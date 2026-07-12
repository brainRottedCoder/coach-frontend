# Upload local detection_dataset to Azure Blob (container atcr).
# Prerequisites: AzCopy in PATH, Storage account + container created.
#
# Usage:
#   .\azure\scripts\azcopy_upload_dataset.ps1 `
#     -StorageAccountName "atcrstoreXXXX" `
#     -SasToken "?sv=..." `
#     -LocalDataset "atcr-system\data\detection_dataset"
#
# Or set env AZURE_STORAGE_SAS_URL to a container SAS URL ending in /atcr

param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $false)]
    [string]$SasToken = "",

    [Parameter(Mandatory = $false)]
    [string]$LocalDataset = "",

    [Parameter(Mandatory = $false)]
    [string]$Container = "atcr",

    [Parameter(Mandatory = $false)]
    [string]$BlobPrefix = "datasets/detection_dataset"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command azcopy -ErrorAction SilentlyContinue)) {
    Write-Error "AzCopy not found in PATH. Install: https://learn.microsoft.com/azure/storage/common/storage-use-azcopy-v10"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
if (-not $LocalDataset) {
    $LocalDataset = Join-Path $repoRoot "atcr-system\data\detection_dataset"
}
$LocalDataset = Resolve-Path $LocalDataset

if (-not (Test-Path (Join-Path $LocalDataset "data.yaml"))) {
    Write-Error "Expected data.yaml under $LocalDataset"
}

if ($env:AZURE_STORAGE_SAS_URL) {
    # Expect container SAS URL: https://account.blob.core.windows.net/atcr?<sas>
    $base = $env:AZURE_STORAGE_SAS_URL
    if ($base -match '\?') {
        $parts = $base -split '\?', 2
        $dest = ($parts[0].TrimEnd("/") + "/$BlobPrefix") + "?" + $parts[1]
    }
    else {
        $dest = $base.TrimEnd("/") + "/$BlobPrefix"
    }
}
else {
    if (-not $SasToken) {
        Write-Error "Pass -SasToken or set AZURE_STORAGE_SAS_URL"
    }
    if (-not $SasToken.StartsWith("?")) {
        $SasToken = "?" + $SasToken
    }
    $dest = "https://$StorageAccountName.blob.core.windows.net/$Container/$BlobPrefix$SasToken"
}

Write-Host "Uploading:"
Write-Host "  From: $LocalDataset"
Write-Host "  To:   https://$StorageAccountName.blob.core.windows.net/$Container/$BlobPrefix"
Write-Host ""

azcopy copy "$LocalDataset\*" $dest --recursive=true --overwrite=ifSourceNewer

Write-Host ""
Write-Host "Done. Dataset available at blob://$Container/$BlobPrefix"
