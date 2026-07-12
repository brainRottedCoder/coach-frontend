# ATCR — Full Azure Architecture

Target infra: **Blob** (data) + **Azure ML** (train) + **Container Apps GPU** (serve) + **Vercel** (UI).

The single NC T4 VM path in [AZURE_GPU_VM.md](AZURE_GPU_VM.md) is **deprecated for production serving** after cutover.

## Architecture

```
Vercel (Next.js)
    │ HTTPS
    ▼
Azure Container Apps (GPU T4)  →  FastAPI + YOLOv8
    │
    ▼
Azure Blob (container: atcr)  ←  datasets, models/yolo_coach.pt, jobs/
    ▲
Azure ML job (NC4as_T4_v3)  →  train → Model Registry → promote
```

See [azure/blob_layout.md](../azure/blob_layout.md) for folder contract.

## Prerequisites

| Item | Notes |
|------|--------|
| Azure subscription | Contributor on a resource group |
| Region with **Container Apps GPU (T4)** | Prefer `westus3` or `eastus` — verify in portal before creating resources |
| Azure CLI | `az login`; extensions: `containerapp`, `ml` |
| AzCopy | Dataset upload |
| Docker Desktop | Build inference image |
| ACR | Holds `atcr-api` image |

Suggested resource names (replace `XXXX` with a unique suffix):

| Resource | Example |
|----------|---------|
| Resource group | `rg-atcr` |
| Storage account | `atcrstoreXXXX` |
| Blob container | `atcr` |
| AML workspace | `mlw-atcr` |
| ACR | `acratcrXXXX` |
| ACA environment | `cae-atcr` |
| Container app | `ca-atcr-api` |

## Stage A — One-command provision (CLI)

From repo root (requires `az login`):

```powershell
.\azure\scripts\provision_all.ps1
```

This creates in **eastus** (GPU-capable for Container Apps):

- Resource group `rg-atcr`
- Storage account + container `atcr`
- ACR + cloud image build (`az acr build` — no local Docker)
- Log Analytics + Container Apps environment with `Consumption-GPU-NC8as-T4`
- Container App `ca-atcr-api` (single GPU replica)

Resource names are suffixed from your subscription id (see `azure/deploy.env` after run).

Skip AML on first run if `az extension add --name ml` is slow:

```powershell
.\azure\scripts\provision_all.ps1 -SkipAml
```

## Stage A (manual) — Storage only

```powershell
$RG = "rg-atcr"
$LOC = "westus3"
$SA = "atcrstoreXXXX"

az group create -n $RG -l $LOC
az storage account create -g $RG -n $SA -l $LOC --sku Standard_LRS
az storage container create --account-name $SA -n atcr --auth-mode login

# SAS for AzCopy (adjust expiry)
az storage container generate-sas `
  --account-name $SA -n atcr --permissions racwdl `
  --expiry (Get-Date).AddDays(7).ToString("yyyy-MM-ddTHH:mmZ") `
  --auth-mode login --as-user
```

Upload dataset:

```powershell
.\azure\scripts\azcopy_upload_dataset.ps1 `
  -StorageAccountName $SA `
  -SasToken "?sv=..."
```

## Stage B — Azure ML training

1. Create workspace + GPU compute cluster (`Standard_NC4as_T4_v3`, low-priority).
2. Register Blob datastore pointing at `atcr/datasets/detection_dataset`.
3. Submit job:

```powershell
az ml job create -f azure/aml/job_yolov8m.yml -g $RG -w mlw-atcr
```

Hyperparams match [`train_yolov8m_gpu.sh`](../atcr-system/scripts/train_yolov8m_gpu.sh):

`yolov8m` · `imgsz=960` · `batch=8` · `epochs=150` · `patience=30`

4. Promote weights:

```powershell
.\azure\scripts\promote_model.ps1 `
  -StorageAccountName $SA `
  -SourceBlob "models/runs/<run_id>/yolo_coach.pt" `
  -ContainerAppName ca-atcr-api `
  -ResourceGroup $RG
```

Or register an existing VM-trained `models/yolo_coach.pt` by uploading it to `models/yolo_coach.pt` with AzCopy.

## Stage C — Container Apps inference

1. Build & push image (see [`deploy_aca.ps1`](../azure/scripts/deploy_aca.ps1)).
2. Create ACA environment with a **GPU workload profile** (T4).
3. Deploy app from [`azure/aca/containerapp.yaml`](../azure/aca/containerapp.yaml) (edit placeholders).
4. Confirm:

```bash
curl https://<aca-fqdn>/health
# Expect cuda_available: true
```

**Replica policy:** `minReplicas=1`, `maxReplicas=1` — FastAPI uses in-process `BackgroundTasks`; do not scale out without a shared job queue.

## Stage D — Vercel cutover

In Vercel → Environment Variables:

| Name | Value |
|------|--------|
| `NEXT_PUBLIC_API_URL` | `https://<aca-fqdn>` |

Redeploy frontend. Smoke-test upload → poll → count.

Details: [VERCEL_DEPLOY.md](VERCEL_DEPLOY.md).

## Stage E — Deallocate NC T4 VM

After ACA `/health` is green and one end-to-end demo works:

```powershell
az vm deallocate -g <vm-rg> -n <vm-name>
```

Do **not** delete the VM in this pass (disk retained for rollback). Update local `NEXT_PUBLIC_API_URL` away from `http://20.55.4.254:8000`.

## Cost notes

- Pay GPU minutes for AML training jobs; prefer low-priority/spot for 150-epoch runs.
- ACA GPU replica is the always-on cost for demos — stop/scale carefully when idle.
- Leaving the old NC T4 VM running **and** ACA doubles GPU spend — deallocate the VM after cutover.

## Cost control

**Stop GPU spend when not demoing:**

```powershell
.\azure\scripts\stop_costs.ps1
```

This sets Container App `minReplicas=0` (no always-on T4) and deallocates the legacy NC T4 VM if it was running.

**Before a demo:**

```powershell
.\azure\scripts\start_api.ps1
```

| Resource | Idle cost | Action |
|----------|-----------|--------|
| `ltx2.3gguftesting` VM | High (GPU) | Already **deallocated** |
| `ca-atcr-api` (GPU) | High at min=1 | Now **minReplicas=0** |
| Blob + ACR Basic | Low | Keep (data + image) |
| `cae-atcr` environment | Low fixed | Keep (needed for ACA) |

Do **not** run the old VM and ACA GPU at the same time.

## Cutover checklist

- [ ] Storage + `atcr` container created in GPU-capable region
- [ ] Dataset uploaded via AzCopy (no SCP)
- [ ] AML job succeeds **or** existing `yolo_coach.pt` uploaded to Blob
- [ ] `models/yolo_coach.pt` present in Blob
- [ ] ACA image deployed; `/health` shows CUDA
- [ ] Vercel `NEXT_PUBLIC_API_URL` → ACA HTTPS
- [ ] Browser CORS OK (origin in `CORS_ORIGINS`)
- [ ] One full upload → count demo
- [ ] NC T4 VM deallocated

## Repo map

| Path | Role |
|------|------|
| `azure/aml/` | Training job + environment |
| `azure/aca/` | Dockerfile + Container App YAML |
| `azure/scripts/provision_all.ps1` | **One-shot CLI provision** (Blob + ACR + ACA GPU) |
| `atcr-system/app/storage/blob.py` | Blob download/upload helpers |
| `atcr-system/app/config.py` | Blob + CORS settings |
