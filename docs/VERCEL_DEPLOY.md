# Vercel + Azure Container Apps backend

Frontend: [https://coach-frontend-eta.vercel.app/](https://coach-frontend-eta.vercel.app/)

**Preferred backend:** Azure Container Apps (GPU) — see [AZURE_FULL_ARCHITECTURE.md](AZURE_FULL_ARCHITECTURE.md).

The old NC T4 VM URL (`http://20.55.4.254:8000`) is **deprecated** after cutover. Deallocate the VM once ACA is healthy.

## Vercel environment variable

In **Vercel → Project → Settings → Environment Variables**, set:

| Name | Value |
|------|-------|
| `NEXT_PUBLIC_API_URL` | `https://<aca-fqdn>` |

Get the FQDN after deploy:

```powershell
az containerapp show -g rg-atcr -n ca-atcr-api --query "properties.configuration.ingress.fqdn" -o tsv
```

Redeploy the frontend after saving.

Local override (do not commit secrets):

```powershell
# frontend/.env.local
NEXT_PUBLIC_API_URL=https://<aca-fqdn>
```

## CORS

API `CORS_ORIGINS` must include the Vercel origin (default in config):

`https://coach-frontend-eta.vercel.app`

Set via Container App env when deploying (`deploy_aca.ps1 -CorsOrigins ...`).

## Verify backend

```bash
curl https://<aca-fqdn>/health
```

Expect `"cuda_available": true`, `"blob_configured": true`, and a Tesla T4 (or equivalent) device name.

Weights are pulled from Blob `models/yolo_coach.pt` on API startup — promote with:

```powershell
.\azure\scripts\promote_model.ps1 -StorageAccountName <sa> -LocalWeights "atcr-system\models\yolo_coach.pt" `
  -ContainerAppName ca-atcr-api -ResourceGroup rg-atcr
```

## Training (not on the API box)

Use Azure ML — do not train on the Container App:

```powershell
az ml job create -f azure/aml/job_yolov8m.yml -g rg-atcr -w mlw-atcr
```

## Legacy VM (rollback only)

If ACA is down and you still have the NC T4 allocated:

| Name | Value |
|------|-------|
| `NEXT_PUBLIC_API_URL` | `http://20.55.4.254:8000` |

NSG must allow TCP **8000**. Prefer deallocating the VM when ACA is primary to avoid double GPU cost.
