import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/translation_chunks.dart';

void main() {
  test('empty and short inputs are unchanged', () {
    expect(TranslationChunks.split(''), isEmpty);
    expect(TranslationChunks.split('hello'), ['hello']);
  });

  test('long English text is lossless and each chunk fits UTF-8 limit', () {
    final text = List.filled(400, 'hello world').join(' ');
    final chunks = TranslationChunks.split(text);
    expect(chunks.length, greaterThan(1));
    expect(chunks.join(), text);
    expect(chunks.every((c) => utf8.encode(c).length <= 450), isTrue);
  });

  test('Arabic and emoji are not split inside Unicode code points', () {
    final text = List.filled(300, 'مرحبًا 👋 بالعالم').join(' ');
    final chunks = TranslationChunks.split(text);
    expect(chunks.join(), text);
    expect(chunks.every((c) => utf8.encode(c).length <= 450), isTrue);
    expect(chunks.every((c) => !c.contains('\uFFFD')), isTrue);
  });

  test('long unbroken words are split without losing characters', () {
    final text = List.filled(1100, 'x').join();
    final chunks = TranslationChunks.split(text);
    expect(chunks.join(), text);
    expect(chunks.every((c) => c.length <= 450), isTrue);
  });

  test('rejects invalid byte limits and impossible rune sizes', () {
    expect(() => TranslationChunks.split('x', maxBytes: 0), throwsArgumentError);
    expect(() => TranslationChunks.split('👋', maxBytes: 1), throwsArgumentError);
  });
}
