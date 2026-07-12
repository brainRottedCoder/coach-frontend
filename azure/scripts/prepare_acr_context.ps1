# Copy minimal API files into azure/aca/build for ACR cloud build (avoids huge data/).
$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$atcr = Join-Path $repoRoot "atcr-system"
$build = Join-Path $repoRoot "azure\aca\build"

if (Test-Path $build) {
    try { Remove-Item $build -Recurse -Force -ErrorAction Stop }
    catch {
        $build = Join-Path $repoRoot "azure\aca\build-$(Get-Date -Format 'yyyyMMddHHmmss')"
    }
}
New-Item -ItemType Directory -Path $build | Out-Null

Copy-Item (Join-Path $atcr "Dockerfile") $build
Copy-Item (Join-Path $atcr "requirements-l1.txt") $build
Copy-Item (Join-Path $atcr "app") (Join-Path $build "app") -Recurse
Copy-Item (Join-Path $atcr "cfg") (Join-Path $build "cfg") -Recurse

Write-Host "Build context ready: $build"
