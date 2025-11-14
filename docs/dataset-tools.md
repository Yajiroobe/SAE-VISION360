# Outils datasets (scripts/)

- `prepare_yolo_dataset.py` : convertit un JSON COCO vers labels YOLO.
  ```bash
  python scripts/prepare_yolo_dataset.py \
      --annotations C:/datasets/vision360/coco/annotations/instances_train2017.json \
      --images-dir C:/datasets/vision360/coco/train2017 \
      --output-dir C:/datasets/vision360/yolo/train/labels \
      --classes person handbag cell_phone
  ```
  Ajoute `--names-file classes.txt` pour exporter la liste des classes utilisées.

- `merge_datasets.py` : fusionne plusieurs datasets YOLO dans un seul dossier.
  ```bash
  python scripts/merge_datasets.py \
      --datasets C:/datasets/coco_yolo C:/datasets/openimages_yolo \
      --output C:/datasets/vision360/merged --split train
  ```

- `generate_data_yaml.py` : génère `datasets/data-template.yaml` à partir de `poc-web/ontology.json`.
  ```bash
  python scripts/generate_data_yaml.py --output datasets/data-template.yaml \
      --root C:/datasets/vision360
  ```

Mise en place recommandée :
1. Télécharge/extrais les datasets
2. Convertis chaque source -> YOLO (`prepare_yolo_dataset.py`)
3. Fusionne dans un dossier final (`merge_datasets.py`)
4. Génère/ajuste `data.yaml`
5. `yolo detect train data=...`
