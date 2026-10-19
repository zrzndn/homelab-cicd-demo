[CmdletBinding()]
param(
    [switch]$Once,
    [ValidateRange(1, 3600)]
    [int]$IntervalSeconds = 5
)

$ErrorActionPreference = 'Continue'
$targets = @(
    [pscustomobject]@{ Name = 'staging'; Url = 'http://localhost:8081'; Project = 'homelab-staging' },
    [pscustomobject]@{ Name = 'production'; Url = 'http://localhost:8082'; Project = 'homelab-production' }
)

Write-Host 'Basic home-lab monitor. Press Ctrl+C to stop.'
do {
    foreach ($target in $targets) {
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $status = 'DOWN'
        try {
            $response = Invoke-WebRequest -Uri $target.Url -TimeoutSec 3 -UseBasicParsing
            $status = "HTTP $($response.StatusCode)"
        } catch {
            $status = 'DOWN'
        }
        $timer.Stop()

        $containerName = "$($target.Project)-web-1"
        $containerStatus = (docker inspect --format '{{.State.Status}}/{{.State.Health.Status}}' $containerName 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $containerStatus) {
            $containerStatus = 'not-created'
        }

        $line = '{0} | {1,-10} | {2,-10} | {3,4} ms | container={4}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $target.Name, $status, $timer.ElapsedMilliseconds, $containerStatus
        Write-Host $line
    }

    if (-not $Once) {
        Start-Sleep -Seconds $IntervalSeconds
    }
} while (-not $Once)
