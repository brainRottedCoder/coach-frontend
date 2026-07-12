# Build, push, and deploy ATCR FastAPI to Azure Container Apps (GPU).
#
# Prerequisites:
#   az login; Docker running; ACR + ACA env with GPU workload profile
#
# Usage:
#   .\azure\scripts\deploy_aca.ps1 `
#     -ResourceGroup rg-atcr `
#     -AcrName acratcrXXXX `
#     -ContainerAppName ca-atcr-api `
#     -EnvironmentName cae-atcr `
#     -StorageConnectionString "DefaultEndpointsProtocol=..."

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$AcrName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerAppName,

    [Parameter(Mandatory = $true)]
    [string]$EnvironmentName,

    [Parameter(Mandatory = $false)]
    [string]$StorageConnectionString = "",

    [Parameter(Mandatory = $false)]
    [string]$ImageTag = "latest",

    [Parameter(Mandatory = $false)]
    [string]$Location = "westus3",

    [Parameter(Mandatory = $false)]
    [string]$CorsOrigins = "https://coach-frontend-eta.vercel.app",

    [Parameter(Mandatory = $false)]
    [string]$WorkloadProfile = "Consumption-GPU-NC8as-T4",

    [Parameter(Mandatory = $false)]
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$image = "$AcrName.azurecr.io/atcr-api:$ImageTag"

Write-Host "=== ATCR Container Apps deploy ==="
Write-Host "Image: $image"
Write-Host "App:   $ContainerAppName"
Write-Host ""

if (-not $SkipBuild) {
    $dockerOk = $false
    try {
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $dockerOk = $true }
    }
    catch { $dockerOk = $false }

    if ($dockerOk) {
        Write-Host "Logging into ACR..."
        az acr login -n $AcrName | Out-Null

        Write-Host "Building Docker image locally (CUDA)..."
        docker build -f "$repoRoot\azure\aca\Dockerfile" -t $image "$repoRoot"
        if ($LASTEXITCODE -ne 0) { Write-Error "docker build failed" }

        Write-Host "Pushing image..."
        docker push $image
        if ($LASTEXITCODE -ne 0) { Write-Error "docker push failed" }
    }
    else {
        Write-Host "Docker not running - using ACR cloud build (az acr build)..."
        & (Join-Path $PSScriptRoot "prepare_acr_context.ps1")
        $buildDir = Join-Path $repoRoot "azure\aca\build"
        Push-Location $buildDir
        try {
            az acr build `
                --registry $AcrName `
                --image "atcr-api:$ImageTag" `
                --file Dockerfile `
                . `
                --no-logs
            if ($LASTEXITCODE -ne 0) { Write-Error "acr build failed" }
        }
        finally {
            Pop-Location
        }
    }
}

$exists = az containerapp show -g $ResourceGroup -n $ContainerAppName -o tsv 2>$null
$envVars = @(
    "YOLO_MODEL_PATH=./models/yolo_coach.pt",
    "YOLO_DEVICE=0",
    "BLOB_CONTAINER=atcr",
    "MODEL_BLOB_PATH=models/yolo_coach.pt",
    "BLOB_SYNC_MODEL_ON_STARTUP=true",
    "BLOB_PERSIST_JOB_RESULTS=true",
    "CORS_ORIGINS=$CorsOrigins"
)

if (-not $exists) {
    if (-not $StorageConnectionString) {
        Write-Error "First deploy requires -StorageConnectionString"
    }
    Write-Host "Creating Container App (GPU profile: $WorkloadProfile)..."
    az containerapp create `
        -g $ResourceGroup `
        -n $ContainerAppName `
        --environment $EnvironmentName `
        --image $image `
        --registry-server "$AcrName.azurecr.io" `
        --target-port 8000 `
        --ingress external `
        --min-replicas 1 `
        --max-replicas 1 `
        --cpu 4 `
        --memory 16Gi `
        -w $WorkloadProfile `
        --secrets "storage-connection-string=$StorageConnectionString" `
        --env-vars @envVars "AZURE_STORAGE_CONNECTION_STRING=secretref:storage-connection-string" `
        --system-assigned
}
else {
    Write-Host "Updating existing Container App image..."
    $updateArgs = @(
        "containerapp", "update",
        "-g", $ResourceGroup,
        "-n", $ContainerAppName,
        "--image", $image,
        "--min-replicas", "1",
        "--max-replicas", "1",
        "--set-env-vars"
    ) + $envVars

    if ($StorageConnectionString) {
        az containerapp secret set `
            -g $ResourceGroup -n $ContainerAppName `
            --secrets "storage-connection-string=$StorageConnectionString" | Out-Null
        $updateArgs += "AZURE_STORAGE_CONNECTION_STRING=secretref:storage-connection-string"
    }

    & az @updateArgs
}

$fqdn = az containerapp show -g $ResourceGroup -n $ContainerAppName --query "properties.configuration.ingress.fqdn" -o tsv
Write-Host ""
Write-Host "Deployed. Health check:"
Write-Host "  curl https://$fqdn/health"
Write-Host ""
Write-Host "Set Vercel NEXT_PUBLIC_API_URL=https://$fqdn"
