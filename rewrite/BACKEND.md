# Aidict optional processing backend

The Flutter app works without this backend for Arabic ↔ English on-device translation (after ML Kit model download), text extraction for searchable PDF/DOCX/TXT, Latin image OCR, saved translations, learning, and device speech-to-text/TTS.

The following features require an **optional HTTPS service**:
- Arabic OCR: multipart POST, field `task=ocr`, image in field `image`
- Existing audio recordings: multipart POST, `task=transcribe`, binary file in field `audio`
- Writing support: JSON POST, `{"task":"rewrite|proofread|summarize","text":"...","language":"ar"}`

All success responses must be JSON: `{"result":"processed text"}` (HTTP 200).
No backend is provided or deployed by this repository. No OpenAI or other paid-provider API key should ever be placed in the mobile app. Configure the URL from the **AI tools** screen. The URL itself is saved locally on the phone; source text/audio/images are sent only on explicit request. The app enforces HTTPS, size limits, and timeouts; the server operator must provide authentication, rate limiting, content safety, logging controls, and privacy notices.

**Functional limitations:** Google's Flutter ML Kit text-recognition package does not offer Arabic OCR through the current on-device Latin script recognizer. The optional backend enables Arabic image processing only when such a service is operational. The audio file API likewise needs a real transcription engine. Scanned PDFs are not OCR-transcribed automatically. The online translation service has third-party limitations; verify its privacy terms before submitting private documents.

## Release acceptance

- CI: flutter pub get, flutter analyze, flutter test, flutter build apk
- Android physical device: downloaded-model offline pairs, online text, camera/gallery OCR, PDF/DOCX/TXT, speech recognition, TTS, local history/favorites
- With an owned backend: Arabic OCR, audio transcription, rewrite/proofread/summarize
- Confirm the debug APK is installable; test release signing separately.
