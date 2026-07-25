# Tashila API

Production-ready FastAPI backend for the Tashila ride-hailing platform. Deployed on [Railway](https://railway.app) via **Nixpacks** (pure Python, no Docker).

## Stack

- **FastAPI** + **Uvicorn**
- **MongoDB** via Motor + Beanie ODM
- **Redis** for caching, OTP rate limits, and sessions
- **JWT** auth (user + admin) with **python-jose** and **passlib**
- **Socket.IO** scaffold for real-time trip updates

## Project layout

```
tashila-api/
├── app/
│   ├── core/          # config, DB, Redis, security, deps, exceptions
│   ├── models/        # Beanie documents
│   ├── routers/       # HTTP route modules
│   ├── services/      # business logic
│   ├── socket/        # Socket.IO server
│   └── utils/         # geo, pagination
├── scripts/           # DB seed utilities
├── tests/
├── main.py            # local shim (production uses app.main:app)
├── requirements.txt
├── runtime.txt        # python-3.12.3
├── nixpacks.toml
├── railway.toml
└── Procfile
```

## Local development

### 1. Prerequisites

- Python 3.12.3 (see `runtime.txt`)
- MongoDB and Redis instances (local or cloud)

### 2. Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Edit `.env` and set secrets to **at least 32 characters** (`JWT_SECRET`, `JWT_REFRESH_SECRET`, `ADMIN_JWT_SECRET`).

### 3. Run

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- API docs: http://localhost:8000/docs
- Health: http://localhost:8000/health

### 4. Seed data

```bash
python -m scripts.seed_admin
python -m scripts.seed_pricing
```

### 5. Tests

```bash
pytest
```

## Railway deployment

1. Create a new Railway project and connect this repository.
2. Add **MongoDB** and **Redis** plugins (or external URLs).
3. Set all variables from `.env.example` in the Railway dashboard.
4. Railway reads `nixpacks.toml`, `railway.toml`, and `runtime.txt` automatically.

| File | Purpose |
|------|---------|
| `nixpacks.toml` | Install deps and start Uvicorn |
| `railway.toml` | Builder, health check `/health`, restart policy |
| `Procfile` | Fallback process definition |
| `runtime.txt` | Python 3.12.3 for Nixpacks |

**Start command:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 1`

**Health check:** `GET /health` → `{"status":"ok"}`

## Environment variables

See `.env.example` for the full list. Required for startup:

| Variable | Description |
|----------|-------------|
| `MONGO_URI` | MongoDB connection string |
| `MONGO_DB_NAME` | Database name (default: `tashila`) |
| `REDIS_URL` | Redis connection URL |
| `JWT_SECRET` / `JWT_REFRESH_SECRET` | User tokens (min 32 chars) |
| `ADMIN_JWT_SECRET` | Admin tokens (min 32 chars) |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins |

Optional: `FCM_SERVER_KEY`, `UPLOAD_DIR`, OTP limits (`MAX_OTP_ATTEMPTS`, `OTP_WINDOW_SECONDS`).

## Dispatch simulation

Load-test the exclusive offer engine against staging or production:

```bash
cd tashila-api
SIM_NUM_CLIENTS=50 SIM_NUM_DRIVERS=20 python -m scripts.simulate.run_simulation
```

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SIM_BASE_URL` | Railway production URL | API + Socket.IO base |
| `SIM_NUM_CLIENTS` | `100` | Virtual clients |
| `SIM_NUM_DRIVERS` | `30` | Virtual drivers |
| `SIM_TRIP_CYCLES` | `3` | Trips per client |

The report includes offer→accept latency, expired offers, and blocked accepts after `expiresAt`.

## API conventions

- JSON error shape: `{"error": {"code": "...", "message": "...", "details": ...}}`
- Auth header: `Authorization: Bearer <token>`
- Idempotency: `X-Idempotency-Key` header (via `get_idempotency_key` dep)

## License

Proprietary — Tashila.
