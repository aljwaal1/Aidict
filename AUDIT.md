# Aidict technical audit — 2026-10-17

## Confirmed CI diagnosis
GitHub Actions run 39044460419 (Issue #3): flutter analyze SUCCESS; flutter test SUCCESS (2 tests); build FAILURE in :file_picker:checkDebugAarMetadata because the old file_picker subproject used Android compileSdk 34 while flutter_plugin_android_lifecycle demanded Android API >=36.

### Changes
- Upgrade file_picker 8.x -> 11.0.3-compatible range.
- Generate app android/app/build.gradle.kts with compileSdk = 36 and minSdk = 23.
- Validate compileSdk/minSdk during CI.
- Add flutter_lints and wire voice conversation into the UI (fixed previous warnings).
- Migrate Flutter dropdown to initialValue.

### Not yet verified
No successful run after those changes has been confirmed. Plugin subprojects can still have independent compileSdk values; if :file_picker still reports android-34, inspect the updated plugin's build.gradle, and consider patching plugin subproject or selecting a supported version. Verify the Android SDK platform 36 is installed on the runner.

## Runtime and feature audit
- Offline ML Kit translation: permits only ar->en / en->ar, requires models downloaded. Device airplane-mode test pending.
- Online translation: uses public MyMemory service, limited to 450 characters; unsuitable for guaranteed production reliability; request quotas and privacy notices need attention.
- Image OCR: Latin script only; Arabic OCR and live camera overlays not implemented.
- Document reader: imports PDF/DOCX/TXT text, max 12 MiB / 40k characters, but full-document translation, export, layout preservation and scanned PDF OCR not implemented.
- Voice conversation: alternating microphone speech and TTS, requires device services, no full audio-file translation, possible offline limitations.
- Local dictionary: 20 entries; vocabulary quiz is preliminary.
- Favorites and history: stored in SharedPreferences as text; lacks structured entries and migrations.
- AI correction/rephrasing: not implemented; production backend required.
- Automated tests: 2 logic tests only; widget, integration, Android-device, document fixture and audio tests pending.

## Release gates
1. Flutter analyze must pass.
2. All tests must pass.
3. flutter build apk --debug must produce artifact.
4. Install and run APK on Android and verify airplane-mode translation, online modes, camera, audio and document import.
5. Create a properly signed release build and verify feature completeness before calling the APK final.
