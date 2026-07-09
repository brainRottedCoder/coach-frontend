# ATCR Frontend

Railway-themed Next.js console for **Automatic Train Composition Recognition**. Upload station footage, poll the FastAPI backend, and view coach counts, type breakdown, and rake composition.

## Prerequisites

- Node.js 18+
- ATCR API running from `atcr-system` (Python venv with models installed)

## Setup

```powershell
cd frontend
copy .env.local.example .env.local
npm install
```

## Run

**Terminal 1 — API** (from `atcr-system`):

```powershell
.\venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8000
```

**Terminal 2 — UI**:

```powershell
cd frontend
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Flow

1. Upload `.mp4` / `.avi` / `.mov` / `.mkv`
2. App calls `POST /jobs/upload`
3. Polls `GET /jobs/{job_id}` until `COMPLETED`
4. Loads `GET /jobs/{job_id}/type_count` and renders results

Set `NEXT_PUBLIC_API_URL` in `.env.local` if the API is not on port 8000.
