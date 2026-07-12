# Azure Blob layout — container `atcr`

Single source of truth for datasets, production weights, training artifacts, and optional job archives.

```
atcr/
  datasets/
    detection_dataset/          # YOLO images + labels + data.yaml (~8 GB)
  models/
    yolo_coach.pt               # Production weights (API pulls this on startup)
    runs/{run_id}/              # AML job outputs (best.pt, metrics, checkpoints)
  jobs/
    {job_id}/
      input.mp4                 # Optional upload archive
      result.json               # Count / multi-train result snapshot
```

## Consumers

| Path | Written by | Read by |
|------|------------|---------|
| `datasets/detection_dataset/` | AzCopy (`azcopy_upload_dataset.ps1`) | Azure ML training job |
| `models/yolo_coach.pt` | `promote_model.ps1` | FastAPI startup sync |
| `models/runs/{run_id}/` | AML job upload step | Model comparison / promote |
| `jobs/{job_id}/` | Inference API (optional) | Debugging / audit |

## Naming

- Container name is always `atcr` (override with env `BLOB_CONTAINER` only if needed).
- Production model blob path defaults to `models/yolo_coach.pt` (`MODEL_BLOB_PATH`).
