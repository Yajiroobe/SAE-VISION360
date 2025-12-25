import os
import json
from pathlib import Path

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field


router = APIRouter()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
# Par défaut, modèle vision rapide. Ajustable via GEMINI_MODEL (ex. gemini-1.5-flash).
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash-exp")
GEMINI_API_VERSION = os.getenv("GEMINI_API_VERSION", "v1beta")
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/"
    f"{GEMINI_API_VERSION}/models/{GEMINI_MODEL}:generateContent"
)

# DEBUG (dev uniquement) : afficher les premières lettres de la clé pour vérifier le chargement
if GEMINI_API_KEY:
    print(f"[DEBUG] GEMINI_API_KEY loaded (prefix): {GEMINI_API_KEY[:6]}...", flush=True)
else:
    print("[DEBUG] GEMINI_API_KEY is missing", flush=True)

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
PROFILE_PATH = Path(__file__).parent / "user_profiles.json"
try:
    _PROFILES = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
except FileNotFoundError:
    _PROFILES = {}


class DescribeRequest(BaseModel):
    image_b64: str = Field(..., description="Image encodée en base64 (avec ou sans préfixe data:)")
    prompt: str = Field(
        default="Décris précisément les produits/objets visibles, marques ou catégories, positions relatives.",
        description="Prompt texte pour la description",
    )


@router.post("/describe/gemini")
async def describe_gemini(payload: DescribeRequest) -> dict:
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY manquante côté serveur")

    b64 = payload.image_b64
    if "," in b64:  # data:image/jpeg;base64,...
        b64 = b64.split(",", 1)[1]

    body = {
        "contents": [
            {
                "parts": [
                    {"text": payload.prompt},
                    {
                        "inline_data": {
                            "mime_type": "image/jpeg",
                            "data": b64,
                        }
                    },
                ]
            }
        ]
    }

    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY,
    }

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(GEMINI_URL, headers=headers, json=body)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Appel Gemini échoué: {exc}") from exc

    if resp.status_code != 200:
        # renvoyer le texte complet de l'erreur Google pour diagnostic
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()
    parts = data.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    text = " ".join([p.get("text", "") for p in parts if isinstance(p, dict)]).strip()

    # Payload prêt à être transmis à un second LLM (Groq ou autre)
    structured = {
        "text": text,
        "raw_parts": parts,
        "prompt": payload.prompt,
        "model": GEMINI_MODEL,
    }
    return {"structured": structured, "raw": data}


class GroqRequest(BaseModel):
    description: str = Field(..., description="Texte descriptif (ex: sortie Gemini)")
    profile: str = Field(default="default", description="Profil utilisateur (pour les consignes)")
    instruction: str = Field(
        default="Génère un JSON minimal : {\"summary\": string, \"risks\": [string], \"actions\": [string]}",
        description="Instruction envoyée au LLM Groq",
    )
    profile_override: dict | None = Field(
        default=None, description="Profil inline pour écraser le catalogue"
    )


@router.post("/describe/groq")
async def describe_groq(payload: GroqRequest) -> dict:
    if not GROQ_API_KEY:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY manquante côté serveur")

    profile_data = payload.profile_override or _PROFILES.get(payload.profile) or _PROFILES.get("default", {})

    system_prompt = (
        "Tu es un assistant de sécurité pour la mobilité PMR. "
        "Réponds STRICTEMENT en JSON sans texte hors JSON. "
        "Inclue des risques potentiels et des actions/recommandations courtes."
    )

    user_prompt = (
        f"Profil: {payload.profile}\n"
        f"Données profil: {json.dumps(profile_data, ensure_ascii=False)}\n"
        f"Description:\n{payload.description}\n"
        f"Consigne de sortie: {payload.instruction}"
    )

    body = {
        "model": GROQ_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.2,
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {GROQ_API_KEY}",
    }

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(GROQ_URL, headers=headers, json=body)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Appel Groq échoué: {exc}") from exc

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()
    content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
    parsed = None
    try:
        parsed = json.loads(content)
    except Exception:
        parsed = None

    return {"structured": parsed, "raw_text": content, "raw": data}
