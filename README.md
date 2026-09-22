# AgriN AI 🌾

**Evidence-grounded regenerative agricultural intelligence for India, with an open-data architecture designed for cross-border interoperability.**

AgriN combines live weather, model-derived soil information, Sentinel-2 satellite observations, historical intelligence and Gemini reasoning into farmer-facing decision support.

> **Data integrity principle:** AgriN does not fabricate environmental measurements. When a source is unavailable, the product surfaces the limitation instead of inventing a value.

## What AgriN does

### 1. Farm Intelligence
Collects location-based weather, soil and satellite observations and presents them as farm intelligence.

### 2. AI Agro-Advisory
Uses supplied observations as evidence for practical agricultural decision support. Missing values remain missing.

### 3. Crop Doctor
Accepts a crop/leaf image and uses Gemini vision for evidence-aware visual decision support. It does not claim a definitive diagnosis or provide chemical dosage.

### 4. Regenerative Farming
Builds regenerative farming guidance from available weather and soil evidence.

### 5. Historical Intelligence
Combines historical weather and Sentinel-2 observations to help inspect changes over time. Historical relationships are presented as observations, not automatic causal conclusions.

### 6. BRICS-ready Data Network
Exports an open JSON observation contract using WGS84 coordinates, source attribution and country-neutral fields, with validation support.

### 7. AgriN Intelligence Agent
The central decision loop:

```text
FARMER INPUT
    ↓
GATHER
    ├── Weather
    ├── Soil
    ├── Satellite
    └── Historical observations
    ↓
EVIDENCE PACK
    ↓
GEMINI REASONING
    ↓
EXPLAINABLE DECISION SUPPORT
    ├── Recommendations
    ├── Observations
    ├── Next checks
    └── Limitations
```

Every recommendation is required to be grounded in the supplied evidence.

## Real data sources

| Signal | Source | Role |
|---|---|---|
| Weather | Open-Meteo | Current weather and precipitation probability |
| Soil | ISRIC SoilGrids 2.0 | Model-derived soil properties |
| Satellite | Sentinel-2 Collection 1 L2A / AWS Open Data | Satellite scenes and NDVI |
| Historical weather | Open-Meteo archive service | Historical weather context |
| Historical satellite | Sentinel-2 / AWS Open Data | Historical NDVI observations |
| Reasoning | Google Gemini API | Evidence-grounded language reasoning |

### Important data limitations

- **SoilGrids** is model-derived information, not a laboratory soil test.
- **NDVI** is a satellite-derived observation and, where sampled at a point/window, is not automatically a whole-farm health score.
- Historical weather and NDVI are observations; AgriN does not automatically claim that one caused the other.
- If a required source is unavailable, AgriN reports the limitation.

## Architecture

```text
┌─────────────────────────────────────────────┐
│              Flutter Application            │
│                                             │
│ Dashboard · Farm Intelligence · Advisory   │
│ Crop Doctor · Regenerative · History       │
│ BRICS Network · Intelligence Agent         │
└──────────────────┬──────────────────────────┘
                   │ HTTP / JSON
                   ▼
┌─────────────────────────────────────────────┐
│                 FastAPI API                 │
│                                             │
│ /health                                     │
│ /soil                                        │
│ /satellite/search                            │
│ /satellite/ndvi                              │
│ /disease/analyze                             │
│ /advisory                                    │
│ /regenerative/*                              │
│ /historical/*                                │
│ /interoperability/*                          │
│ /agent/analyze                               │
└───────┬──────────┬──────────┬───────────────┘
        │          │          │
        ▼          ▼          ▼
   Open-Meteo  SoilGrids  Sentinel-2/AWS
                         │
                         ▼
                    Gemini API
```

## Technology stack

### Frontend
- Flutter / Dart
- Flutter Animate
- GoRouter
- HTTP
- Image Picker

### Backend
- Python 3.12
- FastAPI
- Pydantic
- HTTPX
- Rasterio

### Intelligence
- Google Gemini API
- Evidence-grounded prompts
- Structured JSON responses

## Platforms

Flutter provides one application codebase for:

- Web
- Android
- iOS
- Windows

## Local development

### Frontend

```bash
flutter pub get
flutter run -d chrome
```

### Backend

Create `backend/.env` with your Gemini credential:

```env
GEMINI_API_KEY=your_key_here
```

Then:

```bash
cd backend
python -m venv .venv
# Windows
.venv\Scripts\activate
pip install -r requirements.txt
pip install python-dotenv
uvicorn main:app --reload
```

Backend:

```text
http://127.0.0.1:8000
```

Frontend:

```text
http://localhost:PORT
```

Never commit `.env` or API keys.

## Quality checks

GitHub Actions automatically validates:

- Flutter dependencies
- Flutter static analysis
- Flutter web release build
- Python backend dependency installation
- Python backend compilation

Workflows:

```text
.github/workflows/flutter-ci.yml
.github/workflows/backend-ci.yml
```

## Project structure

```text
agrin-ai/
├── lib/
│   ├── features/
│   │   ├── dashboard/
│   │   ├── farm_intelligence/
│   │   ├── ai_advisory/
│   │   ├── crop_doctor/
│   │   ├── regenerative_farming/
│   │   ├── historical_intelligence/
│   │   ├── brics_network/
│   │   └── intelligence_agent/
│   ├── services/
│   ├── theme/
│   └── app.dart
│
├── backend/
│   ├── main.py
│   ├── agent.py
│   ├── historical.py
│   ├── regenerative.py
│   └── interoperability.py
│
└── .github/
    └── workflows/
        ├── flutter-ci.yml
        └── backend-ci.yml
```

## Why the Intelligence Agent matters

AgriN is not designed as a generic agricultural chatbot.

The agent is an orchestration layer that:

1. resolves the farmer's location,
2. gathers observations from external scientific/open-data sources,
3. packages those observations as evidence,
4. asks Gemini to reason only from that evidence,
5. returns recommendations with supporting evidence,
6. exposes next checks and limitations.

This creates a traceable path from **data → evidence → reasoning → action**.

## Current status

- ✅ Flutter multi-page application
- ✅ Live weather integration
- ✅ SoilGrids integration
- ✅ Sentinel-2 scene discovery
- ✅ Real NDVI sampling
- ✅ Historical intelligence
- ✅ Crop image analysis
- ✅ Regenerative farming guidance
- ✅ BRICS-ready JSON interoperability
- ✅ Intelligence Agent
- ✅ Evidence-grounded Gemini reports
- ✅ Automated Flutter CI
- ✅ Automated backend CI

## Responsible use

AgriN is agricultural decision-support software. It should not replace field inspection, laboratory soil analysis, qualified agronomy advice, or other professional verification where those are required.

## License

Project license and attribution details can be added before public release.
