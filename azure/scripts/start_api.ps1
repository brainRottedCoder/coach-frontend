# Start ATCR API for demos (warm at least one GPU replica).
#
# Usage:
#   .\azure\scripts\start_api.ps1

param(
    [string]$ResourceGroup = "rg-atcr",
    [string]$ContainerAppName = "ca-atcr-api"
)

$ErrorActionPreference = "Stop"

Write-Host "Scaling Container App to minReplicas=1 ..."
az containerapp update `
    -g $ResourceGroup -n $ContainerAppName `
    --min-replicas 1 `
    --max-replicas 1 `
    --only-show-errors -o none

$fqdn = az containerapp show -g $ResourceGroup -n $ContainerAppName `
    --query "properties.configuration.ingress.fqdn" -o tsv

Write-Host ""
Write-Host "API URL: https://$fqdn"
Write-Host "Health:  curl https://$fqdn/health"
Write-Host ""
Write-Host "Set Vercel NEXT_PUBLIC_API_URL=https://$fqdn"
Write-Host ""
Write-Host "When done: .\azure\scripts\stop_costs.ps1"
