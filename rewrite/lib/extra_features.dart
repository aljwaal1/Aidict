import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const words = <String,String>{
  'hello':'مرحبًا','goodbye':'وداعًا','water':'ماء','food':'طعام',
  'hospital':'مستشفى','school':'مدرسة','doctor':'طبيب','family':'عائلة',
  'work':'عمل','friend':'صديق','thank you':'شكرًا','please':'من فضلك',
  'book':'كتاب','computer':'حاسوب','phone':'هاتف','language':'لغة',
  'translation':'ترجمة','dictionary':'قاموس','university':'جامعة',
  'student':'طالب','teacher':'معلم','accountant':'محاسب',
  'money':'مال','invoice':'فاتورة','bank':'بنك','balance':'رصيد',
  'income':'دخل','expense':'مصروف','customer':'عميل',
  'supplier':'مورد','business':'عمل تجاري','meeting':'اجتماع',
  'today':'اليوم','tomorrow':'غدًا','yesterday':'أمس',
  'morning':'صباح','evening':'مساء','night':'ليل',
  'yes':'نعم','no':'لا','help':'مساعدة','welcome':'أهلًا',
  'travel':'سفر','airport':'مطار','ticket':'تذكرة',
  'hotel':'فندق','restaurant':'مطعم','street':'شارع',
  'left':'يسار','right':'يمين','straight':'مباشرة',
};

String? findWord(String term) {
  final normalized=term.trim().toLowerCase();
  if(words.containsKey(normalized)) return words[normalized];
  for(final item in words.entries) {
    if(item.value==normalized) return item.key;
  }
  return null;
}

class SavedTranslations {
  static const historyKey='aidict.history.v1';
  static const favoritesKey='aidict.favorites.v1';
  static Future<List<String>> load(bool favorite) async {
    final preferences=await SharedPreferences.getInstance();
    return preferences.getStringList(favorite?favoritesKey:historyKey)??[];
  }
  static Future<void> add(String value,{bool favorite=false}) async {
    final preferences=await SharedPreferences.getInstance();
    final key=favorite?favoritesKey:historyKey;
    final entries=preferences.getStringList(key)??[];
    entries.remove(value);
    entries.insert(0,value);
    await preferences.setStringList(key,entries.take(100).toList());
  }
  static Future<void> remove(String value,{bool favorite=false}) async {
    final preferences=await SharedPreferences.getInstance();
    final key=favorite?favoritesKey:historyKey;
    final entries=preferences.getStringList(key)??[];
    entries.remove(value);
    await preferences.setStringList(key,entries);
  }
}

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});
  @override State<LearningScreen> createState()=>_LearningScreenState();
}
class _LearningScreenState extends State<LearningScreen> {
  final entries=words.entries.toList();
  int index=0,score=0;
  bool answered=false;
  List<String> get choices {
    if(index>=entries.length)return [];
    final correct=entries[index].value;
    final others=entries.where((e)=>e.value!=correct).skip(index%5).take(3).map((e)=>e.value);
    return [correct,...others];
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('اختبار المفردات')),
    body:Padding(padding:const EdgeInsets.all(16),child:index>=entries.length
      ? Column(children:[
        Text('النتيجة: $score / ${entries.length}'),
        FilledButton(onPressed:()=>setState((){index=0;score=0;answered=false;}),child:const Text('إعادة الاختبار'))
      ])
      : Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        LinearProgressIndicator(value:index/entries.length),
        const SizedBox(height:20),
        Text(entries[index].key,style:Theme.of(context).textTheme.headlineMedium),
        for(final choice in choices) OutlinedButton(
          onPressed:answered?null:()=>setState((){
            answered=true;
            if(choice==entries[index].value)score++;
          }),
          child:Text(choice)),
        if(answered) ...[
          Text('الصحيح: ${entries[index].value}'),
          FilledButton(onPressed:()=>setState((){index++;answered=false;}),child:const Text('التالي')),
        ],
      ])),
  );
}

class TranslationLibraryPage extends StatefulWidget {
  final bool favorites;
  const TranslationLibraryPage({super.key,required this.favorites});
  @override State<TranslationLibraryPage> createState()=>_TranslationLibraryPageState();
}
class _TranslationLibraryPageState extends State<TranslationLibraryPage> {
  List<String> items=[];
  String search='';
  @override void initState(){super.initState();refresh();}
  Future<void> refresh() async {
    final loaded=await SavedTranslations.load(widget.favorites);
    if(mounted)setState(()=>items=loaded);
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.favorites?'المفضلة':'سجل الترجمات')),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(
        onChanged:(v)=>setState(()=>search=v),
        decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'بحث',border:OutlineInputBorder()))),
      Expanded(child:ListView(children:[
        for(final value in items.where((v)=>v.toLowerCase().contains(search.toLowerCase())))
          ListTile(title:Text(value),trailing:IconButton(icon:const Icon(Icons.delete_outline),
            onPressed:() async {
              await SavedTranslations.remove(value,favorite:widget.favorites);
              await refresh();
            })),
      ])),
    ]),
  );
}
