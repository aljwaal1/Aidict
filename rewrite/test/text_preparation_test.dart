import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/text_preparation.dart';
void main() {
  test('normalize line endings and whitespace', () {
    expect(TextPreparation.normalize(' a  b\r\n\r\n\r\nc '),'a b\n\nc');
  });
  test('count words including Arabic', () {
    expect(TextPreparation.wordCount('مرحبا بالعالم hello'),3);
    expect(TextPreparation.wordCount('  '),0);
  });
  test('preview never splits an emoji surrogate pair', () {
    expect(TextPreparation.preview('ab😀cd',maxLength:3),'ab…');
    expect(TextPreparation.preview('ab😀cd',maxLength:4),'ab😀…');
  });
  test('empty preview limit', () {
    expect(TextPreparation.preview('something',maxLength:0),'…');
  });
  test('safe preview', () {
    expect(TextPreparation.preview('abcdef',maxLength:3),'abc…');
  });
}
