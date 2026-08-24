$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

Set-Location $projectRoot
Write-Host '发布工具版本：2026-08-24.2' -ForegroundColor Cyan

# Use the Windows desktop TLS session and the encrypted DPAPI credential store.
# This avoids crashes seen with the OpenSSL helper in some Git for Windows builds.
git config http.sslBackend schannel
git config http.sslVerify true
git config credential.credentialStore dpapi

& (Join-Path $PSScriptRoot 'build.ps1') -ProjectRoot $projectRoot

git diff --check
if ($LASTEXITCODE -ne 0) {
    Write-Host '发现多余空格，将继续发布；可稍后整理格式。' -ForegroundColor Yellow
}

git add --all
$pendingChanges = git status --porcelain

if ($pendingChanges) {
    $commitMessage = "学习记录：$(Get-Date -Format 'yyyy-MM-dd')"
    git commit -m $commitMessage
    if ($LASTEXITCODE -ne 0) { throw '保存版本失败。' }
} else {
    Write-Host '没有发现需要发布的新内容。' -ForegroundColor Yellow
}

Write-Host '正在通过安全备用通道上传到 GitHub……' -ForegroundColor Cyan
$workspaceRoot = Split-Path -Parent $projectRoot
$pythonPath = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$helperPath = Join-Path $workspaceRoot 'work\push_with_dulwich.py'
$libraryPath = Join-Path $workspaceRoot 'work\dulwich_lib'
$credentialPath = Join-Path $env:USERPROFILE '.gcm\dpapi_store\git\https\github.com\tslay899-sys.credential'

if (-not (Test-Path -LiteralPath $pythonPath) -or
    -not (Test-Path -LiteralPath $helperPath) -or
    -not (Test-Path -LiteralPath $libraryPath)) {
    throw '安全上传组件不完整，请让 Codex 重新配置发布工具。'
}
if (-not (Test-Path -LiteralPath $credentialPath)) {
    throw '尚未保存 GitHub 登录，请先运行“⓪ 首次登录 GitHub”。'
}

Add-Type -AssemblyName System.Security
$credentialLines = [System.IO.File]::ReadAllLines($credentialPath)
$encryptedBytes = [Convert]::FromBase64String($credentialLines[0])
$plainBytes = [Security.Cryptography.ProtectedData]::Unprotect(
    $encryptedBytes,
    $null,
    [Security.Cryptography.DataProtectionScope]::CurrentUser
)
$secret = [Text.Encoding]::UTF8.GetString($plainBytes)

try {
    $pushOutput = $secret | & $pythonPath $helperPath $projectRoot $libraryPath 2>&1
    $pushExitCode = $LASTEXITCODE
} finally {
    if ($plainBytes) { [Array]::Clear($plainBytes, 0, $plainBytes.Length) }
    $secret = $null
}

$pushOutput | ForEach-Object { Write-Host $_ }
if ($pushExitCode -ne 0) {
    throw '安全上传失败，请把上方 SAFE_PUSH_ERROR 后的内容发给 Codex。'
}

$headCommit = git rev-parse HEAD
git update-ref refs/remotes/origin/main $headCommit

Write-Host '发布成功！GitHub Pages 通常会在 1～2 分钟内更新。' -ForegroundColor Green

