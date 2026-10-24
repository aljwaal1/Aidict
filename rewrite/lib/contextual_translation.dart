import 'dart:convert';
import 'translation_chunks.dart';

/// Preserves sentence context for on-device translation: translate whole
/// paragraphs where possible, then split only at sentence boundaries.
/// It never rewrites meaning or sends user text to a server.
class ContextualTranslation {
  static List<String> plan(String input, {int maxBytes = 2500}) {
    if (maxBytes < 8) throw ArgumentError.value(maxBytes, 'maxBytes');
    if (input.isEmpty) return const [];
    final normalized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final paragraphs = normalized.split(RegExp(r'\n\s*\n'));
    final planned = <String>[];
    for (final paragraph in paragraphs) {
      final cleaned = paragraph.replaceAll(RegExp(r'(?<=\S)\n(?=\S)'), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ').trim();
      if (cleaned.isEmpty) continue;
      if (utf8.encode(cleaned).length <= maxBytes) {
        planned.add(cleaned);
        continue;
      }
      // Prefer a sentence boundary to prevent isolated words losing context.
      final sentences = cleaned.split(RegExp(r'(?<=[.!?؟。])\s+'));
      var current = '';
      for (final sentence in sentences) {
        if (utf8.encode(sentence).length > maxBytes) {
          if (current.isNotEmpty) { planned.add(current); current = ''; }
          planned.addAll(TranslationChunks.split(sentence, maxBytes: maxBytes)
              .where((part) => part.trim().isNotEmpty));
          continue;
        }
        final candidate = current.isEmpty ? sentence : '$current $sentence';
        if (utf8.encode(candidate).length <= maxBytes) {
          current = candidate;
        } else {
          if (current.isNotEmpty) planned.add(current);
          current = sentence;
        }
      }
      if (current.isNotEmpty) planned.add(current);
    }
    return planned;
  }

  static String finish(Iterable<String> translatedParagraphs) =>
      translatedParagraphs.map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join('\n\n')
        .replaceAll(RegExp(r'[ \t]+([،,؛;.!?؟])'), r'$1')
        .trim();
}
