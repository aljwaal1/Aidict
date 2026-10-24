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
}
