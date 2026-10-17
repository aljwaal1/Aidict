const vocabulary = <String, String>{
  'hello': 'مرحبًا', 'thank you': 'شكرًا', 'goodbye': 'وداعًا',
  'water': 'ماء', 'food': 'طعام', 'hospital': 'مستشفى',
  'school': 'مدرسة', 'book': 'كتاب', 'friend': 'صديق',
  'family': 'عائلة', 'house': 'منزل', 'travel': 'سفر',
  'work': 'عمل', 'money': 'مال', 'time': 'وقت',
  'computer': 'حاسوب', 'phone': 'هاتف', 'doctor': 'طبيب',
  'please': 'من فضلك', 'sorry': 'آسف'
};

String? lookupWord(String word, {bool arabicToEnglish = false}) {
  final text = word.trim().toLowerCase();
  if (text.isEmpty) return null;
  if (!arabicToEnglish) return vocabulary[text];
  for (final entry in vocabulary.entries) {
    if (entry.value == text) return entry.key;
  }
  return null;
}
