import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/contextual_translation.dart';

void main() {
  test('short sentences travel together to preserve context', () {
    const input='I went to the bank. It was already closed. We went home.';
    expect(ContextualTranslation.plan(input), [input]);
  });

  test('line-wrapped PDF and OCR text is treated as one sentence', () {
    expect(ContextualTranslation.plan('The doctor\narrived early.'),
      ['The doctor arrived early.']);
  });

  test('separate paragraphs remain separate', () {
    expect(ContextualTranslation.plan('Hello world.\n\nHow are you?'),
      ['Hello world.', 'How are you?']);
    expect(ContextualTranslation.finish([' Hello. ', ' كيف الحال ؟ ']),
      'Hello.\n\nكيف الحال؟');
  });

  test('oversize input groups full sentences first', () {
    const input='One sentence ends here. Second sentence finishes next. Third sentence finishes later.';
    final groups=ContextualTranslation.plan(input,maxBytes:52);
    expect(groups.length,greaterThan(1));
    expect(groups.join(' '),input);
    expect(groups.every((part)=>utf8.encode(part).length<=52),isTrue);
  });

  test('Arabic and emoji are kept valid while splitting', () {
    final input=List.filled(100,'أريد ترجمة جملة مفهومة، وليس كلمات منفصلة 😊.').join(' ');
    final groups=ContextualTranslation.plan(input,maxBytes:170);
    expect(groups.every((part)=>utf8.encode(part).length<=170),isTrue);
    expect(groups.join(' '),input);
    expect(groups.every((part)=>!part.contains('�')),isTrue);
  });
  test('long English paragraph stays one paragraph after translation', () {
    const original = 'First sentence is long. Second sentence is longer. Third sentence ends.';
    final parts = ContextualTranslation.planWithParagraphs(original, maxBytes: 35);
    expect(parts.length, greaterThan(1));
    expect(parts.map((part) => part.paragraphId).toSet(), {0});
    final translated = List.generate(parts.length, (i) => 'جزء ${i + 1} .');
    final result = ContextualTranslation.finishWithParagraphs(parts, translated);
    expect(result.contains('\n'), isFalse);
    expect(result.contains(' .'), isFalse);
    expect(result, contains('جزء 1.'));
  });

  test('Arabic paragraphs keep boundaries even after several requests', () {
    const original = 'أريد ترجمة واضحة. هذا مثال أطول حتى ينقسم النص.\n\n'
        'The doctor came yesterday. She will return tomorrow.';
    final parts = ContextualTranslation.planWithParagraphs(original, maxBytes: 42);
    expect(parts.map((part) => part.paragraphId).toSet(), {0, 1});
    final result = ContextualTranslation.finishWithParagraphs(
      parts, parts.map((part) => part.paragraphId == 0 ? 'ترجمة عربية.' : 'English translation.').toList());
    expect('\n\n'.allMatches(result).length, 1);
  });

  test('a single word is one translation request in either language', () {
    for (final word in ['book', 'كتاب']) {
      final parts = ContextualTranslation.planWithParagraphs(word);
      expect(parts.length, 1);
      expect(parts.single.text, word);
    }
  });

  test('never silently discard a failed or omitted chunk', () {
    final parts = ContextualTranslation.planWithParagraphs('Hello. Another sentence.', maxBytes: 15);
    expect(() => ContextualTranslation.finishWithParagraphs(parts, ['Hello.']),
        throwsArgumentError);
  });

}
