import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/jordanian_dictionary.dart';
import 'package:aidict/translation_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Jordanian curriculum asset has usable bilingual offline entries',() async {
    final words=await JordanianDictionary.load();
    expect(words.length,greaterThanOrEqualTo(1000));
    expect(words['apple'],'تفاحة');
    expect(JordanianDictionary.search('apple',words).first.key,'apple');
    expect(JordanianDictionary.search('تفاحة',words).first.key,'apple');
  });
  test('dictionary matches exact then prefixes without duplicates',() {
    final hits=JordanianDictionary.search('book',{'booking':'حجز','book':'كتاب'},
      fallback:{'book':'نسخة ثانية','notebook':'دفتر'});
    expect(hits.first.key,'book');
    expect(hits.where((x)=>x.key=='book').length,1);
  });
  test('translation memory retains direction and avoids repeated calls',() async {
    final cache=TranslationMemory(maxEntries:2);
    var calls=0;
    Future<String> run()async{calls++;return 'hello';}
    expect(await cache.translate('ar','en','مرحبا',run),'hello');
    expect(await cache.translate('ar','en','مرحبا',run),'hello');
    expect(calls,1);
    expect(await cache.translate('en','ar','مرحبا',run),'hello');
    expect(calls,2);
  });
  test('cache evicts old entries and never remembers failures',() async {
    final cache=TranslationMemory(maxEntries:1);
    var calls=0;
    Future<String> run()async{calls++;return '$calls';}
    await cache.translate('ar','en','one',run);
    await cache.translate('ar','en','two',run);
    await cache.translate('ar','en','one',run);
    expect(calls,3);
    await expectLater(cache.translate('ar','en','fail',() async =>
      throw StateError('failed')),throwsStateError);
    expect(await cache.translate('ar','en','fail',run),'4');
  });
}
