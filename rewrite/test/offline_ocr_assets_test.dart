import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Arabic and English OCR models are included as local Flutter assets', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/tessdata_config.json'),
    ) as Map<String, dynamic>;
    expect(manifest['files'], containsAll(['ara.traineddata', 'eng.traineddata']));

    for (final language in ['ara', 'eng']) {
      final asset = await rootBundle.load('assets/tessdata/$language.traineddata');
      expect(asset.lengthInBytes, greaterThan(100000));
    }
  });
}
