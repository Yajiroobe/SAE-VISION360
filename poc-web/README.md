# POC Vision - Webcam (PC)

Ce POC permet de tester en direct la detection d'obstacles ou d'objets via la webcam du PC. Il utilise TensorFlow.js (modele COCO-SSD) et affiche FPS, latence et alertes vocales optionnelles.

## Prerequis
- Navigateur moderne (Chrome/Edge/Firefox). Chrome recommande.
- Internet pour charger TF.js et le modele (ou lancer `fetch_vendor.*` pour les avoir en local).

## Lancer le POC
1. Dans `SAE-VISION360/poc-web`
2. `python -m http.server 8000`
3. Ouvrir `http://localhost:8000/`
4. Autoriser la camera.

## Utilisation
- Contrôles:
  - `Start`/`Stop`: demarrer/arreter
  - `TTS`: activer la voix
  - `Boxes`: afficher/masquer les boites
  - `Profile`: applique un mapping (obstacles, retail, restaurant) issu de `ontology.json` et remplit `classes`
  - `Res`: resolution d'entree (320/480/640)
  - `Stride`: n'inferer qu'une frame sur N
  - `Conf`: seuil confiance
  - `MinArea`: aire minimale (fraction de l'image)
  - `Backend`: auto/webgpu/webgl/cpu
  - `classes`: filtre manuel complementaire (ex: `person,car,truck`). Vide = toutes
  - `Record`: enregistre une video (.webm)
  - `Snapshot`: capture PNG
  - `Capture Sample`: telecharge PNG + JSON des detections (dataset)
  - `Download CSV`: export metrics (timestamp, FPS, latence, nb objets)
- Bandeau: affiche FPS, latence et backend actif.

## Limites
- COCO-SSD reste generique; modele custom (YOLOv8n/MediaPipe) viendra ensuite.
- Phrases TTS et consignes simplifiees.

## Suite possible
- Remplacer par un modele on-device custom.
- Ajouter profondeur (ARCore/Depth API) et OCR/barcode pour retail/restaurant.
