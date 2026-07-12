# One-shot Azure CLI provisioning for ATCR (Blob + ACR + ACA GPU + optional AML).
#
# Usage (from repo root):
#   .\azure\scripts\provision_all.ps1
#
# Optional:
#   .\azure\scripts\provision_all.ps1 -SkipAml -SkipAcrBuild
#   .\azure\scripts\provision_all.ps1 -Location westus3
#
# Writes non-secret config to azure/deploy.env (gitignored).
# Storage connection string is printed once - save it securely.

param(
    [string]$ResourceGroup = "rg-atcr",
    [string]$Location = "eastus",
    [string]$WorkloadProfile = "Consumption-GPU-NC8as-T4",
    [string]$ContainerAppName = "ca-atcr-api",
    [string]$EnvironmentName = "cae-atcr",
    [string]$AmlWorkspace = "mlw-atcr",
    [string]$CorsOrigins = "https://coach-frontend-eta.vercel.app,http://localhost:3000",
    [switch]$SkipAml,
    [switch]$SkipAcrBuild,
    [switch]$SkipDeploy
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Invoke-Az {
    # az writes warnings to stderr; do not treat as terminating errors
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & az @args --only-show-errors 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { return $null }
    if ($out -is [array]) { return ($out | Out-String).Trim() }
    return "$out".Trim()
}

# Unique suffix from subscription id (stable per sub)
$subId = (az account show --query id -o tsv).Trim()
$suffix = $subId.Replace("-", "").Substring($subId.Replace("-", "").Length - 6).ToLower()
$StorageAccount = "atcr$suffix"
$AcrName = "acratcr$suffix"
$LogWorkspace = "law-atcr-$suffix"

Write-Host "=== ATCR Azure provision ===" -ForegroundColor Cyan
Write-Host "Resource group : $ResourceGroup"
Write-Host "Location       : $Location"
Write-Host "Storage        : $StorageAccount"
Write-Host "ACR            : $AcrName"
Write-Host "GPU profile    : $WorkloadProfile"
Write-Host ""

function Require-Az {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI (az) not found"
    }
    $acct = az account show -o json 2>$null | ConvertFrom-Json
    if (-not $acct) { Write-Error "Run: az login" }
}

function Ensure-Extension {
    param([string]$Name)
    $installed = az extension list --query "[?name=='$Name'].name" -o tsv
    if (-not $installed) {
        Write-Host "Installing az extension: $Name ..."
        az extension add --name $Name -y | Out-Null
    }
}

Require-Az
Ensure-Extension -Name "containerapp"

Write-Host 'Step 1/8: Resource group'
az group create -n $ResourceGroup -l $Location -o none
if ($LASTEXITCODE -ne 0) { Write-Error "group create failed" }

Write-Host 'Step 2/8: Storage account + container atcr'
az storage account create `
    -g $ResourceGroup -n $StorageAccount -l $Location `
    --sku Standard_LRS --kind StorageV2 -o none

az storage container create `
    --account-name $StorageAccount -n atcr --auth-mode login -o none

$connStr = az storage account show-connection-string `
    -g $ResourceGroup -n $StorageAccount --query connectionString -o tsv

Write-Host 'Step 3/8: Azure Container Registry'
az acr create -g $ResourceGroup -n $AcrName -l $Location --sku Basic -o none

Write-Host 'Step 4/8: Log Analytics + Container Apps environment (GPU)'
az monitor log-analytics workspace create `
    -g $ResourceGroup -n $LogWorkspace -l $Location -o none

$lawId = az monitor log-analytics workspace show `
    -g $ResourceGroup -n $LogWorkspace --query customerId -o tsv
$lawKey = az monitor log-analytics workspace get-shared-keys `
    -g $ResourceGroup -n $LogWorkspace --query primarySharedKey -o tsv

$envExists = Invoke-Az containerapp env show -g $ResourceGroup -n $EnvironmentName -o tsv
if (-not $envExists) {
    Invoke-Az containerapp env create `
        -g $ResourceGroup -n $EnvironmentName -l $Location `
        --logs-workspace-id $lawId `
        --logs-workspace-key $lawKey `
        --enable-workload-profiles | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error "containerapp env create failed" }
}

$profiles = Invoke-Az containerapp env show -g $ResourceGroup -n $EnvironmentName --query "properties.workloadProfiles[].name" -o tsv
if ($profiles -notmatch [regex]::Escape($WorkloadProfile)) {
    Write-Host "  Adding GPU workload profile: $WorkloadProfile"
    Invoke-Az containerapp env workload-profile add `
        -g $ResourceGroup -n $EnvironmentName `
        -w $WorkloadProfile `
        --workload-profile-type $WorkloadProfile | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error "workload-profile add failed" }
}
else {
    Write-Host "  Environment $EnvironmentName ready (GPU profile present)"
}

$image = "$AcrName.azurecr.io/atcr-api:latest"

