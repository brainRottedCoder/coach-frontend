# One-time AML compute + data setup

```powershell
$RG = "rg-atcr"
$WS = "mlw-atcr"
$LOC = "westus3"

az ml workspace create -g $RG -n $WS -l $LOC

# GPU cluster (T4) — low priority for cheaper training
az ml compute create `
  --name atcr-gpu-cluster `
  --type amlcompute `
  --size Standard_NC4as_T4_v3 `
  --min-instances 0 `
  --max-instances 1 `
  --tier low_priority `
  -g $RG -w $WS

az ml environment create -f azure/aml/environment.yml -g $RG -w $WS

# After dataset is in Blob under datasets/detection_dataset, create a data asset
# (adjust datastore path to match your workspaceblobstore / custom datastore):
az ml data create `
  --name atcr-detection-dataset `
  --version 1 `
  --type uri_folder `
  --path "azureml://datastores/workspaceblobstore/paths/datasets/detection_dataset" `
  -g $RG -w $WS
```

Then: `az ml job create -f azure/aml/job_yolov8m.yml -g $RG -w $WS`
