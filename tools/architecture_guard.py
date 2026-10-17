from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
pubspec = (root / "pubspec.yaml").read_text()
reader = (root / "lib/document_text_reader.dart").read_text()
policy = (root / "lib/translation_policy.dart").read_text()
workflow = (root / ".github/workflows/android-validation.yml").read_text()
main = (root / "lib/main.dart").read_text()

checks = {
    "supported file_picker API": "FilePicker.pickFiles(" in reader and "FilePicker.platform" not in reader,
    "file_picker modern dependency": bool(re.search(r"file_picker:\s*\^11\.", pubspec)),
    "Android API 36": "compileSdk = 36" in workflow,
    "offline translation strictly AR/EN": all(s in policy for s in ("source == 'ar' && target == 'en'", "source == 'en' && target == 'ar'")),
    "no fallback from offline to online": "offline\n          ? await _translateOffline(value)\n          : await _translateOnline(value)" in main,
    "voice conversation connected": "VoiceConversationPage(" in main,
    "flutter lints declared": "flutter_lints:" in pubspec,
    "CI produces an APK artifact": "Aidict-debug-apk" in workflow,
}
for label, passed in checks.items():
    print(("PASS" if passed else "FAIL") + ": " + label)
if not all(checks.values()):
    raise SystemExit("Static regression guard failed")
