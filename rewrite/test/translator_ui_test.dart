import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aidict/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Translator starts with offline language controls', (tester) async {
    await tester.pumpWidget(const AidictApp());
    await tester.pump();
    expect(find.text('Aidict • المترجم'), findsOneWidget);
    expect(find.text('ترجم، تعلّم، وتحدث'), findsOneWidget);
    expect(find.text('وضع محلي فقط — لا خوادم ولا خدمات ترجمة مدفوعة'), findsOneWidget);
  });
  testWidgets('Translator includes translation action', (tester) async {
    await tester.pumpWidget(const AidictApp());
    await tester.pump();
    expect(find.text('وضع محلي فقط — لا خوادم ولا خدمات ترجمة مدفوعة'), findsOneWidget);
    expect(find.text('ترجم، تعلّم، وتحدث'), findsOneWidget);
  });
}
