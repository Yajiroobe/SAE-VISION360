# POC Vision – Webcam (PC)

Ce POC permet de tester en direct la détection d’obstacles depuis la webcam du PC, sans installer Android. Il utilise TensorFlow.js (modèle COCO‑SSD) et affiche FPS, boîtes, et alertes vocales optionnelles.

## Prérequis
- Un navigateur moderne (Chrome/Edge/Firefox). Chrome recommandé.
- Accès internet (pour charger TF.js et le modèle). 

## Lancer le POC
1) Ouvrir un terminal dans `SAE-VISION360/poc-web`
2) Démarrer un serveur local (HTTPS non requis en local):
   - Python 3: `python -m http.server 8000`
3) Ouvrir le navigateur sur: `http://localhost:8000/`
4) Autoriser l’accès à la caméra quand le navigateur le demande.

## Utilisation
- Boutons en haut à gauche:
  - Start/Stop: démarrer/arrêter l’inférence
  - TTS: activer/désactiver les alertes vocales (Web Speech API)
  - Show Boxes: afficher/masquer les boîtes
- Affichages: FPS, classes détectées, zone (near/mid/far), côté (left/center/right)
- Optimisation: la résolution d’entrée est réduite pour améliorer la latence. 

## Limites
- Modèle générique (COCO) ≠ liste exacte d’obstacles du projet (utilisé ici pour latence et boucle E2E). 
- Phrases TTS simples pour démo. La logique finale sera affinée.

## Étapes suivantes
- Remplacer par un modèle léger custom (YOLOv8n/MediaPipe) une fois prêt.
- Ajouter estimation de distance plus robuste (stéréo/AR depth sur mobile).

