param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$contentDirectory = Join-Path $ProjectRoot 'content'
$dataDirectory = Join-Path $ProjectRoot 'data'
$outputFile = Join-Path $dataDirectory 'logs.js'

if (-not (Test-Path -LiteralPath $contentDirectory)) {
    throw "找不到内容目录：$contentDirectory"
}

$logs = @()
$files = Get-ChildItem -LiteralPath $contentDirectory -Filter '*.md' -File |
    Where-Object { -not $_.Name.StartsWith('_') }

foreach ($file in $files) {
    $raw = [System.IO.File]::ReadAllText($file.FullName)
    $frontMatterMatch = [regex]::Match($raw, '(?s)\A---\r?\n(.*?)\r?\n---\r?\n(.*)\z')
    if (-not $frontMatterMatch.Success) {
        throw "$($file.Name) 缺少正确的头部信息。"
    }

    $metadata = @{}
    foreach ($line in ($frontMatterMatch.Groups[1].Value -split '\r?\n')) {
        if ($line -match '^([^:]+):\s*(.*)$') {
            $metadata[$matches[1].Trim()] = $matches[2].Trim()
        }
    }

    if (-not $metadata.date -or -not $metadata.title) {
        throw "$($file.Name) 必须填写 date 和 title。"
    }

    $sections = @{}
    $sectionMatches = [regex]::Matches(
        $frontMatterMatch.Groups[2].Value,
        '(?ms)^##\s+(.+?)\s*\r?\n(.*?)(?=^##\s+|\z)'
    )
    foreach ($section in $sectionMatches) {
        $sections[$section.Groups[1].Value.Trim()] = $section.Groups[2].Value.Trim()
    }

    $tags = @()
    if ($metadata.tags) {
        $tags = @($metadata.tags -split '[,，]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    $log = [ordered]@{
        date = $metadata.date
        title = $metadata.title
        tags = $tags
        learned = $sections['今日学习']
        insight = $sections['收获与思考']
        next = $sections['下一步']
        motto = $sections['今日一句']
        recommendation = $sections['今日推荐曲目']
    }

    if ($metadata.image) { $log.image = $metadata.image }
    if ($metadata.imageAlt) { $log.imageAlt = $metadata.imageAlt }
    $logs += [pscustomobject]$log
}

$logs = @($logs | Sort-Object date -Descending)
$json = ConvertTo-Json -InputObject $logs -Depth 6
$javascript = "window.LEARNING_LOGS = $json;`n"

if (-not (Test-Path -LiteralPath $dataDirectory)) {
    New-Item -ItemType Directory -Path $dataDirectory | Out-Null
}

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outputFile, $javascript, $utf8WithoutBom)
Write-Host "已生成 $($logs.Count) 篇学习记录。" -ForegroundColor Green

