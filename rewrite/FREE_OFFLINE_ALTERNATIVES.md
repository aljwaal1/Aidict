# Zero-subscription technology options for Aidict — 2026-10-20

Goal: reduce paid APIs, protect offline privacy, and avoid breaking the currently buildable Android Flutter project.

## Research and decisions

| Need | Candidate | License/compatibility | Decision |
| --- | --- | --- | --- |
| Arabic OCR | [Tesseract4Android](https://github.com/adaptech-cz/Tesseract4Android) | Apache-2.0 Android native library, requires traineddata and Flutter MethodChannel or local plugin | Preferred investigation; do not package without evaluating install size, memory, page orientation, RTL and Arabic accuracy |
| Arabic OCR baseline | [android-ocr](https://github.com/SubhamTyagi/android-ocr) | Android application built around Tesseract; inspect its license and code before reuse | UI and imaging architecture reference |
| Multilingual OCR | [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) | Apache-2.0, Android deployment integration more complicated than Tesseract | Benchmark fallback candidate |
| Recorded audio STT | [whisper_cpp_flutter_plus](https://github.com/47gurvinder/whisper_cpp_flutter) | MIT plugin, Android API 24+, bundled native binaries; models downloaded separately and licensed individually | Preferred Flutter experiment in isolated branch, not current stable branch. Verify model download security, audio input, storage, ABI and 16 KB alignment. |
| Android native audio STT | [whisper-android](https://github.com/ffmpegkit-maintained/whisper) | MIT prebuilt AAR API 24+, arm64 only on free tier; Pro includes extra features | No forced proprietary feature dependency; assess vendor restrictions first |
| Speech recognition alternative | [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | Offline speech processing; model/language support and model license vary | Evaluate only with verified Arabic-supporting model |
| Local language generation | [llama.cpp](https://github.com/ggml-org/llama.cpp) | MIT inference core, GGUF model rights vary, NDK/CMake integration | Optional high-memory device mode, not universal requirement. Avoid restrictive third-party Flutter wrappers |
| No-API text operations | Existing Dart `OfflineWritingTools` | First-party pure-Dart implementation | Implemented: deterministic extractive summary and whitespace clean-up, no claimed AI generative capability |
| Basic AR/EN translation | Existing Google ML Kit | Already integrated Android library | Retain without subscription; models downloaded on first use |
| Self-hosted network translation | LibreTranslate | AGPL-3.0 server; separate AGPL obligations | Already optional URL-based engine, not a hosted free public service |

## Acceptance gates before replacing remote backend

1. Test offline Arabic/English text samples; track exact-character accuracy for OCR and word-error-rate for Arabic/English recordings.
2. Check offline deployment on Android API 24/26/35, ARM64 and emulator as supported, especially 16 KB native page alignment, APK size, model load time and RAM.
3. Download model only on explicit user intent. Check SHA256, HTTPS provenance, free space, cancellation, model deletion and licenses.
4. Keep ML Kit Latin OCR and platform speech-to-text as usable fallback.
5. Do not change main or automatically merge without flutter analyze, tests, APK build and physical device sanity checks.
6. Treat transcription, Arabic OCR and local generative rephrasing as **not implemented offline yet** until these tests pass.

No scheduled automation has been enabled by this research.
