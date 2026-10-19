import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/translation_engine.dart';
void main(){
  test('HTTPS only translation backends',(){
    expect(()=>TranslationEngine.validateEndpoint('http://demo.example/translate'),throwsFormatException);
    expect(()=>TranslationEngine.validateEndpoint('https://user:pass@example.com/translate'),throwsFormatException);
    expect(TranslationEngine.validateEndpoint('https://example.com/translate').path,'/translate');
  });
}
