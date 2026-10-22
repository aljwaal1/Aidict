import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aidict/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Dashboard shows core feature cards', (tester) async {
    await tester.pumpWidget(const AidictApp());
    await tester.pump();
    expect(find.text('AI Translator'), findsOneWidget);
    expect(find.text('AI photo recognition'), findsOneWidget);
    expect(find.text('AI photo translation'), findsOneWidget);
    expect(find.text('AI simultaneous interpretation'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Offline translation'), 250,
      scrollable: find.byType(Scrollable).first);
    expect(find.text('Offline translation'), findsOneWidget);
  });

  testWidgets('Offline tile opens the existing translator', (tester) async {
    await tester.pumpWidget(const AidictApp());
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Offline translation'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Offline translation'));
    await tester.pumpAndSettle();
    expect(find.text('Aidict • المترجم'), findsOneWidget);
    expect(find.text('ترجم، تعلّم، وتحدث'), findsOneWidget);
  });
}
