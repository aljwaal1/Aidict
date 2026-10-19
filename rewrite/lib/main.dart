import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  final FlutterTts tts=FlutterTts();
  bool offline=true, busy=false;
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
      final url = Uri.https('api.mymemory.translated.net', '/get',
          {'q': chunk, 'langpair': '${sourceCode??source}|${targetCode??target}'});
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError('تعذرت ترجمة جزء من المستند (HTTP ${response.statusCode})');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['responseStatus'];
      if (status is num && status != 200) {
        throw StateError('خدمة الترجمة رفضت الطلب (رمز $status)');
      }
      final result = (data['responseData'] as Map?)?['translatedText']?.toString();
      if (result == null || result.isEmpty) {
        throw StateError('لم تصل ترجمة لأحد أجزاء المستند');
      }
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
      setState((){input.text=parts.sublist(1,parts.length-1).join(' | ');output=parts.last;message='تم استرجاع الترجمة المحفوظة';});
    }else{
      setState((){input.text=selected;output='';message='تم استرجاع النص المحفوظ';});
    }
  }
  void cleanImportedText() => setState(() {
    input.text=TextPreparation.normalize(input.text);
    message='تم تنظيف المسافات وفواصل الأسطر';
  });
  void showAiFeatureInfo() {
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('مساعد الكتابة بالذكاء الاصطناعي'),
      content:const Text('إعادة الصياغة والتدقيق المتقدم تحتاج مزود AI ومفتاح وصول آمن. الميزة غير مفعلة إلى حين توفير خدمة موثوقة؛ لم يتم إرسال أي نص إلى مزود AI.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('موافق'))],
    ));
  }
  void clearText() => setState(() {input.clear();output='';message='';});
  void reverseLanguages() => setState(() {
    final previous=source;source=target;target=previous;
    if(output.isNotEmpty){final old=input.text;input.text=output;output=old;}
  });
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
  Future<void> importImage(bool camera) async {
    if(busy)return;
    setState((){busy=true;message='';});
    try {
      final text=await ImageTextReader.selectAndExtract(camera:camera);
      if(text!=null&&mounted)setState((){
        input.text=text;
        output='';
        message='تم استخراج النص من الصورة. اضغط ترجمة.';
      });
    } catch(e) {
      if(mounted)setState(()=>message='تعذر استخراج النص: $e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> importDocument() async {
    if(busy)return;
    setState((){busy=true;message='';});
    try {
      final text=await DocumentTextReaderV2.selectAndExtract();
      if(text!=null&&mounted)setState((){
        input.text=text;
        output='';
        message='تم استخراج النص من المستند. اضغط ترجمة.';
      });
    } catch(e) {
      if(mounted)setState(()=>message='تعذر قراءة المستند: $e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> speakTranslation() async {
    if(output.trim().isEmpty)return;
    try {
      await tts.setLanguage(target=='ar'?'ar':'en-US');
      await tts.speak(output);
    } catch(e) {if(mounted)setState(()=>message='تعذر النطق: $e');}
  }
  @override void dispose(){input.dispose();tts.stop();super.dispose();}
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
          IconButton(tooltip:'تبديل اللغات والنصوص',onPressed:busy?null:reverseLanguages,icon:const Icon(Icons.swap_horiz)),
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
        if(input.text.trim().isNotEmpty)Padding(
          padding:const EdgeInsets.symmetric(vertical:6),
          child:Text('عدد الكلمات: ${TextPreparation.wordCount(input.text)} — عدد الأحرف: ${input.text.length}')),
        OutlinedButton.icon(onPressed:busy?null:cleanImportedText,
          icon:const Icon(Icons.auto_fix_high),label:const Text('تنظيف النص')),
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
        const Padding(padding:EdgeInsets.only(top:8),child:Text('استخراج النص من الصور يدعم الحروف اللاتينية حاليًا؛ التعرف على العربية من الصور غير متاح في هذا الإصدار.')),
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
          OutlinedButton.icon(onPressed:showAiFeatureInfo,icon:const Icon(Icons.auto_awesome),label:const Text('مساعد الكتابة AI')),
          OutlinedButton(onPressed:()=>openSavedTranslations(false),child:const Text('السجل')),
          OutlinedButton(onPressed:()=>openSavedTranslations(true),child:const Text('المفضلة')),
          OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LearningScreen())),child:const Text('تعلم الكلمات')),
        ]),
        ExpansionTile(title:const Text('قاموس عربي–إنجليزي'),children:[
          TextField(onChanged:(v)=>setState(()=>dictionaryQuery=v),decoration:const InputDecoration(hintText:'ابحث عن كلمة',border:OutlineInputBorder())),
          if(dictionaryQuery.trim().isNotEmpty)Padding(padding:const EdgeInsets.all(12),child:Text(findWord(dictionaryQuery)??'لم تُعثر على الكلمة في القاموس المصغر')),
        ]),
      ]));
  }
}
