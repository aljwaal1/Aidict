# Aidict source review — 2026-10-21

Scope: `rewrite/from-scratch`, especially `rewrite/lib`, Flutter tests, Android creation workflow, model assets and legacy files. GitHub Actions success establishes compile and automated tests only; no physical Android device tests were performed.

## Corrections made in this review

- **Translation result race:** Capture input and both language directions before asynchronous translation; publish a result only if source text/direction still match. Avoid mislabeling a stale translation.
- **Misleading OCR message:** Correct the home screen to describe the local Arabic/English Tesseract engine and scanned PDF fallback.
- **GGUF imports:** Validate size, copy to app support storage with staged file and explicit length verification, and avoid reading directly from a transient picked URI.
- **Audio imports:** Bound local file size, stage Whisper model and WAV files in app-specific storage, check complete copies and handle selection errors in the UI.
- **PDF OCR:** Correct paragraph separators between pages (literal escaped backslashes were previously exposed).
- **Unicode previews:** Avoid cutting surrogate pairs in half and cover regressions with unit tests.

## Observations needing further verification or separate work

1. **Native inference:** `llama_flutter_android`, `sherpa_onnx`, Tesseract, ML Kit and Android speech support require physical-device tests on multiple supported Android versions and RAM/ABI profiles. Green CI alone does not verify model results or speaker language accuracy.
2. **Models:** The user supplies compatible GGUF and Whisper ONNX files. Installation, source checksums, model provenance/licenses, persistent UI state, disk-space checks, cancellable imports and model deletion UX are incomplete.
3. **Recorded audio:** Current transcription path requires 16 kHz mono WAV. MP3/M4A conversion, automatic resampling and lengthy-recording progress/cancel are outstanding.
4. **Scanned PDFs:** Scanned-only PDFs use OCR with a 20-page limit; mixed selectable/scanned documents can miss scanned pages if other pages have extractable text. Password-protected, malformed and large PDFs need device stress tests.
5. **Storage:** Saved translations/favorites use on-device SharedPreferences, not encrypted storage. Do not claim cryptographic at-rest protection.
6. **Legacy code:** `rewrite/lib/ai_backend.dart`, `rewrite/lib/translation_engine.dart`, `rewrite/backend/`, and `rewrite/BACKEND.md` reflect an old optional server design. The active Flutter UI does not import these remote modules; they should be archived separately before claiming the *entire repository* contains no server features.
7. **Repositories and Android workflows:** The repository root still carries a separate legacy Flutter app and a separate main-branch CI workflow. The actively updated APK is produced by `.github/workflows/from-scratch.yml` in `rewrite/`, without merging to main.
8. **Build tooling:** Tesseract plugin source is patched in GitHub Actions' pub cache because upstream ships duplicate Android plugin classes and obsolete Gradle settings. Prefer maintaining an audited fork and pinned dependency to minimize future breakages.
9. **Accessibility and localization:** RTL home flow exists; full English localization, TalkBack semantics, dynamic font scaling and landscape/tablet visual testing are outstanding.
10. **Release:** GitHub currently provides a debug APK only; signed release APK/AAB, 16-KB native alignment inspection, security audit and Play publication testing are separate gates.

## Acceptance checks

- Flutter pub resolution, static analysis, tests, and debug APK build must be green on the latest commit.
- Inspect APK artifact for both Arabic and English tessdata assets.
- Real-device validation must include document OCR, voice transcription from an Arabic/English sample, GGUF inference, model reload after app restart, copying files through Android's document picker, flight-mode privacy and low-memory behavior.
- Do not change the `main` branch or enable scheduled jobs as part of this review.
