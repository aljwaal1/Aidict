/// Splits large texts into UTF-8-safe requests for translation services.
/// Preserves all source characters and avoids cutting surrogate pairs.
class TranslationChunks {
  static List<String> split(String text, {int maxBytes = 450}) {
    if (maxBytes < 1) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'Must be positive');
    }
    final codePoints = text.runes.toList(growable: false);
    final chunks = <String>[];
    var start = 0;
    while (start < codePoints.length) {
      var end = start;
      var bytesUsed = 0;
      var lastWhitespace = -1;
      while (end < codePoints.length) {
        final rune = codePoints[end];
        final runeBytes = rune <= 0x7f
            ? 1
            : rune <= 0x7ff
                ? 2
                : rune <= 0xffff
                    ? 3
                    : 4;
        if (bytesUsed + runeBytes > maxBytes) break;
        bytesUsed += runeBytes;
        if (rune == 0x20 || rune == 0x0a || rune == 0x0d || rune == 0x09) {
          lastWhitespace = end;
        }
        end++;
      }
      if (end == start) {
        throw ArgumentError.value(
          maxBytes, 'maxBytes', 'Cannot fit a Unicode code point');
      }
      // Prefer a word or paragraph boundary in the second half of the chunk.
      if (end < codePoints.length &&
          lastWhitespace >= start &&
          lastWhitespace - start >= (end - start) ~/ 2) {
        end = lastWhitespace + 1;
      }
      chunks.add(String.fromCharCodes(codePoints.getRange(start, end)));
      start = end;
    }
    return chunks;
  }
}
