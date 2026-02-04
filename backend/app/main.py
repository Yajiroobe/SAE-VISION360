import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# Chargement minimal des variables d'environnement depuis .env ou .env.example (sans dépendance externe)
def _load_env_file():
    here = Path(__file__).resolve()
    candidates = [
        here.parent.parent.parent / ".env",          # racine du repo
        here.parent.parent / ".env",                 # dossier backend
        here.parent.parent.parent / ".env.example",  # fallback exemple racine
        here.parent.parent / ".env.example",         # fallback exemple backend
    ]
    env_path = next((p for p in candidates if p.exists()), None)
    if not env_path:
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        if not line or line.strip().startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        os.environ[key.strip()] = val.strip()  # écrase pour refléter le contenu du fichier .env/.env.example

# Charger l'environnement AVANT d'importer les routes
_load_env_file()

from .guidance import router as guidance_router
from .describe import router as describe_router

app = FastAPI(title="Vision360 API")

# CORS permissif (DEV) + fallback headers
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_origin_regex=".*",
    allow_credentials=False,  # doit rester False avec allow_origins="*"
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=86400,
)

@app.middleware("http")
async def add_cors_headers(request, call_next):
    if request.method == "OPTIONS":
        return JSONResponse(
            status_code=200,
            content={"status": "ok"},
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
                "Access-Control-Allow-Headers": "*",
                "Access-Control-Expose-Headers": "*",
                "Access-Control-Max-Age": "86400",
            },
        )

    response = await call_next(request)
    response.headers.setdefault("Access-Control-Allow-Origin", "*")
    response.headers.setdefault("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
    response.headers.setdefault("Access-Control-Allow-Headers", "*")
    response.headers.setdefault("Access-Control-Expose-Headers", "*")
    response.headers.setdefault("Access-Control-Max-Age", "86400")
    return response


@app.get("/health")
def health():
    return {"status": "ok"}

# Routes
app.include_router(guidance_router, prefix="/api/guidance", tags=["guidance"])
app.include_router(describe_router, prefix="/api", tags=["describe"])
