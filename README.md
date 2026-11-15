# EduLite

EduLite is a local-first study app for importing previous-year papers, reviewing extracted questions, exploring exam patterns, estimating next-exam topic coverage, discovering free study resources, and generating original practice papers with answers.

## What is included

- FastAPI REST API with email/password registration, signed JWT sessions, per-user private subjects and uploads, and SQLite persistence through SQLAlchemy.
- PDF, DOCX, Markdown, plain-text, and common scanned/image uploads (PNG/JPG/WEBP/BMP/TIFF); PDF text extraction, Tesseract OCR with a bundled RapidOCR CPU fallback for scanned PDFs and images, heuristic question splitting, topic/type/difficulty tagging, and editable low-confidence questions. Uploads first appear as an editable preview; select **Save questions to library** to persist them. Unsupported formats such as legacy `.doc`, archives, audio, and video are rejected with a supported-format message because they cannot be reliably extracted by this pipeline.
- Topic/year/marks/type/difficulty analytics, question-family similarity flags, a recency baseline and optional logistic-regression/XGBoost estimates with explicit uncertainty notices and rolling-origin backtest metrics when enough dated papers are available.
- Retrieval-augmented practice-paper generation with a request-scoped TF-IDF cosine-similarity vector index over private PYQs. A recency baseline is blended with logistic regression when there is enough training history and with XGBoost when installed and the dataset is larger. Students can enter a custom computer-science topic; choosing Numerical also provides topic-specific YouTube searches for worked numerical examples. With no API key, an offline practice generator and structured revision guide are available; setting `GEMINI_API_KEY` enables Gemini question and study-guide generation.
- Curated-resource discovery restricted to HTTPS results from the allowlisted education domains in `backend/resource_service.py`. Set `GOOGLE_SEARCH_API_KEY` and `GOOGLE_SEARCH_ENGINE_ID` to use Google Programmable Search in the app; otherwise DuckDuckGo is used. In Study Materials, students can choose a syllabus topic or enter a custom topic, search curated free resources, and open Google Web links for additional reading or YouTube playlists. Saved bookmarks, revision guides, practice attempts, and PDF/DOCX exports are included.
- A Next.js App Router frontend built with React, TypeScript, Tailwind CSS, Lucide icons, and Recharts, with a mobile bottom navigation and a responsive desktop sidebar.
- A dashboard study-hour counter with start, pause, and session reset controls. Focus totals persist in the current browser per account; signing out pauses the active session.
- A reproducible synthetic sample PYQ dataset for immediate local testing.
- Retrieval uses an in-memory FAISS cosine index with `all-MiniLM-L6-v2` embeddings when available; otherwise it uses the built-in TF-IDF cosine vector index. Windows uses the in-memory cosine implementation unless FAISS is installed separately.

The built-in classifier, OCR split confidence, similarity matching, and next-exam probability are heuristic estimates. They should support revision planning, not be treated as guarantees or as a substitute for checking extracted papers and answers.

## Requirements

- Python 3.11 or newer.
- Tesseract OCR is optional for scanned PDFs and image uploads. If available, EduLite uses it; otherwise the RapidOCR CPU fallback runs locally. The first fallback OCR use downloads its recognition models, so allow internet access for that first run. On Windows, Tesseract can optionally be installed with `winget install --id UB-Mannheim.TesseractOCR -e --source winget`; if installed in a custom folder, set `TESSERACT_CMD` in `.env` to its full executable path. Digital PDFs, DOCX, Markdown, and text files do not require OCR.
- A Gemini API key is optional. Resource discovery requires internet access; the rest of the app runs locally.
- Node.js 20.9 or newer and npm for the Next.js frontend.

## Install and initialize

From the project root in PowerShell:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
Copy-Item .env.example .env
```

Edit `.env` and set `JWT_SECRET` to a unique random value of at least 32 characters. To enable Gemini, set `GEMINI_API_KEY`. To connect in-app search to Google, enable the Google Custom Search JSON API in Google Cloud, create a Programmable Search Engine configured for trusted education sites, then set both `GOOGLE_SEARCH_API_KEY` and `GOOGLE_SEARCH_ENGINE_ID`. Leave both blank to use DuckDuckGo. The direct Google Search button works without an API key. The default SQLite database is `edulite.db` in the project root.

Install the frontend dependencies:

```powershell
Set-Location frontend
npm install
Set-Location ..
```

Create the schema and sample subjects/questions:

```powershell
python -m backend.seed
```

The API also creates any missing schema tables when it starts.

To enable sentence-transformer embeddings instead of the default TF-IDF index, install the optional ML dependencies:

```powershell
pip install -r requirements-ml.txt
```

The first semantic search downloads the `all-MiniLM-L6-v2` model. The default installation is fully functional offline and does not download model weights. On Windows, FAISS is excluded from that pip install because upstream wheels may not be available; semantic retrieval still runs with scikit-learn.

## Run both servers

Open two PowerShell windows at the project root and activate the environment in each.

Backend:

```powershell
.\.venv\Scripts\Activate.ps1
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Frontend:

```powershell
Set-Location frontend
npm run dev
```

Open <http://localhost:3000>. The API documentation is at <http://127.0.0.1:8000/docs>. Register an account; the four seeded example subjects and their synthetic sample papers are available immediately.

After installing dependencies, you can instead start both local servers and seed the sample data with one command. The script prefers `.venv` when present; otherwise it uses the Python installation on `PATH`:

```powershell
.\start_edulite.ps1
```

The script opens the API and frontend in separate windows. If the matching EduLite service is already listening on its default port, it reuses that service; it stops with an explicit message if another app owns a required port. Close the server windows to stop services started by the script.

The frontend sends API requests through its same-origin `/api` proxy to `http://127.0.0.1:8000` by default, avoiding browser CORS and localhost resolution issues. To run the API on a different address, set `EDULITE_API_SERVER_URL` in the environment before starting the frontend (for example, `http://127.0.0.1:8010`).

For deployment, set `ENVIRONMENT=production`, configure a strong `JWT_SECRET`, set `DATABASE_URL` to a managed PostgreSQL URL such as `postgresql+psycopg://user:password@host/database`, set exact `CORS_ORIGINS`, and serve the frontend over HTTPS. Keep API keys in the backend environment only. If Gemini is enabled, retrieved syllabus text, PYQs, and resource snippets are sent to Google for generation and verification; do not configure it unless that processing is acceptable for your users. Use a managed OCR service or provision Tesseract on the backend host for scanned files.

## API outline

- `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`
- `GET/POST /api/subjects`, `GET /api/subjects/{id}/questions`, `POST /api/subjects/{id}/upload` (extract preview), `POST /api/subjects/{id}/questions/import` (save reviewed questions)
- `PUT /api/questions/{id}`, `GET /api/subjects/{id}/analytics`, `GET /api/subjects/{id}/predictions`
- `POST /api/subjects/{id}/papers`, `GET /api/papers`, `GET /api/papers/{id}/export?format=pdf|docx`
- `POST /api/subjects/{id}/resources/discover`, `GET /api/subjects/{id}/resources`, `PUT /api/resources/{id}/bookmark`
- `GET /api/search/status` reports the configured in-app resource-search provider.
- `POST /api/papers/{id}/attempt`

All `/api` endpoints other than health and authentication require a bearer token. Uploads and generated papers remain private to the owning account; seeded public sample questions are shared read-only.

## Run tests

```powershell
python -m pytest
```
