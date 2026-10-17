class TranslationPolicy {
  static bool allowsOfflinePair(String source, String target) {
    return (source == 'ar' && target == 'en') ||
        (source == 'en' && target == 'ar');
  }
}
