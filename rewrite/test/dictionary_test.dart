import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/extra_features.dart';
void main() {
  test('Bidirectional dictionary', () {
    expect(findWord(' hello '),'مرحبًا');
    expect(findWord('ماء'),'water');
    expect(findWord('UNKNOWN'),isNull);
  });
}
