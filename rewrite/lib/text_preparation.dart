/// Text preparation utilities for extracted documents and recognized images.
/// Does not alter original PDF or Word layouts.
class TextPreparation {
  static String normalize(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static int wordCount(String value) {
    final text=normalize(value);
    if(text.isEmpty)return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  static bool isLikelyEmpty(String value) => normalize(value).isEmpty;

  static String preview(String value,{int maxLength=400}) {
    final text=normalize(value);
    if(text.length<=maxLength)return text;
    return '${text.substring(0,maxLength)}…';
  }
}
