import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'translation_policy.dart';
import 'translation_chunks.dart';
import 'extra_features.dart';
import 'image_text_reader.dart';
import 'document_text_reader_v2.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_conversation_page.dart';
import 'text_preparation.dart';
import 'ai_tools_page.dart';
import 'translation_engine.dart';
import 'speech_locales.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AidictApp());
class AidictApp extends StatefulWidget {
  const AidictApp({super.key});
  @override State<AidictApp> createState() => _AidictAppState();
}
class _AidictAppState extends State<AidictApp> {
  bool dark = false;
  @override void initState(){super.initState();_restore();}
  Future<void> _restore() async {
    final prefs=await SharedPreferences.getInstance();
    if(mounted)setState(()=>dark=prefs.getBool('aidict.dark.v1')??false);
  }
  Future<void> _toggleTheme() async {
    setState(()=>dark=!dark);
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool('aidict.dark.v1',dark);
  }
  @override Widget build(BuildContext context) => MaterialApp(
    title:'Aidict', debugShowCheckedModeBanner:false,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(useMaterial3:true,colorSchemeSeed:const Color(0xFF007F86),scaffoldBackgroundColor:const Color(0xFFF5F9FA),appBarTheme:const AppBarTheme(centerTitle:false),cardTheme:CardThemeData(elevation:0,color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18))))),
    darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:const Color(0xFF22BDC2),cardTheme:const CardThemeData(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18))))),
    home: Directionality(textDirection:TextDirection.rtl,
      child: TranslatorScreen(toggleTheme:_toggleTheme)),
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
  final FlutterTts tts=FlutterTts();
  bool offline=true, busy=false;
  OnlineEngine engine=OnlineEngine.myMemory;
  final engineEndpoint=TextEditingController();
  @override void initState(){super.initState();input.addListener(_refreshInputStats);_restoreSettings();}
  void _refreshInputStats(){
    if(!mounted)return;
    // A previously translated result must not be presented as the translation
    // of newly edited source text.
    if(output.isNotEmpty && input.text!=_translatedInput){
      setState((){output='';message='تم تغيير النص؛ اضغط ترجمة مجددًا';});
    }else{
      setState((){});
    }
  }
  String _translatedInput='';
  Future<void> _restoreSettings() async {
    final prefs=await SharedPreferences.getInstance();
    final saved=prefs.getString('aidict.engine.v1');
    engineEndpoint.text=prefs.getString('aidict.libre.url.v1')??'';
    if(mounted&&saved=='libreTranslate')setState(()=>engine=OnlineEngine.libreTranslate);
  }
  Future<void> _saveEngine() async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('aidict.engine.v1',engine.name);
    await prefs.setString('aidict.libre.url.v1',engineEndpoint.text.trim());
  }
  bool get hasTranslation => output.trim().isNotEmpty;
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
  Future<String> local(String text,{String? sourceCode,String? targetCode}) async {
    final src=sourceCode??source;
    final dst=targetCode??target;
    if(!TranslationPolicy.offlineAllowed(src,dst))throw StateError('المحلي عربي ↔ إنجليزي فقط');
    if(!await manager.isModelDownloaded(src) || !await manager.isModelDownloaded(dst)) {
      throw StateError('نزّل نموذجي اللغة أولًا');
    }
    final t=OnDeviceTranslator(
      sourceLanguage:src=='ar'?TranslateLanguage.arabic:TranslateLanguage.english,
      targetLanguage:dst=='ar'?TranslateLanguage.arabic:TranslateLanguage.english);
    try {
      final parts = TranslationChunks.split(text, maxBytes: 2500);
      final translated = <String>[];
      for (final part in parts) {
        translated.add(await t.translateText(part));
      }
      return translated.join('\n');
    } finally {await t.close();}
  }
  Future<String> online(String text,{String? sourceCode,String? targetCode}) async {
    final results = <String>[];
    final chunks = TranslationChunks.split(text);
    for (var index = 0; index < chunks.length; index++) {
      final chunk = chunks[index];
      if (mounted) {
        setState(() => message = 'ترجمة الجزء ${index + 1} من ${chunks.length}');
      }
      if (chunk.trim().isEmpty) {
        results.add(chunk);
        continue;
      }
      final result=await TranslationEngine.translate(
        text:chunk,source:sourceCode??source,target:targetCode??target,
        engine:engine,endpoint:engineEndpoint.text);
      results.add(result);
    }
    return results.join('\n');
  }
  Future<void> openSavedTranslations(bool favorites) async {
    final selected=await Navigator.push<String>(context,MaterialPageRoute<String>(
      builder:(_)=>TranslationLibraryPage(favorites:favorites)));
    if(!mounted||selected==null)return;
    final parts=selected.split(' | ');
    if(parts.length>=3){
      setState((){input.text=parts.sublist(1,parts.length-1).join(' | ');_translatedInput=input.text;output=parts.last;message='تم استرجاع الترجمة المحفوظة';});
    }else{
      setState((){input.text=selected;output='';message='تم استرجاع النص المحفوظ';});
    }
  }
  void showDocumentPreview() {
    final text=TextPreparation.normalize(input.text);
    if(text.isEmpty) {return;}
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('معاينة النص المستخرج'),
      content:SizedBox(width:500,child:SingleChildScrollView(
        child:SelectableText(TextPreparation.preview(text,maxLength:3000)))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))],
    ));
  }
  void cleanImportedText() => setState(() {
    input.text=TextPreparation.normalize(input.text);
    message='تم تنظيف المسافات وفواصل الأسطر';
  });
  void openAiTools() {
    Navigator.push<void>(context,MaterialPageRoute<void>(
      builder:(_)=>AiToolsPage(initialText:input.text,onResult:(value){
        if(mounted) { setState((){
          input.text=value;
          output='';
          message='تم استيراد نتيجة المعالجة';
        });
        }
      })));
  }
  void clearText() => setState(() {input.clear();output='';message='';});
  void reverseLanguages() => setState(() {
    final previous=source;source=target;target=previous;
    if(output.isNotEmpty){final old=input.text;input.text=output;output=old;_translatedInput=input.text;}
  });
  Future<void> translate() async {
    if(busy||input.text.trim().isEmpty)return;
    if(source==target){setState(()=>message='اختر لغتين مختلفتين للترجمة');return;}
    setState((){busy=true;message='';});
    try {
      if(!offline)await _saveEngine();
      final text=input.text.trim();
      final result=offline?await local(text):await online(text);
      if(mounted){
        setState((){_translatedInput=text;output=result;});
        await SavedTranslations.add('$source → $target | $text | $result');
      }
    } catch(e) {
      if(mounted)setState(()=>message='$e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> importImage(bool camera) async {
    if(busy)return;
    setState((){busy=true;message='';});
    try {
      final text=await ImageTextReader.selectAndExtract(camera:camera);
      if(text!=null&&mounted) { setState((){
        input.text=text;
        output='';
        message='تم استخراج النص من الصورة. اضغط ترجمة.';
      });
      }
    } catch(e) {
      if(mounted)setState(()=>message='تعذر استخراج النص: $e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> importDocument() async {
    if(busy)return;
    setState((){busy=true;message='';});
    try {
      final text=await DocumentTextReaderV2.selectAndExtract();
      if(text!=null&&mounted) { setState((){
        input.text=text;
        output='';
        message='تم استخراج النص من المستند. اضغط ترجمة.';
      });
      }
    } catch(e) {
      if(mounted)setState(()=>message='تعذر قراءة المستند: $e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> shareTranslation() async {
    if(output.trim().isEmpty)return;
    await Clipboard.setData(ClipboardData(text:'${input.text}\n\n$output'));
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم نسخ النص والترجمة معًا')));
  }
  Future<void> speakTranslation() async {
    if(output.trim().isEmpty)return;
    try {
      await tts.setLanguage(SpeechLocales.forLanguage(target));
      await tts.speak(output);
    } catch(e) {if(mounted)setState(()=>message='تعذر النطق: $e');}
  }
  @override void dispose(){input.removeListener(_refreshInputStats);input.dispose();engineEndpoint.dispose();tts.stop();super.dispose();}
  @override Widget build(BuildContext context) {
    final languages=offline?const ['ar','en']:const ['ar','en','sv','fr','de','es','tr'];
    return Scaffold(
      appBar:AppBar(title:const Text('Aidict • المترجم'),
        actions:[IconButton(onPressed:widget.toggleTheme,icon:const Icon(Icons.dark_mode))]),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Card(color:Theme.of(context).colorScheme.primaryContainer,
          child:Padding(padding:const EdgeInsets.all(18),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('ترجم، تعلّم، وتحدث',style:Theme.of(context).textTheme.titleLarge),
              const SizedBox(height:6),
              const Text('ترجمة عربي ↔ إنجليزي على الجهاز بعد تنزيل النماذج مرة واحدة'),
            ]))),
        const SizedBox(height:16),
        const Card(child:Padding(padding:EdgeInsets.all(12),
          child:Row(children:[Icon(Icons.phonelink_off),SizedBox(width:8),
            Expanded(child:Text('وضع محلي فقط — لا خوادم ولا خدمات ترجمة مدفوعة'))]))),
        if(offline) OutlinedButton.icon(onPressed:busy?null:download,
          icon:const Icon(Icons.download),label:const Text('تنزيل العربية والإنجليزية')),
        Row(children:[
          Expanded(child:DropdownButtonFormField<String>(
            key:ValueKey('source-$offline-$source'),
            initialValue:source,
            items:languages.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
            onChanged:busy?null:(v)=>setState((){
              if(v==null){return;} source=v;if(offline){target=v=='ar'?'en':'ar';}
            }))),
          IconButton(tooltip:'تبديل اللغات والنصوص',onPressed:busy?null:reverseLanguages,icon:const Icon(Icons.swap_horiz)),
          Expanded(child:DropdownButtonFormField<String>(
            key:ValueKey('target-$offline-$target'),
            initialValue:target,
            items:languages.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
            onChanged:busy?null:(v)=>setState((){
              if(v==null){return;} target=v;if(offline){source=v=='ar'?'en':'ar';}
            }))),
        ]),
        const SizedBox(height:16),
        TextField(controller:input,minLines:3,maxLines:6,
          decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'النص')),
        if(input.text.trim().isNotEmpty)Padding(
          padding:const EdgeInsets.symmetric(vertical:6),
          child:Text('عدد الكلمات: ${TextPreparation.wordCount(input.text)} — عدد الأحرف: ${input.text.length}')),
        Wrap(spacing:8,children:[
          OutlinedButton.icon(onPressed:busy?null:showDocumentPreview,icon:const Icon(Icons.preview),label:const Text('معاينة النص')),
          OutlinedButton.icon(onPressed:busy?null:cleanImportedText,
          icon:const Icon(Icons.auto_fix_high),label:const Text('تنظيف النص')),
        ]),
        Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:busy?null:clearText,icon:const Icon(Icons.clear),label:const Text('مسح النص'))),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:4,children:[
          OutlinedButton.icon(onPressed:busy?null:()=>importImage(true),
            icon:const Icon(Icons.camera_alt_outlined),label:const Text('الكاميرا')),
          OutlinedButton.icon(onPressed:busy?null:()=>importImage(false),
            icon:const Icon(Icons.photo_library_outlined),label:const Text('صورة')),
          OutlinedButton.icon(onPressed:busy?null:importDocument,
            icon:const Icon(Icons.description_outlined),label:const Text('PDF / Word / TXT')),
        ]),
        const Padding(padding:EdgeInsets.only(top:8),child:Text('تعرف الصور يدعم النصوص اللاتينية فقط حاليًا؛ ملفات PDF المصورة والعربية في الصور تحتاج خدمة OCR أخرى.')),
        const SizedBox(height:12),
        FilledButton(onPressed:busy?null:translate,child:const Text('ترجمة')),
        if(busy)const LinearProgressIndicator(),
        if(message.isNotEmpty)Text(message),
        if(hasTranslation)Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            SelectableText(output),
            Wrap(children:[
              IconButton(tooltip:'الاستماع للترجمة',onPressed:speakTranslation,icon:const Icon(Icons.volume_up)),
              IconButton(tooltip:'نسخ',onPressed:()=>Clipboard.setData(ClipboardData(text:output)),icon:const Icon(Icons.copy)),
              IconButton(tooltip:'نسخ النص والترجمة معًا',onPressed:shareTranslation,icon:const Icon(Icons.content_copy)),
              IconButton(tooltip:'حفظ في المفضلة',onPressed:()=>SavedTranslations.add('$source → $target | ${input.text} | $output',favorite:true),icon:const Icon(Icons.favorite_border)),
            ]),
          ]))),
        const Divider(),
        Wrap(spacing:8,children:[
          OutlinedButton.icon(onPressed:() async {
            final clip=await Clipboard.getData(Clipboard.kTextPlain);
            if(clip?.text!=null)input.text=clip!.text!;
          },icon:const Icon(Icons.paste),label:const Text('لصق')),
          OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>VoiceConversationPage(translate:(text,s,t)=>offline?local(text,sourceCode:s,targetCode:t):online(text,sourceCode:s,targetCode:t)))),icon:const Icon(Icons.mic),label:const Text('محادثة صوتية')),
          OutlinedButton.icon(onPressed:openAiTools,icon:const Icon(Icons.auto_awesome),label:const Text('مساعد الكتابة AI')),
          OutlinedButton(onPressed:()=>openSavedTranslations(false),child:const Text('السجل')),
          OutlinedButton(onPressed:()=>openSavedTranslations(true),child:const Text('المفضلة')),
          OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LearningScreen())),child:const Text('تعلم الكلمات')),
        ]),
        ExpansionTile(title:const Text('قاموس عربي–إنجليزي'),children:[
          TextField(onChanged:(v)=>setState(()=>dictionaryQuery=v),decoration:const InputDecoration(hintText:'ابحث عن كلمة',border:OutlineInputBorder())),
          if(dictionaryQuery.trim().isNotEmpty)
            ...searchWords(dictionaryQuery,limit:12).map((entry)=>ListTile(
              title:Text(entry.key),subtitle:Text(entry.value),
              onTap:()=>setState((){
                input.text=entry.key;
                output=entry.value;
                _translatedInput=entry.key;
                source='en';target='ar';
                message='تم اختيار الكلمة من القاموس';
              }),
            )),
          if(dictionaryQuery.trim().isNotEmpty&&searchWords(dictionaryQuery).isEmpty)
            const Padding(padding:EdgeInsets.all(12),
              child:Text('لا توجد نتائج في القاموس المحلي المصغر.')),
        ]),
      ]));
  }
}
