param(
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $projectRoot 'content\_template.md'
$newLogPath = Join-Path $projectRoot "content\$Date.md"

try {
    [void][datetime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
} catch {
    throw '日期格式应为 yyyy-MM-dd，例如 2026-08-24。'
}

if (-not (Test-Path -LiteralPath $newLogPath)) {
    $template = [System.IO.File]::ReadAllText($templatePath).Replace('{{date}}', $Date)
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($newLogPath, $template, $utf8WithoutBom)
    Write-Host "已新建今天的学习记录：$Date.md" -ForegroundColor Green
} else {
    Write-Host '今天的记录已经存在，正在打开。' -ForegroundColor Yellow
}

$codeCommand = Get-Command code -ErrorAction SilentlyContinue
if ($codeCommand) {
    & $codeCommand.Source '--reuse-window' $newLogPath
} else {
    Write-Host "请在 VS Code 中打开：$newLogPath"
}

