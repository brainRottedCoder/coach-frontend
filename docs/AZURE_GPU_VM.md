# Azure T4 GPU VM — deployment guide (DEPRECATED for serving)

> **Deprecated for production serving.** Prefer Blob + Azure ML + Container Apps GPU.
> See **[AZURE_FULL_ARCHITECTURE.md](AZURE_FULL_ARCHITECTURE.md)**.
>
> Keep this VM only as a temporary bridge or emergency rollback. After ACA `/health`
> is green and Vercel points at the ACA HTTPS URL, **deallocate** the VM:
>
> ```powershell
> az vm deallocate -g <vm-resource-group> -n <vm-name>
> ```
>
> Do not delete the VM/disk in the first cutover pass (rollback). Leaving it
> **Running** while ACA is also up doubles GPU cost.

Use this guide only when you still need the NC-series VM (e.g. `Standard_NC4as_T4_v3`) for ad-hoc SSH debugging.

## VM details (your instance)

| Item | Value |
|------|-------|
| Public IP | `20.55.4.254` |
| SSH key | `ltx2.3gguftesting_key.pem` (keep private — never commit) |
| SSH port | **443** (port 22 blocked on some WiFi; VM listens on both) |
| Default user | `azureuser` |

## 1. Open port 443 in Azure NSG (required for your WiFi)

Port 22 may work from some networks but is blocked on your WiFi. The VM **already listens on port 443** for SSH. You must allow it in Azure:

1. **Virtual machine** → your VM → **Networking** (or NSG)
2. **Inbound port rules** → Add rule:
   - Source: `Your IP` (or `Any` for testing)
   - Destination port: **443**
   - Protocol: TCP
   - Action: Allow
   - Priority: e.g. `100`
3. Confirm the VM is **Running**

Optional — API + frontend:

| Port | Service |
|------|---------|
| 8000 | FastAPI (`uvicorn`) |
| 3000 | Next.js dev server |

## 2. SSH from Windows (port 443)

```powershell
cd "C:\Users\Shubh Varshney\Downloads\coach-detection"

# Interactive shell (default port 443)
.\scripts\ssh_azure_vm.ps1

# Or explicit port / command
.\scripts\ssh_azure_vm.ps1 -Port 443 -Command "df -h /"
```

Manual SSH (fixes Windows PEM line-ending issue via script):

```powershell
# Script copies key to %TEMP%\azure_vm_key.pem with Unix line endings
ssh -i $env:TEMP\azure_vm_key.pem -p 443 azureuser@20.55.4.254
```

If `azureuser` fails, try the username you chose when creating the VM.

## 3. LTX model cleanup (done)

The VM previously had ~37 GB of LTX GGUF / ComfyUI under `~/ltx-poc`. This was removed:

| Before | After |
|--------|-------|
| 47 GB used | **11 GB used** |
| 77 GB free | **113 GB free** |

Re-run if needed: `bash scripts/cleanup_ltx_gguf.sh`

After SSH works:

```bash
# Option A — clone from GitHub and run setup script
git clone https://github.com/brainRottedCoder/coach-detection.git
cd coach-detection/atcr-system
bash scripts/setup_azure_gpu_vm.sh
```

Or copy your local repo with `scp` (port 443):

```powershell
scp -i $env:TEMP\azure_vm_key.pem -P 443 -r "C:\Users\Shubh Varshney\Downloads\coach-detection" azureuser@20.55.4.254:~/
```

Then on the VM:

```bash
cd ~/coach-detection/atcr-system
bash scripts/setup_azure_gpu_vm.sh
```

## 4. Start services

**API (GPU inference):**

```bash
cd ~/coach-detection/atcr-system
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Verify GPU:

```bash
curl http://localhost:8000/health
# Expect: "gpu": { "cuda_available": true, "device_name": "Tesla T4" }
```

**Frontend** (optional, on VM or locally):

```bash
cd ~/coach-detection/frontend
npm install
echo "NEXT_PUBLIC_API_URL=http://20.55.4.254:8000" > .env.local
npm run dev -- --hostname 0.0.0.0
```

## 5. Retrain for better accuracy (recommended on T4)

Current shipped weights are YOLOv8n. On GPU you can train a stronger model:

```bash
cd ~/coach-detection/atcr-system
source venv/bin/activate
python train_detector.py --model yolov8s.pt --device 0 --imgsz 960 --epochs 150 --batch 16
```

Weights are copied to `models/yolo_coach.pt` automatically.

## 6. Storage (128 GB SSD)

Plenty for this project:

| Item | Approx. size |
|------|----------------|
| Repo + venv + CUDA torch | ~8–12 GB |
| Models + OCR weights | ~500 MB |
| Raw videos + debug outputs | varies (tens of GB max) |

## 7. Security notes

- Do **not** commit `.pem` files (already in `.gitignore`)
- Restrict NSG rules to your IP when possible
- Rotate keys if the PEM was shared in chat or committed anywhere

## Troubleshooting

| Issue | Fix |
|-------|-----|
| SSH timeout on 443 | Open **NSG port 443** in Azure Portal (VM listens; firewall blocks externally) |
| `invalid format` PEM on Windows | Use `.\scripts\ssh_azure_vm.ps1` (fixes line endings) |
| Port 22 blocked on WiFi | Use `-p 443` after NSG rule is added |
| `cuda_available: false` | Install NVIDIA driver; reboot VM; reinstall `torch` with cu121 index |
| Slow OCR | EasyOCR uses GPU when `OCR_GPU=true` and CUDA is available |
| API unreachable from browser | Open NSG port 8000; use `--host 0.0.0.0` |
