# Coach Detection

This folder is the **GitHub repository root** — pushed to [github.com/brainRottedCoder/coach-detection](https://github.com/brainRottedCoder/coach-detection).

All setup and usage instructions are in **[atcr-system/README.md](atcr-system/README.md)**.

```powershell
cd atcr-system
.\setup.ps1
python scripts/run_count.py --video data/raw_videos/YOUR_VIDEO.mp4 --save-debug
```

Azure target architecture (Blob + AML + Container Apps):

- [docs/AZURE_FULL_ARCHITECTURE.md](docs/AZURE_FULL_ARCHITECTURE.md)
- [docs/VERCEL_DEPLOY.md](docs/VERCEL_DEPLOY.md)

Other docs at this level (not on GitHub):

- [PRD_Train_Coach_Detection_System.md](PRD_Train_Coach_Detection_System.md)
- [MVP_Implementation_Guide.md](MVP_Implementation_Guide.md)
- [ATCR_Dataset_Research_Report.md](ATCR_Dataset_Research_Report.md)
