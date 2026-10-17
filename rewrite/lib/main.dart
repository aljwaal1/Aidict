import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'translation_policy.dart';
import 'extra_features.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AidictApp());
class AidictApp extends StatefulWidget {
  const AidictApp({super.key});
  @override State<AidictApp> createState() => _AidictAppState();
}
class _AidictAppState extends State<AidictApp> {
  bool dark = false;
  @override Widget build(BuildContext context) => MaterialApp(
    title:'Aidict', debugShowCheckedModeBanner:false,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(useMaterial3:true,colorSchemeSeed:Colors.blue),
    darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark),
    home: Directionality(textDirection:TextDirection.rtl,
      child: TranslatorScreen(toggleTheme:()=>setState(()=>dark=!dark))),
  );
}
class TranslatorScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const TranslatorScreen({super.key, required this.toggleTheme});
  @override State<TranslatorScreen> createState()=>_TranslatorScreenState();
}
class _TranslatorScreenState extends State<TranslatorScreen> {
  final input=TextEditingController();
  final manager=OnDeviceTranslatorModelManager();
  bool offline=true, busy=false;
  String dictionaryQuery='';
  String source='ar',target='en',output='',message='';
  Future<void> download() async {
    if(busy)return;
    setState(()=>busy=true);
    try {
      for (final code in ['ar','en']) {
        if (!await manager.isModelDownloaded(code)) {
          if(!await manager.downloadModel(code)) throw StateError('تنزيل نموذج $code فشل');
        }
      }
      if(mounted)setState(()=>message='النماذج جاهزة للترجمة دون إنترنت');
    } catch(e) {
      if(mounted)setState(()=>message='$e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  Future<String> local(String text) async {
    if(!TranslationPolicy.offlineAllowed(source,target))throw StateError('المحلي عربي ↔ إنجليزي فقط');
    if(!await manager.isModelDownloaded(source) || !await manager.isModelDownloaded(target)) {
      throw StateError('نزّل نموذجي اللغة أولًا');
    }
    final t=OnDeviceTranslator(
      sourceLanguage:source=='ar'?TranslateLanguage.arabic:TranslateLanguage.english,
      targetLanguage:target=='ar'?TranslateLanguage.arabic:TranslateLanguage.english);
    try{return await t.translateText(text);}finally{await t.close();}
  }
  Future<String> online(String text) async {
    if(text.length>450)throw StateError('حد الترجمة المتصلة 450 حرفًا');
    final url=Uri.https('api.mymemory.translated.net','/get',
      {'q':text,'langpair':'$source|$target'});
    final response=await http.get(url).timeout(const Duration(seconds:20));
    if(response.statusCode!=200)throw StateError('الخدمة غير متاحة');
    final data=jsonDecode(response.body) as Map<String,dynamic>;
    final result=(data['responseData'] as Map?)?['translatedText']?.toString();
    if(result==null||result.isEmpty)throw StateError('لم تصل ترجمة');
    return result;
  }
  Future<void> translate() async {
    if(busy||input.text.trim().isEmpty)return;
    setState((){busy=true;message='';});
    try {
      final text=input.text.trim();
      final result=offline?await local(text):await online(text);
      if(mounted){
        setState(()=>output=result);
        await SavedTranslations.add('$source → $target | $text | $result');
      }
    } catch(e) {
      if(mounted)setState(()=>message='$e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  @override void dispose(){input.dispose();super.dispose();}
  @override Widget build(BuildContext context) {
    final languages=offline?const ['ar','en']:const ['ar','en','sv','fr','de','es','tr'];
    return Scaffold(
      appBar:AppBar(title:const Text('Aidict • المترجم'),
        actions:[IconButton(onPressed:widget.toggleTheme,icon:const Icon(Icons.dark_mode))]),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        const Text('عربي ↔ إنجليزي محليًا، وبقية اللغات عبر الإنترنت'),
        const SizedBox(height:16),
        SegmentedButton<bool>(segments:const [
          ButtonSegment(value:true,label:Text('محلي'),icon:Icon(Icons.wifi_off)),
          ButtonSegment(value:false,label:Text('إنترنت'),icon:Icon(Icons.wifi))],
          selected:{offline},onSelectionChanged:(s)=>setState((){
            offline=s.first;source='ar';target='en';output='';
          })),
        if(offline) OutlinedButton.icon(onPressed:busy?null:download,
          icon:const Icon(Icons.download),label:const Text('تنزيل العربية والإنجليزية')),
        Row(children:[
          Expanded(child:DropdownButtonFormField<String>(
            key:ValueKey('source-$offline-$source'),
            initialValue:source,
            items:languages.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
            onChanged:busy?null:(v)=>setState((){
              if(v==null)return;source=v;if(offline)target=v=='ar'?'en':'ar';
            }))),
          IconButton(onPressed:busy?null:()=>setState((){
            final v=source;source=target;target=v;output='';
          }),icon:const Icon(Icons.swap_horiz)),
          Expanded(child:DropdownButtonFormField<String>(
            key:ValueKey('target-$offline-$target'),
            initialValue:target,
            items:languages.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
            onChanged:busy?null:(v)=>setState((){
              if(v==null)return;target=v;if(offline)source=v=='ar'?'en':'ar';
            }))),
        ]),
        const SizedBox(height:16),
        TextField(controller:input,minLines:3,maxLines:6,
          decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'النص')),
        const SizedBox(height:12),
        FilledButton(onPressed:busy?null:translate,child:const Text('ترجمة')),
        if(busy)const LinearProgressIndicator(),
        if(message.isNotEmpty)Text(message),
        if(output.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            SelectableText(output),
            Wrap(children:[
              IconButton(tooltip:'نسخ',onPressed:()=>Clipboard.setData(ClipboardData(text:output)),icon:const Icon(Icons.copy)),
              IconButton(tooltip:'حفظ في المفضلة',onPressed:()=>SavedTranslations.add('$source → $target | ${input.text} | $output',favorite:true),icon:const Icon(Icons.favorite_border)),
            ]),
          ]))),
        const Divider(),
        Wrap(spacing:8,children:[
          OutlinedButton.icon(onPressed:() async {
            final clip=await Clipboard.getData(Clipboard.kTextPlain);
            if(clip?.text!=null)input.text=clip!.text!;
          },icon:const Icon(Icons.paste),label:const Text('لصق')),
          OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const TranslationLibraryPage(favorites:false))),child:const Text('السجل')),
          OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const TranslationLibraryPage(favorites:true))),child:const Text('المفضلة')),
          OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LearningScreen())),child:const Text('تعلم الكلمات')),
        ]),
        ExpansionTile(title:const Text('قاموس عربي–إنجليزي'),children:[
          TextField(onChanged:(v)=>setState(()=>dictionaryQuery=v),decoration:const InputDecoration(hintText:'ابحث عن كلمة',border:OutlineInputBorder())),
          if(dictionaryQuery.trim().isNotEmpty)Padding(padding:const EdgeInsets.all(12),child:Text(findWord(dictionaryQuery)??'لم تُعثر على الكلمة في القاموس المصغر')),
        ]),
      ]));
  }
}
