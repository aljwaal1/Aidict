class TranslationPolicy {
  static bool offlineAllowed(String source, String target) =>
      (source == 'ar' && target == 'en') ||
      (source == 'en' && target == 'ar');
}
