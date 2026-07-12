# Stop ATCR Azure resources when not in use (save GPU cost).
#
# Usage:
#   .\azure\scripts\stop_costs.ps1
#
# To bring API back for demos:
#   .\azure\scripts\start_api.ps1

param(
    [string]$ResourceGroup = "rg-atcr",
    [string]$ContainerAppName = "ca-atcr-api",
    [string]$VmResourceGroup = "LTX-RG",
    [string]$VmName = "ltx2.3gguftesting"
)

$ErrorActionPreference = "Stop"

Write-Host "=== ATCR cost stop ===" -ForegroundColor Cyan

# Container App GPU: scale to zero (no always-on T4 replica)
Write-Host "Scaling Container App to minReplicas=0 ..."
az containerapp update `
    -g $ResourceGroup -n $ContainerAppName `
    --min-replicas 0 `
    --max-replicas 1 `
    --only-show-errors -o none
Write-Host "  $ContainerAppName -> scale-to-zero when idle"

# Legacy NC T4 VM (if still allocated)
$power = az vm get-instance-view -g $VmResourceGroup -n $VmName `
    --query "instanceView.statuses[?starts_with(code,'PowerState/')].code | [0]" -o tsv 2>$null
if ($power -and $power -ne "PowerState/deallocated" -and $power -ne "PowerState/stopped") {
    Write-Host "Deallocating legacy VM $VmName ..."
    az vm deallocate -g $VmResourceGroup -n $VmName -o none
    Write-Host "  VM deallocated"
}
else {
    Write-Host "Legacy VM $VmName already deallocated"
}

Write-Host ""
Write-Host "Still billed (low cost when idle):" -ForegroundColor Yellow
Write-Host "  - Blob storage (atcr62e441)"
Write-Host "  - ACR Basic (acratcr62e441)"
Write-Host "  - Log Analytics / ACA environment (cae-atcr) - small fixed cost"
Write-Host ""
Write-Host "Start API before demos: .\azure\scripts\start_api.ps1"
