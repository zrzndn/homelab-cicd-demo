$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$indexPath = Join-Path $projectRoot 'index.html'
$dockerfilePath = Join-Path $projectRoot 'Dockerfile'
$composePath = Join-Path $projectRoot 'compose.yaml'
$healthPath = Join-Path $projectRoot 'health.html'

foreach ($path in @($indexPath, $dockerfilePath, $composePath, $healthPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required project file is missing: $path"
    }
}

$html = Get-Content -LiteralPath $indexPath -Raw
$dockerfile = Get-Content -LiteralPath $dockerfilePath -Raw
$compose = Get-Content -LiteralPath $composePath -Raw
$health = (Get-Content -LiteralPath $healthPath -Raw).Trim()

$assertions = @(
    @{ Name = 'HTML has the expected title'; Passed = ($html -match '<title>Home Lab CI/CD Demo</title>') },
    @{ Name = 'HTML has a release placeholder'; Passed = ($html -match 'Release: __APP_VERSION__') },
    @{ Name = 'Dockerfile copies the website'; Passed = ($dockerfile -match 'COPY index\.html') },
    @{ Name = 'Dockerfile embeds the image version'; Passed = ($dockerfile -match 'APP_VERSION') },
    @{ Name = 'Compose defines a health check'; Passed = ($compose -match 'healthcheck:') },
    @{ Name = 'Health endpoint returns the expected body'; Passed = ($health -eq 'ok') }
)

$failed = @()
foreach ($assertion in $assertions) {
    if ($assertion.Passed) {
        Write-Host "PASS: $($assertion.Name)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: $($assertion.Name)" -ForegroundColor Red
        $failed += $assertion.Name
    }
}

if ($failed.Count -gt 0) {
    throw "Automated source tests failed: $($failed -join '; ')"
}

Write-Host "All $($assertions.Count) source tests passed."
