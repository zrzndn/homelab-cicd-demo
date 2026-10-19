[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('staging', 'production')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^sha-[0-9a-f]{7,40}$|^dev$')]
    [string]$ImageTag
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $projectName = "homelab-$Environment"
    # Keep the advanced lab beside the existing demo, avoiding accidental downtime during migration.
    $port = if ($Environment -eq 'staging') { 8081 } else { 8082 }
    $imageName = "homelab-cicd-demo-web:$ImageTag"
    $stateRoot = Join-Path $env:USERPROFILE '.homelab-cicd-demo\deploy-state'
    $stateFile = Join-Path $stateRoot "$Environment.current"
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null

    docker image inspect $imageName *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Image $imageName is not present locally. Build and scan it before deploying, or use an existing version tag for rollback."
    }

    $previousTag = ''
    if (Test-Path -LiteralPath $stateFile) {
        $previousTag = (Get-Content -LiteralPath $stateFile -Raw).Trim()
    }

    function Invoke-VersionDeployment {
        param(
            [string]$Tag,
            [string]$Project,
            [int]$HostPort
        )

        $env:IMAGE_TAG = $Tag
        $env:WEB_PORT = [string]$HostPort

        docker compose -p $Project up -d --no-build --remove-orphans
        if ($LASTEXITCODE -ne 0) {
            throw "Docker Compose could not start $Project using image tag $Tag."
        }

        $baseUrl = "http://localhost:$HostPort"
        $containerName = "$Project-web-1"
        for ($attempt = 0; $attempt -lt 30; $attempt++) {
            try {
                $page = Invoke-WebRequest -Uri "$baseUrl/" -TimeoutSec 3 -UseBasicParsing
                $health = Invoke-WebRequest -Uri "$baseUrl/health" -TimeoutSec 3 -UseBasicParsing
                $containerHealth = (docker inspect --format '{{.State.Health.Status}}' $containerName 2>$null | Out-String).Trim()
                if (
                    $page.StatusCode -eq 200 -and
                    $page.Content.Contains("Release: $Tag") -and
                    $health.StatusCode -eq 200 -and
                    $health.Content.Trim() -eq 'ok' -and
                    $containerHealth -eq 'healthy'
                ) {
                    return $true
                }
            } catch {
                # A new container may need a few seconds to become ready.
            }
            Start-Sleep -Seconds 2
        }
        return $false
    }

    Write-Host "Deploying $imageName to $Environment at http://localhost:$port ..."
    try {
        $healthy = Invoke-VersionDeployment -Tag $ImageTag -Project $projectName -HostPort $port
        if (-not $healthy) {
            throw "Smoke/health checks did not pass for $Environment release $ImageTag."
        }

        Set-Content -LiteralPath $stateFile -Value $ImageTag -NoNewline
        Write-Host "Deployment healthy: $Environment is running $ImageTag at http://localhost:$port" -ForegroundColor Green
    } catch {
        Write-Host "Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
        docker compose -p $projectName logs --tail 80

        if ($previousTag -and $previousTag -ne $ImageTag) {
            $previousImage = "homelab-cicd-demo-web:$previousTag"
            docker image inspect $previousImage *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Warning "Attempting automatic rollback to $previousTag ..."
                $rollbackHealthy = $false
                try {
                    $rollbackHealthy = Invoke-VersionDeployment -Tag $previousTag -Project $projectName -HostPort $port
                } catch {
                    Write-Warning "Rollback command encountered an error: $($_.Exception.Message)"
                }
                if ($rollbackHealthy) {
                    Write-Warning "Rollback succeeded. $Environment is back on $previousTag. The workflow will still be marked failed because the new release failed."
                } else {
                    Write-Error "Rollback was attempted but did not pass health checks. Inspect Docker logs immediately."
                }
            } else {
                Write-Warning "Previous image $previousImage is no longer present, so automatic rollback is unavailable."
            }
        } else {
            Write-Warning "No prior successful $Environment release is recorded. The failed project will be stopped."
            docker compose -p $projectName down
        }
        throw "Deployment of $Environment release $ImageTag failed. Review the job log above."
    }
} finally {
    Remove-Item Env:\IMAGE_TAG -ErrorAction SilentlyContinue
    Remove-Item Env:\WEB_PORT -ErrorAction SilentlyContinue
    Pop-Location
}
