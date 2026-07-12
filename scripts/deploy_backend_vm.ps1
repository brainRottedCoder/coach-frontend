param(
    [string]$VmIp = "20.55.4.254",
    [int]$SshPort = 22
)

$ErrorActionPreference = "Stop"
$tmpKey = Join-Path $env:TEMP "azure_vm_key.pem"
$srcKey = Join-Path $PSScriptRoot "..\ltx2.3gguftesting_key.pem"
$content = (Get-Content $srcKey -Raw) -replace "`r`n", "`n"
[IO.File]::WriteAllText($tmpKey, $content.TrimEnd() + "`n", [Text.UTF8Encoding]::new($false))

function Invoke-Vm($cmd) {
    ssh -i $tmpKey -o StrictHostKeyChecking=no -p $SshPort "azureuser@$VmIp" $cmd
}

Write-Host "=== Deploy minimal backend ==="
if (-not (Test-Path "$env:TEMP\atcr-minimal.tgz")) {
    Push-Location (Join-Path $PSScriptRoot "..\atcr-system")
    tar -czf "$env:TEMP\atcr-minimal.tgz" app cfg deploy scripts tests train_detector.py requirements-l1.txt requirements-l2.txt data/detection_dataset/data.yaml data/coach_registry.json
    Pop-Location
}
scp -i $tmpKey -o StrictHostKeyChecking=no -P $SshPort "$env:TEMP\atcr-minimal.tgz" "azureuser@${VmIp}:~/atcr-minimal.tgz"
Invoke-Vm "mkdir -p ~/coach-detection/atcr-system && cd ~/coach-detection/atcr-system && tar -xzf ~/atcr-minimal.tgz && sed -i 's/\r$//' scripts/*.sh deploy/* 2>/dev/null; rm ~/atcr-minimal.tgz"

Write-Host "=== Dataset (if built) ==="
if (Test-Path "$env:TEMP\atcr-dataset.tgz") {
    scp -i $tmpKey -o StrictHostKeyChecking=no -P $SshPort "$env:TEMP\atcr-dataset.tgz" "azureuser@${VmIp}:~/atcr-dataset.tgz"
    Invoke-Vm "mkdir -p ~/coach-detection/atcr-system/data/detection_dataset && cd ~/coach-detection/atcr-system/data/detection_dataset && tar -xzf ~/atcr-dataset.tgz && rm ~/atcr-dataset.tgz"
}

Write-Host "=== Setup + train + API ==="
Invoke-Vm "cd ~/coach-detection/atcr-system && bash scripts/setup_backend_vm.sh 2>/dev/null || true"
Invoke-Vm "cd ~/coach-detection/atcr-system && source venv/bin/activate && nohup bash scripts/train_yolov8m_gpu.sh > ~/train.log 2>&1 &"
Invoke-Vm "sudo systemctl restart atcr-api || true"
Invoke-Vm "curl -s http://localhost:8000/health || echo API not ready yet"
