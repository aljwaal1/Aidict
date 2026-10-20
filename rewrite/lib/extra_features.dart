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
  'house':'منزل','home':'بيت','room':'غرفة','door':'باب','window':'نافذة',
  'table':'طاولة','chair':'كرسي','bed':'سرير','kitchen':'مطبخ','bathroom':'حمام',
  'car':'سيارة','bus':'حافلة','train':'قطار','plane':'طائرة','bicycle':'دراجة',
  'road':'طريق','bridge':'جسر','station':'محطة','passport':'جواز سفر','luggage':'أمتعة',
  'departure':'مغادرة','arrival':'وصول','reservation':'حجز','price':'سعر','payment':'دفع',
  'cash':'نقد','credit':'ائتمان','debit':'مدين','account':'حساب','salary':'راتب',
  'tax':'ضريبة','profit':'ربح','loss':'خسارة','asset':'أصل','liability':'التزام',
  'equity':'حقوق ملكية','revenue':'إيراد','cost':'تكلفة','budget':'موازنة','report':'تقرير',
  'statement':'قائمة مالية','receipt':'إيصال','contract':'عقد','employee':'موظف','manager':'مدير',
  'office':'مكتب','email':'بريد إلكتروني','message':'رسالة','call':'اتصال','appointment':'موعد',
  'calendar':'تقويم','week':'أسبوع','month':'شهر','year':'سنة','hour':'ساعة',
  'minute':'دقيقة','early':'مبكر','late':'متأخر','open':'مفتوح','closed':'مغلق',
  'buy':'يشتري','sell':'يبيع','send':'يرسل','receive':'يستقبل','read':'يقرأ',
  'write':'يكتب','speak':'يتحدث','listen':'يستمع','understand':'يفهم','learn':'يتعلم',
  'question':'سؤال','answer':'إجابة','problem':'مشكلة','solution':'حل','important':'مهم',
  'easy':'سهل','difficult':'صعب','fast':'سريع','slow':'بطيء','new':'جديد',
  'old':'قديم','small':'صغير','large':'كبير','beautiful':'جميل','safe':'آمن',
  'medicine':'دواء','pharmacy':'صيدلية','patient':'مريض','health':'صحة','emergency':'طوارئ',
  'police':'شرطة','fire':'حريق','child':'طفل','mother':'أم','father':'أب',
  'sister':'أخت','brother':'أخ','wife':'زوجة','husband':'زوج','name':'اسم',
  'address':'عنوان','country':'دولة','city':'مدينة','weather':'طقس','rain':'مطر',
  'sun':'شمس','snow':'ثلج','hot':'حار','cold':'بارد','breakfast':'فطور',
  'lunch':'غداء','dinner':'عشاء','bread':'خبز','milk':'حليب','egg':'بيضة',
  'fish':'سمك','vegetables':'خضروات','fruit':'فاكهة','coffee':'قهوة','tea':'شاي',
  'happy':'سعيد','sad':'حزين','tired':'متعب','ready':'جاهز','sorry':'آسف',
  'excuse me':'عذرًا','how are you':'كيف حالك','good morning':'صباح الخير',
  'good evening':'مساء الخير','see you later':'أراك لاحقًا','how much':'كم السعر',

};

String? findWord(String term) {
  final normalized=term.trim().toLowerCase();
  if(words.containsKey(normalized)) return words[normalized];
  for(final item in words.entries) {
    if(item.value==normalized) return item.key;
  }
  return null;
}

/// Search local dictionary in both languages without an external request.
List<MapEntry<String,String>> searchWords(String query,{int limit=30}) {
  final q=query.trim().toLowerCase();
  if(q.isEmpty)return [];
  final exact=<MapEntry<String,String>>[];
  final prefixes=<MapEntry<String,String>>[];
  final partial=<MapEntry<String,String>>[];
  for(final word in words.entries) {
    final en=word.key.toLowerCase();
    final ar=word.value.toLowerCase();
    if(en==q||ar==q){exact.add(word);}
    else if(en.startsWith(q)||ar.startsWith(q)){prefixes.add(word);}
    else if(en.contains(q)||ar.contains(q)){partial.add(word);}
  }
  return [...exact,...prefixes,...partial].take(limit).toList();
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
  static Future<void> clear({bool favorite=false}) async {
    final preferences=await SharedPreferences.getInstance();
    await preferences.remove(favorite?favoritesKey:historyKey);
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
    final others=entries.where((e)=>e.value!=correct)
      .skip((index*7)% (entries.length-3)).take(3).map((e)=>e.value).toList();
    final list=[correct,...others];
    // Rotate the correct answer's position, avoiding a predictable first choice.
    final offset=index%list.length;
    return [...list.skip(offset),...list.take(offset)];
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
    appBar:AppBar(title:Text(widget.favorites?'المفضلة':'سجل الترجمات'),actions:[
      IconButton(tooltip:'مسح الكل',icon:const Icon(Icons.delete_sweep_outlined),onPressed:items.isEmpty?null:() async {
        final confirm=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
          title:const Text('مسح جميع العناصر؟'),
          content:Text(widget.favorites?'سيتم حذف جميع الترجمات المفضلة.':'سيتم حذف سجل الترجمات بالكامل.'),
          actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),
            FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('مسح'))]));
        if(confirm==true){await SavedTranslations.clear(favorite:widget.favorites);await refresh();}
      })]),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(
        onChanged:(v)=>setState(()=>search=v),
        decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'بحث',border:OutlineInputBorder()))),
      Expanded(child:ListView(children:[
        for(final value in items.where((v)=>v.toLowerCase().contains(search.toLowerCase())))
          ListTile(title:Text(value),onTap:()=>Navigator.pop(context,value),trailing:IconButton(icon:const Icon(Icons.delete_outline),
            onPressed:() async {
              await SavedTranslations.remove(value,favorite:widget.favorites);
              await refresh();
            })),
      ])),
    ]),
  );
}
