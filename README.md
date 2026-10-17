# Aidict — AI Translator

Flutter Android application for translation with **Arabic ↔ English only offline** (after downloading both ML Kit models) and more languages via an external online translation endpoint.

## Implemented in the repository

- Text translation with explicit online/offline switch, no automatic online fallback for offline failures.
- Download Arabic and English ML Kit language models.
- Translation history and favorites persisted with SharedPreferences.
- Clipboard paste, copy results and light/dark themes.
- Flutter test for allowed offline language pairs.
- GitHub Actions workflow: create Android scaffolding, configure INTERNET and minSdk 23, resolve dependencies, analyze, test and build debug APK.

## Limitations

The online MyMemory translation endpoint is public/demo-grade with availability and usage limits. It is not a paid production translation backend. Live camera overlay translation, Arabic OCR, live conversation, audio recordings, PDF/DOCX, advanced dictionary, AI rewriting and learning quizzes are **not yet present in the committed version**. Do not claim they work. The earlier standalone ZIP includes preliminary work but was not the basis of validated APK.

## Build

1. Open **Actions → Aidict Android CI** in this repository and inspect the last run on `main`.
2. On success download artifact `Aidict-debug-apk`.
3. On failure inspect Flutter analyze/test/build step; resolve failures before moving to additional phases.
4. Install and test on real Android phone, including airplane-mode Arabic ↔ English translation **after** downloading both models.

Stage 0 remains **unverified** until build and device tests pass. Debug APK is not a Play Store production release; production requires signing and further QA.

## Screenshot/camera OCR progress

Camera capture and importing an image/screenshot now extract **Latin-script text** with ML Kit and fill the translation field. This does not yet perform live camera overlay translation and does not recognize Arabic script. The feature has not passed device QA.

## Development update — voice conversation

Added a basic alternating two-speaker voice conversation screen using speech_to_text, an online text translation endpoint and flutter_tts. Requires RECORD_AUDIO permission and compatible speech/TTS services. Speech recognition may require a network connection depending on the Android device; do not describe it as offline. It does not yet support simultaneous speakers, streaming translation, audio file translation, or an overlay-camera interface. Android CI and real-device QA remain unverified.

## Document import — preliminary

Added a file picker and local text extraction for PDF, DOCX and TXT files. Import populates the text field; it does **not** yet translate complete large documents automatically, produce a translated DOCX/PDF, retain original formatting, or OCR scanned PDFs. The current online translation service limits each request to 450 characters. Document import is limited to 12 MB and 40,000 extracted characters. This feature is source-committed but not yet verified by Flutter analyze, Android build or device testing. PDF parsing uses Syncfusion's package, whose licensing terms should be reviewed before distribution.
