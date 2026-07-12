# Promote trained weights to Blob Production path and restart Container App.
#
# Sources (pick one):
#   -SourceBlob "models/runs/<run_id>/yolo_coach.pt"   # already in same container
#   -LocalWeights "atcr-system\models\yolo_coach.pt"  # upload from disk
#   -AmlModelName "yolo-coach" -AmlModelVersion "1"   # download from AML registry
#
# Usage:
#   .\azure\scripts\promote_model.ps1 -StorageAccountName atcrstoreXXXX `
#     -LocalWeights "atcr-system\models\yolo_coach.pt" `
#     -ContainerAppName ca-atcr-api -ResourceGroup rg-atcr

param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $false)]
    [string]$Container = "atcr",

    [Parameter(Mandatory = $false)]
    [string]$DestBlob = "models/yolo_coach.pt",

    [Parameter(Mandatory = $false)]
    [string]$SourceBlob = "",

    [Parameter(Mandatory = $false)]
    [string]$LocalWeights = "",

    [Parameter(Mandatory = $false)]
    [string]$AmlModelName = "",

    [Parameter(Mandatory = $false)]
    [string]$AmlModelVersion = "",

    [Parameter(Mandatory = $false)]
    [string]$AmlWorkspace = "mlw-atcr",

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "rg-atcr",

    [Parameter(Mandatory = $false)]
    [string]$ContainerAppName = "",

    [Parameter(Mandatory = $false)]
    [string]$TagProduction = "true"
)

$ErrorActionPreference = "Stop"

function Get-StorageKey {
    param([string]$Account, [string]$Rg)
    az storage account keys list -g $Rg -n $Account --query "[0].value" -o tsv
}

$key = Get-StorageKey -Account $StorageAccountName -Rg $ResourceGroup
if (-not $key) {
    Write-Error "Could not read storage key for $StorageAccountName"
}

$tempPt = Join-Path $env:TEMP "yolo_coach_promote.pt"

if ($LocalWeights) {
    $LocalWeights = Resolve-Path $LocalWeights
    Copy-Item $LocalWeights $tempPt -Force
    Write-Host "Using local weights: $LocalWeights"
}
elseif ($SourceBlob) {
    Write-Host "Downloading blob: $SourceBlob"
    az storage blob download `
        --account-name $StorageAccountName `
        --account-key $key `
        --container-name $Container `
        --name $SourceBlob `
        --file $tempPt `
        --overwrite true | Out-Null
}
elseif ($AmlModelName -and $AmlModelVersion) {
    Write-Host "Downloading AML model ${AmlModelName}:${AmlModelVersion}"
    $downloadDir = Join-Path $env:TEMP "aml-model-$AmlModelName"
    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
    az ml model download `
        --name $AmlModelName `
        --version $AmlModelVersion `
        --download-path $downloadDir `
        -g $ResourceGroup -w $AmlWorkspace | Out-Null
    $found = Get-ChildItem -Path $downloadDir -Recurse -Filter "yolo_coach.pt" | Select-Object -First 1
    if (-not $found) {
        $found = Get-ChildItem -Path $downloadDir -Recurse -Filter "best.pt" | Select-Object -First 1
    }
    if (-not $found) {
        Write-Error "No yolo_coach.pt or best.pt under $downloadDir"
    }
    Copy-Item $found.FullName $tempPt -Force
}
else {
    Write-Error "Provide -LocalWeights, -SourceBlob, or -AmlModelName + -AmlModelVersion"
}

Write-Host "Uploading Production weights → $Container/$DestBlob"
az storage blob upload `
    --account-name $StorageAccountName `
    --account-key $key `
    --container-name $Container `
    --name $DestBlob `
    --file $tempPt `
    --overwrite true | Out-Null

if ($AmlModelName -and $TagProduction -eq "true") {
    Write-Host "Tagging AML model as Production (best-effort)"
    az ml model update `
        --name $AmlModelName `
        --version $AmlModelVersion `
        --set tags.stage=Production `
        -g $ResourceGroup -w $AmlWorkspace 2>$null
}

if ($ContainerAppName) {
    Write-Host "Restarting Container App revision: $ContainerAppName"
    $rev = az containerapp revision list `
        -g $ResourceGroup -n $ContainerAppName `
        --query "[?properties.active].name | [0]" -o tsv
    if ($rev) {
        az containerapp revision restart -g $ResourceGroup -n $ContainerAppName --revision $rev
    }
    else {
        # Force new revision by bumping an annotation env
        az containerapp update `
            -g $ResourceGroup -n $ContainerAppName `
            --set-env-vars "MODEL_PROMOTED_AT=$(Get-Date -Format o)"
    }
}

Write-Host "Promoted: https://$StorageAccountName.blob.core.windows.net/$Container/$DestBlob"
