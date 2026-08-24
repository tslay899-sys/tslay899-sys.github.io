$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot 'build.ps1') -ProjectRoot $projectRoot
Start-Process (Join-Path $projectRoot 'index.html')
Write-Host '网站预览已在浏览器中打开。' -ForegroundColor Green

