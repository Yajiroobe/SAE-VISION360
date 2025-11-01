# Playbook Latence – Vision360 (Android)

Objectif: Minimiser la latence E2E (capture → feedback) pour rester <100 ms avec FPS 15–30.

## Pipeline recommandé
1) CameraX/Camera2 en YUV → Surface/GL (pas de copies CPU)
2) Pré‑traitement shader (resize/normalisation) → tensor
3) Inférence TFLite int8 via MediaPipe Tasks (GPU delegate/NNAPI)
4) Post‑traitement (NMS, mapping classes) + tracking inter‑frames
5) Fusion distance (ARCore Depth) → zones proche/moyen/loin
6) Feedback TTS/haptique minimal, non bloquant

## Réglages clés
- Résolution entrée: côté long 320–416 px; adapter dynamiquement si FPS < seuil
- Délégué: GPU (Adreno) prioritaire; fallback NNAPI ou CPU multi‑threads
- Batch: 1; file de frames taille 1–2; drop frames si en retard
- Pré‑allocation: réutiliser tensors/buffers; pas d’alloc par frame
- NMS: utiliser implémentation du modèle/MediaPipe; limiter classes

## Mesure & télémétrie
- Timestamps: t_capture, t_pre, t_infer_start/end, t_post, t_feedback
- Derivés: latence E2E, FPS caméra, FPS inférence, % frames droppées
- Température/thermal throttling: lecture périodique + adaptation résolution
- Logging local circulaire (opt‑in); export manuel pour debug

## Profils device
- Mid‑range (Snapdragon 7xx): 320–384 px, GPU delegate, 15–25 FPS
- High‑end (Snapdragon 8 Gen): 416 px, GPU/NNAPI, 25–35 FPS
- Low‑end fallback: 256–320 px + tracking pour tenir 12–18 FPS

## Dépendances (Android)
- CameraX / Camera2
- ARCore (Depth API)
- TensorFlow Lite + MediaPipe Tasks (Object Detection)
- Kotlin coroutines/Flow pour pipeline asynchrone

## Tests de non‑régression
- Vidéos standardisées (lumière jour/nuit, pluie, foule)
- Bench script: moyenne/percentiles latence, FPS, drop rate, chauffe
- Budget: E2E <100 ms, stable ≥15 FPS durant 10 min

## Anti‑patterns
- Passer par couches JS/Dart (React Native/Flutter) pour le flux vidéo critique
- Copier les frames en Bitmaps à chaque étape
- Exécuter TTS/logiciel d’UI sur le thread d’inférence
- Multiplier les classes dès v1 (privilégier pertinence → perf)

