# Plan d'entraînement Vision360

## Classes cibles
- Obstacles: person, crowd, stairs, curb, door, cone, barrier, puddle
- Retail: product, shelf, price_tag, barcode, cart, basket, bottle, can, produce, package
- Restaurant: table, chair, tray, cutlery, plate, glass, menu, counter, terminal, dish
- Général: cell_phone, handbag, backpack, suitcase, laptop, keyboard, mouse, remote, tv, book, bench, umbrella, tie, sports_ball, clock, potted_plant, etc.

## Sources de données
| Domaine | Dataset | Notes |
|---------|---------|-------|
| Obstacles urbains | COCO, BDD100K, Cityscapes | personnes, routes, trottoirs, signalisation |
| Retail | OpenImages (classes ciblées), SKU-110k, GroZi-120 | produits, rayons, étiquettes |
| Général | COCO, OpenImages, Objects365 | objets du quotidien |

## Pipeline
1. Télécharger datasets (COCO, OpenImages, SKU-110k, GroZi-120)
2. Convertir en format YOLO (`python scripts/prepare_yolo_dataset.py --annotations ... --images-dir ... --output-dir ... --classes ...`)
3. Fusionner plusieurs sources si besoin (`python scripts/merge_datasets.py --datasets data/coco_yolo data/openimages_yolo --output merged`)
4. Générer `data.yaml` via `python scripts/generate_data_yaml.py`
5. Entraîner YOLOv8n (`yolo detect train data=... model=yolov8n.pt epochs=30 imgsz=640`)
5. Exporter TFLite int8 (`yolo export format=tflite int8`)
6. Intégrer dans l'app Android (MediaPipe Tasks / TFLite)

## Active learning
- Utiliser le POC webcam pour capturer des samples (PNG + JSON) -> annotation rapide (Label Studio)
- Ajouter les nouveaux exemples au dataset puis relancer un fine-tune léger (5-10 epochs)

## Améliorations
- Ajouter OCR (Tesseract/ML Kit) pour price_tags, menus
- Scanner code-barres (ZXing) pour enrichir les attributs
- Combiner les sorties YOLO + OCR -> `/api/guidance/enrich`
