# GitHub reference projects for Aidict — 2026-10-20

Research only. No third-party source or assets have been incorporated into the app by this commit.

| Project | Stars (approx., at review) | Platform | License | Aidict benefit |
|---|---:|---|---|---|
| https://github.com/you-apps/TranslateYou | 1.5k | Android Kotlin/Compose | GPL-3.0 | Material 3 design, engine switcher, history, image translation, system share |
| https://github.com/LibreTranslate/LibreTranslate | 17k | Python translation service | AGPL-3.0 | Replace single MyMemory provider with configurable self-hosted backend |
| https://github.com/tesseract-ocr/tesseract | 77k | Native OCR | Apache-2.0 | Evaluate Arabic/English OCR on Android; model language data and JNI integration need validation |
| https://github.com/argosopentech/argos-translate | 6.5k | Python offline NMT | MIT/CC0 (source) | Offline model packaging, language pivot; not drop-in Flutter library; verify model package rights |
| https://github.com/localsend/localsend | 92k | Flutter/Dart | Check upstream LICENSE before code reuse | Flutter routing, architecture, device UX, release automation |
| https://github.com/tisfeng/Easydict | 15k | macOS/Swift | Check upstream LICENSE | Dictionary search UX, multiple engine concepts; not Android code |
| https://github.com/nextai-translator/nextai-translator | 25k | Browser/desktop TypeScript | Check upstream LICENSE | Writing assistant and multimodel UX; not drop-in Flutter code |

## Integration decisions

1. **No code copied on discovery.** Preserve independently authored Flutter app and current green build. Don't copy UI assets, trademarks, icons or source until license obligations, dependencies, provenance and Android build compatibility have been reviewed.
2. Keep offline AR/EN via existing Google ML Kit. LibreTranslate can be an additional optional HTTPS engine behind a clean `TranslationProvider` interface; verify rate limits and deployment/privacy.
3. Investigate Tesseract Arabic OCR with Arabic traineddata and benchmark real device memory, APK size, speed, photographed text and RTL line ordering before committing integration. Existing ML Kit Latin OCR remains as fallback. Check model licenses separately.
4. Improve UX using clean-room Material 3 designs: dashboard with Text / Voice / Camera / Document / Dictionary, a result action bar (copy/speak/favorite/share), language switch and model download states. Start with wireframes and widget tests, not Kotlin/Compose porting.
5. Separate modules into UI / application use cases / providers / local persistence. Add provider contract tests and instrumented Android smoke tests for camera, microphone, files and TTS.
6. On-device audio file transcription remains unsolved: speech_to_text is for microphone capture, not automatically for prerecorded media. Evaluate a licensed Whisper-compatible engine/service with bounded upload and explicit consent.
7. Protect the established workflow: analyze, tests, debug APK build, artifact integrity; run on isolated PR before merging. The app requires a physical-device acceptance test for UI and native plugins.

## Licensing and practical cautions

GPL/AGPL components can create distribution or network-service source obligations. For GPL-licensed TranslateYou, reuse UI *ideas* but do not copy implementation or artwork blindly. For LibreTranslate AGPL, prefer deploying a separately maintained service and review AGPL service obligations. Check all OCR model/data licenses. Stars reflect popularity, **not** Android/Flutter compatibility, tested correctness or permissive reuse. This plan is a research artifact, not completed integration.
