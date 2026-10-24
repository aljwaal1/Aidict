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


  /// Keeps the original paragraph identity when a paragraph needs multiple
  /// model requests. This metadata must never be sent to the model.
  static List<ContextualPart> planWithParagraphs(String input,
      {int maxBytes = 2500}) {
    if (maxBytes < 8) throw ArgumentError.value(maxBytes, 'maxBytes');
    if (input.isEmpty) return const [];
    final paragraphs = input.replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n').split(RegExp(r'\n\s*\n'));
    final result = <ContextualPart>[];
    var paragraphId = 0;
    for (final paragraph in paragraphs) {
      final units = plan(paragraph, maxBytes: maxBytes);
      if (units.isEmpty) continue;
      for (final unit in units) {
        result.add(ContextualPart(unit, paragraphId));
      }
      paragraphId++;
    }
    return result;
  }

  /// Reassembles chunks of the same source paragraph as a single paragraph.
  /// Translated punctuation is retained; only stray spaces before it are
  /// removed. Missing results are errors rather than silently losing text.
  static String finishWithParagraphs(
      List<ContextualPart> parts, List<String> translations) {
    if (parts.length != translations.length) {
      throw ArgumentError('Every source part needs one translation');
    }
    final paragraphs = <String>[];
    final buffer = <String>[];
    int? currentId;
    for (var i = 0; i < parts.length; i++) {
      final translated = translations[i].trim();
      if (currentId != null && currentId != parts[i].paragraphId) {
        paragraphs.add(buffer.join(' '));
        buffer.clear();
      }
      currentId = parts[i].paragraphId;
      if (translated.isNotEmpty) buffer.add(translated);
    }
    if (buffer.isNotEmpty) paragraphs.add(buffer.join(' '));
    return paragraphs.join('\n\n')
        .replaceAllMapped(RegExp(r'[ \t]+([،,؛;.!?؟])'),
            (match) => match.group(1)!)
        .trim();
  }

  static String finish(Iterable<String> translatedParagraphs) =>
      translatedParagraphs.map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join('\n\n')
        .replaceAllMapped(RegExp(r'[ \t]+([،,؛;.!?؟])'), (match) => match.group(1)!)
        .trim();
}

/// A model request with its original paragraph identifier.
class ContextualPart {
  const ContextualPart(this.text, this.paragraphId);
  final String text;
  final int paragraphId;
}
