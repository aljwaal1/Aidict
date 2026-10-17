from pathlib import Path
root = Path(__file__).resolve().parents[1]
policy = (root / 'lib/translation_policy.dart').read_text()
main = (root / 'lib/main.dart').read_text()
assert "source == 'ar' && target == 'en'" in policy
assert "source == 'en' && target == 'ar'" in policy
assert 'TranslationPolicy.allowsOfflinePair' in main
assert 'OnDeviceTranslator(' in main
assert 'isModelDownloaded' in main
assert (root / 'android/app/src/main/AndroidManifest.xml').exists()
print('PASS: offline policy, Flutter code and Android scaffold present')
