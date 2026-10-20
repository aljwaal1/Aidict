/// BCP-47 locale mapping for speech synthesis.
class SpeechLocales {
  static String forLanguage(String code) {
    switch(code) {
      case 'ar':return 'ar';
      case 'en':return 'en-US';
      case 'sv':return 'sv-SE';
      case 'fr':return 'fr-FR';
      case 'de':return 'de-DE';
      case 'es':return 'es-ES';
      case 'tr':return 'tr-TR';
      default:throw FormatException('Unsupported speech language: $code');
    }
  }
}
