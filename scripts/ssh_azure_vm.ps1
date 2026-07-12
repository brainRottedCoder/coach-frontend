param(
    [string]$User = "azureuser",
    [int]$Port = 22,
    [string]$Command = ""
)

$VM_IP = "20.55.4.254"

function Get-AzureVmKeyPath {
    $src = Join-Path $PSScriptRoot "..\ltx2.3gguftesting_key.pem"
    if (-not (Test-Path $src)) {
        throw "PEM key not found: $src"
    }
    $tmpKey = Join-Path $env:TEMP "azure_vm_key.pem"
    $content = Get-Content $src -Raw
    $content = $content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($tmpKey, $content.TrimEnd() + "`n", [System.Text.UTF8Encoding]::new($false))
    icacls $tmpKey /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
    return $tmpKey
}

$Key = Get-AzureVmKeyPath

Write-Host "Testing connectivity to ${VM_IP}:${Port} ..."
$test = Test-NetConnection -ComputerName $VM_IP -Port $Port -WarningAction SilentlyContinue
Write-Host "TcpTestSucceeded: $($test.TcpTestSucceeded)"

if (-not $test.TcpTestSucceeded) {
    Write-Host ""
    Write-Host "Port $Port is not reachable. In Azure Portal -> VM -> Networking:"
    Write-Host "  Add inbound rule: TCP $Port, Source = Your IP, Action = Allow"
    Write-Host "See docs\AZURE_GPU_VM.md"
    exit 1
}

if ($Command) {
    ssh -i $Key -o StrictHostKeyChecking=no -p $Port "${User}@${VM_IP}" $Command
} else {
    Write-Host ""
    Write-Host "Connecting ${User}@${VM_IP}:${Port} ..."
    ssh -i $Key -o StrictHostKeyChecking=no -p $Port "${User}@${VM_IP}"
}
