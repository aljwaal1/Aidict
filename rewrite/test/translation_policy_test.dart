import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/translation_policy.dart';
void main() {
  test('offline pairs', () {
    expect(TranslationPolicy.offlineAllowed('ar', 'en'), isTrue);
    expect(TranslationPolicy.offlineAllowed('en', 'ar'), isTrue);
    expect(TranslationPolicy.offlineAllowed('sv', 'en'), isFalse);
    expect(TranslationPolicy.offlineAllowed('ar', 'ar'), isFalse);
  });
}
