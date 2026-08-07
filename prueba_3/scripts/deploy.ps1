param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("staging", "production")]
    [string]$DeployEnvironment,

    [Parameter(Mandatory = $true)]
    [string]$ImageRef,

    [Parameter(Mandatory = $true)]
    [int]$HostPort
)

$ErrorActionPreference = "Stop"

$ProjectName = "nginx-$DeployEnvironment"
$ServiceName = "nginx"

Write-Host "Environment: $DeployEnvironment"
Write-Host "Project: $ProjectName"
Write-Host "Image: $ImageRef"
Write-Host "Port: $HostPort"

# No se acepta latest como versión de deployment.
if ($ImageRef -match ":latest$") {
    throw "The latest tag is not accepted. Use an immutable image tag."
}

# Buscar el contenedor actualmente desplegado.
$ContainerId = docker compose `
    -p $ProjectName `
    ps -q $ServiceName

if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect the current Docker Compose service."
}

$PreviousImage = $null

if (-not [string]::IsNullOrWhiteSpace($ContainerId)) {
    $PreviousImage = docker inspect `
        --format "{{.Config.Image}}" `
        $ContainerId

    if ($LASTEXITCODE -ne 0) {
        throw "Could not identify the previous image."
    }

    Write-Host "Previous image: $PreviousImage"
}
else {
    Write-Host "No previous deployment was found."
}

function Deploy-Image {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetImage
    )

    Write-Host "Deploying image: $TargetImage"

    $env:IMAGE_REF = $TargetImage
    $env:DEPLOY_ENV = $DeployEnvironment
    $env:HOST_PORT = "$HostPort"

    docker compose `
        -p $ProjectName `
        up -d `
        --pull always `
        --force-recreate

    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose deployment failed."
    }
}

# Desplegar la nueva versión.
Deploy-Image -TargetImage $ImageRef

$DeploymentHealthy = $false
$HealthUrl = "http://127.0.0.1:$HostPort/healthz"

# Doce intentos cada cinco segundos.
for ($Attempt = 1; $Attempt -le 12; $Attempt++) {
    Write-Host "Health check attempt $Attempt of 12: $HealthUrl"

    try {
        $Response = Invoke-WebRequest `
            -Uri $HealthUrl `
            -UseBasicParsing `
            -TimeoutSec 3

        if ($Response.StatusCode -eq 200) {
            $DeploymentHealthy = $true
            break
        }
    }
    catch {
        Write-Warning "Health check failed: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 5
}

if ($DeploymentHealthy) {
    Write-Host "$DeployEnvironment is healthy on $ImageRef"
    exit 0
}

Write-Error "The deployment health check failed for $ImageRef"

# Rollback automático.
if (-not [string]::IsNullOrWhiteSpace($PreviousImage)) {
    Write-Warning "Rolling back to $PreviousImage"

    Deploy-Image -TargetImage $PreviousImage

    Start-Sleep -Seconds 5

    try {
        $RollbackResponse = Invoke-WebRequest `
            -Uri $HealthUrl `
            -UseBasicParsing `
            -TimeoutSec 5

        if ($RollbackResponse.StatusCode -eq 200) {
            Write-Host "Rollback completed successfully."
        }
        else {
            Write-Error "Rollback completed, but the service is not healthy."
        }
    }
    catch {
        Write-Error "Rollback health check failed: $($_.Exception.Message)"
    }
}
else {
    Write-Warning "Rollback was not possible because no previous image exists."
}

exit 1