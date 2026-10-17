import 'package:flutter_test/flutter_test.dart';
import 'package:ai_translator/vocabulary_data.dart';
void main() {
  test('Dictionary searches both Arabic and English', () {
    expect(lookupWord('hello'), 'مرحبًا');
    expect(lookupWord(' مرحبًا ', arabicToEnglish: true), 'hello');
    expect(lookupWord('HELLO'), 'مرحبًا');
    expect(lookupWord(''), isNull);
    expect(lookupWord('nonexistent'), isNull);
  });
}
