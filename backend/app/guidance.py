from typing import Dict, List, Optional

from fastapi import APIRouter
from pydantic import BaseModel, Field


router = APIRouter()


class Detection(BaseModel):
    class_name: str = Field(..., alias="class")
    score: float = Field(..., ge=0.0, le=1.0)
    zone: Optional[str] = Field(None, description="near|mid|far")
    side: Optional[str] = Field(None, description="left|center|right")
    ocr: Optional[str] = None
    context: Optional[str] = None


class EnrichRequest(BaseModel):
    detection: Detection
    profile_hint: Optional[str] = None


class EnrichBatchRequest(BaseModel):
    detections: List[Detection]
    profile_hint: Optional[str] = None


class EnrichResponse(BaseModel):
    summary: str
    attributes: Dict[str, str] = {}
    risks: List[str] = []
    class_name: Optional[str] = None
    zone: Optional[str] = None
    side: Optional[str] = None


class AdviceRequest(BaseModel):
    profile: str
    context: str
    detections: List[Detection]
    enrichments: List[EnrichResponse] = []


class AdviceResponse(BaseModel):
    priority: str
    channel: List[str]
    messages: List[str]


OBSTACLE_DESCRIPTIONS = {
    "person": "Personne à proximité",
    "crowd": "Groupe dense",
    "stairs": "Escalier",
    "curb": "Dénivelé",
    "door": "Porte",
    "cone": "Cône de chantier",
    "barrier": "Barrière / obstacle fixe",
    "puddle": "Zone glissante"
}

RETAIL_DESCRIPTIONS = {
    "product": "Article en rayon",
    "price_tag": "Etiquette de prix",
    "barcode": "Code-barres visible",
    "bottle": "Bouteille / boisson",
    "can": "Boîte ou canette",
    "produce": "Fruit ou légume",
    "package": "Produit emballé"
}

RESTAURANT_DESCRIPTIONS = {
    "table": "Table",
    "chair": "Chaise",
    "tray": "Plateau",
    "cutlery": "Couverts",
    "terminal": "Terminal de paiement",
    "dish": "Plat servi"
}


def describe_detection(det: Detection) -> EnrichResponse:
    cls = det.class_name.lower()
    if cls in OBSTACLE_DESCRIPTIONS:
        summary = OBSTACLE_DESCRIPTIONS[cls]
    elif cls in RETAIL_DESCRIPTIONS:
        summary = RETAIL_DESCRIPTIONS[cls]
    elif cls in RESTAURANT_DESCRIPTIONS:
        summary = RESTAURANT_DESCRIPTIONS[cls]
    else:
        summary = f"Objet {det.class_name}"

    risks: List[str] = []
    if cls in {"person", "crowd", "stairs", "curb", "cone", "barrier", "puddle"}:
        if det.zone == "near":
            risks.append("Obstacle proche")
        if cls == "puddle":
            risks.append("Risque de glissade")
        if cls == "stairs":
            risks.append("Prévoir montée/descente")

    attrs: Dict[str, str] = {
        "zone": det.zone or "unknown",
        "side": det.side or "unknown",
        "score": f"{det.score:.2f}"
    }
    if det.ocr:
        attrs["ocr"] = det.ocr
    if det.context:
        attrs["context"] = det.context

    return EnrichResponse(summary=summary, attributes=attrs, risks=risks, class_name=det.class_name, zone=det.zone, side=det.side)


@router.post("/enrich", response_model=EnrichResponse)
def enrich_detection(payload: EnrichRequest) -> EnrichResponse:
    """Stub d'enrichissement: décrit l'objet et ajoute des risques simples."""
    return describe_detection(payload.detection)


@router.post("/enrich/batch", response_model=List[EnrichResponse])
def enrich_batch(payload: EnrichBatchRequest) -> List[EnrichResponse]:
    """Retourne les enrichissements pour chaque détection."""
    return [describe_detection(det) for det in payload.detections]


@router.post("/advise", response_model=AdviceResponse)
def advise(payload: AdviceRequest) -> AdviceResponse:
    """Génère une consigne simple en fonction du profil et des risques."""
    messages: List[str] = []
    priority = "info"

    for det in payload.detections:
        if det.zone == "near":
            priority = "high"
            side = det.side or "devant"
            messages.append(f"Obstacle {det.class_name} {side}, ralentir")

    for enr in payload.enrichments:
        for risk in enr.risks:
            messages.append(f"{enr.summary}: {risk}")

    if not messages:
        messages.append("Aucun obstacle critique détecté")

    channels = ["voice"]
    if priority == "high":
        channels.append("haptic")

    return AdviceResponse(priority=priority, channel=channels, messages=messages)
