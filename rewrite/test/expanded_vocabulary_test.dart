import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/extra_features.dart';
void main(){
  test('Expanded dictionary contains common categories',(){
    expect(words.length,greaterThan(130));
    expect(findWord('pharmacy'),'صيدلية');
    expect(findWord('فاتورة'),'invoice');
    expect(findWord('passport'),'جواز سفر');
    expect(searchWords('مواز').first.key,'budget');
  });
  test('Search returns bounded and unique results',(){
    final matches=searchWords('a',limit:10);
    expect(matches.length,lessThanOrEqualTo(10));
    expect(matches.map((e)=>e.key).toSet().length,matches.length);
  });
}
