import 'package:flutter_test/flutter_test.dart';
import 'package:ai_translator/translation_policy.dart';
void main() {
  test('Only Arabic-English or English-Arabic are offline', () {
    expect(TranslationPolicy.allowsOfflinePair('ar', 'en'), true);
    expect(TranslationPolicy.allowsOfflinePair('en', 'ar'), true);
    for (final language in ['sv', 'de', 'fr', 'es', 'tr', 'ru', 'zh-CN']) {
      expect(TranslationPolicy.allowsOfflinePair(language, 'ar'), false);
      expect(TranslationPolicy.allowsOfflinePair('en', language), false);
    }
    expect(TranslationPolicy.allowsOfflinePair('ar', 'ar'), false);
  });
}
