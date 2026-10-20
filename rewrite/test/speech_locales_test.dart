import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/speech_locales.dart';
void main(){
  test('TTS uses destination language locale',(){
    expect(SpeechLocales.forLanguage('ar'),'ar');
    expect(SpeechLocales.forLanguage('sv'),'sv-SE');
    expect(SpeechLocales.forLanguage('fr'),'fr-FR');
    expect(SpeechLocales.forLanguage('en'),'en-US');
  });
  test('Unknown locale fails safely',(){
    expect(()=>SpeechLocales.forLanguage('xx'),throwsFormatException);
  });
}
