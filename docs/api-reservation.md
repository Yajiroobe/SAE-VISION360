# API Réservation – Vision360 (v1 stub)

Base URL: `/api`

## POST /reservations
Créer une réservation (stub).
- Body (JSON):
```json
{
  "origin": "Gare A",
  "destination": "Gare B",
  "datetime_utc": "2025-10-15T12:00:00Z",
  "passenger": {"name": "Alice", "pmr_profile": "fauteuil"}
}
```
- 200 OK →
```json
{
  "id": "uuid",
  "origin": "...",
  "destination": "...",
  "datetime_utc": "...",
  "passenger": {"name": "Alice", "pmr_profile": "fauteuil"},
  "status": "pending"
}
```

## GET /reservations/{id}
Récupérer une réservation.
- 200 OK → Reservation
- 404 Not Found

## GET /reservations
Lister les réservations (in‑memory en v1).

Remarques:
- Stockage en mémoire pour la démo; à remplacer par un stockage persistant ultérieurement.
- Le backend n’exécute pas d’algorithmes de vision; la vision est on‑device.

