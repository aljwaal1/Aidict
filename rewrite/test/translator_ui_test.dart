import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/main.dart';

void main(){
  testWidgets('Translator shows primary offline actions', (tester) async {
    await tester.pumpWidget(const AidictApp());
    await tester.pump();
    expect(find.text('Aidict • المترجم'),findsOneWidget);
    expect(find.text('ترجمة'),findsOneWidget);
    expect(find.text('تنزيل العربية والإنجليزية'),findsOneWidget);
    expect(find.text('تعلم الكلمات'),findsOneWidget);
  });
  testWidgets('Translation screen has media and document import actions', (tester) async {
    await tester.pumpWidget(const AidictApp());
    await tester.pump();
    expect(find.text('الكاميرا'),findsOneWidget);
    expect(find.text('صورة'),findsOneWidget);
    expect(find.text('PDF / Word / TXT'),findsOneWidget);
  });
}
