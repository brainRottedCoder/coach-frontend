# Fix Windows OpenSSH "invalid format" for the Azure PEM key.
# Usage: .\scripts\fix_ssh_key.ps1
# Then:  ssh -i $env:TEMP\azure_vm_key.pem -p 22 azureuser@20.55.4.254

$src = Join-Path $PSScriptRoot "..\ltx2.3gguftesting_key.pem"
$tmpKey = Join-Path $env:TEMP "azure_vm_key.pem"

if (-not (Test-Path $src)) {
    throw "PEM not found: $src"
}

# Strip CRLF — Windows OpenSSH rejects keys saved with Windows line endings
$content = Get-Content $src -Raw
$content = $content -replace "`r`n", "`n"
if (Test-Path $tmpKey) { Remove-Item $tmpKey -Force }
[System.IO.File]::WriteAllText($tmpKey, $content.TrimEnd() + "`n", [System.Text.UTF8Encoding]::new($false))
icacls $tmpKey /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null

Write-Host "Fixed key written to: $tmpKey"
ssh-keygen -y -f $tmpKey | Out-Null
Write-Host "Key is valid. Connect with:"
Write-Host ""
Write-Host "  ssh -i `"$tmpKey`" -p 22 azureuser@20.55.4.254"
Write-Host ""
Write-Host "Or use: .\scripts\ssh_azure_vm.ps1"
