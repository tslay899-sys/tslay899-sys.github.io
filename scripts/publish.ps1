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

Write-Host '正在与 GitHub 同步……' -ForegroundColor Cyan
git pull --rebase origin main
if ($LASTEXITCODE -ne 0) { throw '同步 GitHub 失败，请检查上方提示。' }

git push origin main
if ($LASTEXITCODE -ne 0) { throw '上传失败。请确认已经在 VS Code 中登录 GitHub。' }

Write-Host '发布成功！GitHub Pages 通常会在 1～2 分钟内更新。' -ForegroundColor Green