if (-not $SkipAcrBuild) {
    Write-Host 'Step 5/8: ACR cloud build (no local Docker required)'
    & (Join-Path $PSScriptRoot "prepare_acr_context.ps1")
    $buildDir = Join-Path $repoRoot "azure\aca\build"
    Push-Location $buildDir
    try {
        az acr build `
            --registry $AcrName `
            --image atcr-api:latest `
            --file Dockerfile `
            . `
            --no-logs
        if ($LASTEXITCODE -ne 0) { Write-Error "acr build failed" }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host 'Step 5/8: Skipping ACR build'
}

if (-not $SkipDeploy) {
    Write-Host 'Step 6/8: Container App GPU single replica'
    $appExists = Invoke-Az containerapp show -g $ResourceGroup -n $ContainerAppName -o tsv
    $envVars = @(
        "YOLO_MODEL_PATH=./models/yolo_coach.pt",
        "YOLO_DEVICE=0",
        "BLOB_CONTAINER=atcr",
        "MODEL_BLOB_PATH=models/yolo_coach.pt",
        "BLOB_SYNC_MODEL_ON_STARTUP=true",
        "BLOB_PERSIST_JOB_RESULTS=true",
        "CORS_ORIGINS=$CorsOrigins"
    )

    if (-not $appExists) {
        az containerapp create `
            -g $ResourceGroup -n $ContainerAppName `
            --environment $EnvironmentName `
            --image $image `
            --registry-server "$AcrName.azurecr.io" `
            --registry-identity system `
            --target-port 8000 `
            --ingress external `
            --min-replicas 1 `
            --max-replicas 1 `
            --cpu 4 `
            --memory 16Gi `
            -w $WorkloadProfile `
            --secrets "storage-connection-string=$connStr" `
            --env-vars @envVars "AZURE_STORAGE_CONNECTION_STRING=secretref:storage-connection-string" `
            --system-assigned `
            -o none
    }
    else {
        az containerapp update `
            -g $ResourceGroup -n $ContainerAppName `
            --image $image `
            --min-replicas 1 `
            --max-replicas 1 `
            --set-env-vars @envVars `
            -o none
        az containerapp secret set `
            -g $ResourceGroup -n $ContainerAppName `
            --secrets "storage-connection-string=$connStr" `
            -o none
    }

    # Grant ACA managed identity AcrPull
    $principalId = az containerapp show -g $ResourceGroup -n $ContainerAppName `
        --query identity.principalId -o tsv
    $acrId = az acr show -g $ResourceGroup -n $AcrName --query id -o tsv
    if ($principalId -and $acrId) {
        az role assignment create `
            --assignee $principalId `
            --role AcrPull `
            --scope $acrId `
            -o none 2>$null
    }
}
else {
    Write-Host 'Step 6/8: Skipping Container App deploy'
}

if (-not $SkipAml) {
    $mlExt = az extension list --query "[?name=='ml'].name" -o tsv
    if ($mlExt) {
        Write-Host 'Step 7/8: Azure ML workspace + GPU compute'
        az ml workspace create -g $ResourceGroup -n $AmlWorkspace -l $Location -o none 2>$null
        az ml compute create `
            --name atcr-gpu-cluster `
            --type amlcompute `
            --size Standard_NC4as_T4_v3 `
            --min-instances 0 `
            --max-instances 1 `
            --tier low_priority `
            -g $ResourceGroup -w $AmlWorkspace -o none 2>$null
        az ml environment create -f "$repoRoot\azure\aml\environment.yml" `
            -g $ResourceGroup -w $AmlWorkspace -o none 2>$null
        Write-Host "  Submit training when dataset is in Blob:"
        Write-Host "  az ml job create -f azure/aml/job_yolov8m.yml -g $ResourceGroup -w $AmlWorkspace"
    }
    else {
        Write-Host 'Step 7/8: Skipping AML (install: az extension add --name ml)'
    }
}
else {
    Write-Host 'Step 7/8: Skipping AML'
}

Write-Host 'Step 8/8: Writing azure/deploy.env'
$deployEnv = @"
# Generated by provision_all.ps1 - do not commit
AZURE_RESOURCE_GROUP=$ResourceGroup
AZURE_LOCATION=$Location
AZURE_STORAGE_ACCOUNT=$StorageAccount
AZURE_STORAGE_CONTAINER=atcr
AZURE_ACR_NAME=$AcrName
AZURE_ACA_ENV=$EnvironmentName
AZURE_CONTAINER_APP=$ContainerAppName
AZURE_AML_WORKSPACE=$AmlWorkspace
AZURE_WORKLOAD_PROFILE=$WorkloadProfile
"@
$deployPath = Join-Path $repoRoot "azure\deploy.env"
$deployEnv | Set-Content -Path $deployPath -Encoding UTF8

$fqdn = ""
if (-not $SkipDeploy) {
    $fqdn = az containerapp show -g $ResourceGroup -n $ContainerAppName `
        --query "properties.configuration.ingress.fqdn" -o tsv 2>$null
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "Storage account : $StorageAccount"
Write-Host "Blob container  : atcr"
Write-Host "ACR             : $AcrName.azurecr.io"
if ($fqdn) {
    Write-Host "API URL         : https://$fqdn"
    Write-Host "Health          : curl https://$fqdn/health"
    Write-Host ""
    Write-Host "Vercel env: NEXT_PUBLIC_API_URL=https://$fqdn"
}
Write-Host ""
Write-Host "Connection string (save securely, not written to deploy.env):"
Write-Host $connStr
Write-Host ""
Write-Host "Next:"
Write-Host "  1. Upload dataset: .\azure\scripts\azcopy_upload_dataset.ps1 -StorageAccountName $StorageAccount -SasToken '<sas>'"
Write-Host "  2. Promote model:  .\azure\scripts\promote_model.ps1 -StorageAccountName $StorageAccount -LocalWeights atcr-system\models\yolo_coach.pt -ResourceGroup $ResourceGroup -ContainerAppName $ContainerAppName"
