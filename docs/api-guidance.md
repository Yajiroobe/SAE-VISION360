# API Guidance / Enrichissement (stub)

Base URL: `/api`

## POST /guidance/enrich
Transforme une détection brute en description + risques.

Request
```json
{
  "detection": {
    "class": "person",
    "score": 0.92,
    "zone": "near",
    "side": "left",
    "ocr": null,
    "context": "outdoor"
  }
}
```

Response
```json
{
  "summary": "Personne à proximité",
  "attributes": {"zone": "near", "side": "left", "score": "0.92"},
  "risks": ["Obstacle proche"]
}
```

## POST /guidance/enrich/batch
Même logique, mais accepte une liste.

Request
```json
{
  "detections": [
    {"class": "person", "score": 0.9, "zone": "near", "side": "left"},
    {"class": "handbag", "score": 0.7, "zone": "mid", "side": "center"}
  ],
  "profile_hint": "retail"
}
```

Response
```json
[
  {"summary": "Personne à proximité", "attributes": {...}, "risks": ["Obstacle proche"], "class_name": "person"},
  {"summary": "Article en rayon", "attributes": {...}, "risks": [], "class_name": "handbag"}
]
```

## POST /guidance/advise
Combine plusieurs détections/enrichissements pour renvoyer des consignes.

Request
```json
{
  "profile": "pmr_wheelchair",
  "context": "outdoor",
  "detections": [{"class": "person", "score": 0.9, "zone": "near", "side": "left"}],
  "enrichments": [{"summary": "Personne à proximité", "attributes": {"zone": "near"}, "risks": ["Obstacle proche"]}]
}
```

Response
```json
{
  "priority": "high",
  "channel": ["voice", "haptic"],
  "messages": ["Obstacle person left, ralentir", "Personne à proximité: Obstacle proche"]
}
```

Ces stubs seront remplacés par l'orchestration des LLM (détection → description détaillée → consignes profilées).
