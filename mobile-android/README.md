# Vision360 Mobile Android – Build & Docker

Ce dossier contient le squelette Android (Kotlin) prêt pour CameraX et l’intégration future de MediaPipe/ARCore.

## Construire localement (Android Studio)
- Ouvrir `SAE-VISION360/mobile-android` dans Android Studio (JDK 17)
- Lancer l’app sur un appareil Android (minSdk 26)

## Construire via Docker (SDK Android inclus)
1) Depuis la racine du repo `SAE-VISION360/`:
   - Build l’image: `docker build -f mobile-android/docker/Dockerfile -t vision360-android .`
   - Lancer un shell pour voir l’APK: `docker run --rm -it vision360-android`
2) L’APK debug sera dans: `mobile-android/app/build/outputs/apk/debug/`

Notes:
- Le Dockerfile installe l’Android SDK (platform 34, build-tools 34.0.0) et utilise Gradle 8.7 (JDK 17).
- L’intégration MediaPipe/ARCore sera ajoutée dans les prochaines itérations.

