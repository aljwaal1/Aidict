import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/extra_features.dart';

void main() {
  test('Arabic and English partial dictionary search', () {
    expect(searchWords('account').first.key,'account');
    expect(searchWords('accountant').first.key,'accountant');
    expect(searchWords('محاس').first.key,'accountant');
  });
  test('Rank exact matches ahead of prefixes', () {
    expect(searchWords('work').first.key,'work');
  });
  test('No matches returns empty list', () {
    expect(searchWords('###'),isEmpty);
  });
}
