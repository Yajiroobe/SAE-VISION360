# Vision360 – Roadmap et Architecture (v1)

Objectif: Guidage « conseil » en temps réel pour PMR avec détection d’obstacles on‑device et intégration réservation. Priorité à la latence faible et à la fiabilité basique.

## Architecture Cible
- Mobile (Android natif, Kotlin)
  - Caméra: CameraX/Camera2 (YUV) → pipeline zero‑copy (Surface/GL)
  - Vision: MediaPipe Tasks + TFLite int8 (GPU/NNAPI auto) – modèle type YOLOv8n
  - Profondeur/SLAM: ARCore Depth + pose pour distance/plan au sol
  - Feedback: TTS + haptique; éventuel audio 3D simple
- Backend (FastAPI existant)
  - Auth/compte basique, réservation billets (stub d’abord)
  - Routage macro (OSRM/Google) pour conseil, pas obligatoire en v1
- Sources vidéo additionnelles (v2)
  - Lunettes Meta / chien robot: stream vers mobile; traitement sur mobile v1

## Périmètre Détection (v1)
- Classes: escaliers, portes, cônes/barrières (travaux), personnes/foule, dénivelés/curbs, flaques
- Sorties: bbox + distance/zone (proche/moyen/loin) + côté (gauche/droite/face)

## Jalons (6–8 semaines)
S1 — Setup & Données
- Choix appareils Android test, pipeline caméra, TTS/haptique
- Dataset local (clips campus/ville), petite annotation (10–20 clips / classe)

S2 — POC Vision temps réel
- Intégration modèle int8 (TFLite/MediaPipe), cible ≥15 FPS
- Heuristique distance (ARCore depth/échelle bbox), zones d’alerte, métriques FPS/latence

S3 — Micro‑guidage
- Pose ARCore + évitement simple (contourner gauche/droite)
- Enregistrement/replay de séquences pour debug

S4 — Réservation & Itinéraires
- Écrans réservation (mock d’abord), OSRM/Google Directions pour conseil
- Handoff destination → micro‑guidage

S5 — Intégrations périphériques (optionnel)
- Stream lunettes/robot → mobile, mesures de latence bout‑en‑bout

S6 — Accessibilité & Tests terrain
- Modes accessibilité, SOS/stop, disclaimers « conseil »
- Tests supervisés (3–5 utilisateurs), collecte métriques anonymisées on‑device

## Cibles Performance
- Latence décision < 100 ms (camera→feedback), 15–30 FPS
- Énergie: session 30–45 min sans surchauffe notable
- Précision utile ≥ 0.7 mAP sur classes clés (conditions diurnes)

## Risques & Plans B
- Perf device faible → réduire résolution/classes, tracking inter‑frames, quantization/pruning
- Accès SDK lunettes/robot incertain → fallback smartphone caméra
- Indoor maps indisponibles → graphe manuel local d’un site

## Répartition Équipe (3 devs)
- Dev A: Modèle + intégration MediaPipe/TFLite + Depth
- Dev B: App Android (UI/UX accessibilité, TTS/haptique, métriques)
- Dev C: Backend réservation + routage + contrat API

## Critères de succès (v1)
- Démo terrain: parcours 100–200 m avec ≥15 FPS et alertes pertinentes
- Réservation scénarisée qui alimente un guidage « conseil » jusqu’au point d’arrivée
- Journal latence/FPS stable, <5% drops soutenus

