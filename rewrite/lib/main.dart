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
import 'home_screen.dart';
import 'ui_language.dart';
import 'offline_audio_page.dart';
import 'speech_locales.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const AidictApp());
class AidictApp extends StatefulWidget {
  const AidictApp({super.key});
  @override State<AidictApp> createState() => _AidictAppState();
}
class _AidictAppState extends State<AidictApp> {
  bool dark = false;
  String? uiLanguage;
  bool loaded = false;

  @override void initState(){super.initState();_restore();}
  Future<void> _restore() async {
    final prefs=await SharedPreferences.getInstance();
    if(!mounted)return;
    setState((){
      dark=prefs.getBool('aidict.dark.v1')??false;
      final saved=prefs.getString('aidict.ui_language.v1');
      uiLanguage=saved=='ar'||saved=='en'?saved:null;
      UiLanguage.code=uiLanguage??'ar';
      loaded=true;
    });
    if(uiLanguage==null){
      WidgetsBinding.instance.addPostFrameCallback((_){
        if(mounted)_chooseLanguage(firstTime:true);
      });
    }
  }
  Future<void> _toggleTheme() async {
    setState(()=>dark=!dark);
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool('aidict.dark.v1',dark);
  }
  Future<void> _setLanguage(String code) async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('aidict.ui_language.v1',code);
    if(mounted)setState((){uiLanguage=code;UiLanguage.code=code;});
  }
  Future<void> _chooseLanguage({bool firstTime=false}) async {
    if(!mounted)return;
    final picked=await showDialog<String>(
      context:context,
      barrierDismissible:!firstTime,
      builder:(context)=>PopScope(
        canPop:!firstTime,
        child:AlertDialog(
          title:const Text('لغة التطبيق / App language'),
          content:Column(mainAxisSize:MainAxisSize.min,children:[
            const Text('اختر لغة القوائم / Choose menu language'),
            const SizedBox(height:16),
            ListTile(leading:const Icon(Icons.language),
              title:const Text('العربية'),
              trailing:uiLanguage=='ar'?const Icon(Icons.check_circle,color:Colors.teal):null,
              onTap:()=>Navigator.pop(context,'ar')),
            ListTile(leading:const Icon(Icons.language),
              title:const Text('English'),
              trailing:uiLanguage=='en'?const Icon(Icons.check_circle,color:Colors.teal):null,
              onTap:()=>Navigator.pop(context,'en')),
          ]),
        ),
      ),
    );
    if(picked!=null)await _setLanguage(picked);
  }
  Future<void> _openSettings() async {
    if(!mounted)return;
    final ar=uiLanguage!='en';
    await showModalBottomSheet<void>(
      context:context,
      showDragHandle:true,
      builder:(sheetContext)=>SafeArea(child:Padding(
        padding:const EdgeInsets.all(20),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(ar?'الإعدادات':'Settings',
            style:Theme.of(sheetContext).textTheme.titleLarge),
          ListTile(leading:const Icon(Icons.language),
            title:Text(ar?'لغة التطبيق':'App language'),
            subtitle:Text(uiLanguage=='en'?'English':'العربية'),
            trailing:const Icon(Icons.chevron_right),
            onTap:(){
              Navigator.pop(sheetContext);
              _chooseLanguage();
            }),
          ListTile(leading:Icon(dark?Icons.light_mode:Icons.dark_mode),
            title:Text(ar?'تغيير المظهر':'Change theme'),
            onTap:(){
              Navigator.pop(sheetContext);
              _toggleTheme();
            }),
        ]),
      )),
    );
  }
  @override Widget build(BuildContext context) => MaterialApp(
    title:'Aidict', debugShowCheckedModeBanner:false,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(useMaterial3:true,colorSchemeSeed:const Color(0xFF007F86),scaffoldBackgroundColor:const Color(0xFFF5F9FA),appBarTheme:const AppBarTheme(centerTitle:false),cardTheme:CardThemeData(elevation:0,color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18))))),
    darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:const Color(0xFF22BDC2),cardTheme:const CardThemeData(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18))))),
    home: loaded
      ? DashboardShell(toggleTheme:_toggleTheme,onSettings:_openSettings,language:uiLanguage??'ar')
      : const Scaffold(body:Center(child:CircularProgressIndicator())),
  );
}

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key,required this.toggleTheme,required this.onSettings,required this.language});
  final VoidCallback toggleTheme;
  final VoidCallback onSettings;
  final String language;
  @override Widget build(BuildContext context)=>HomeScreen(
    onSettings:onSettings,
    language:language,
    onHistory:()=>Navigator.push<void>(context,MaterialPageRoute<void>(builder:(_)=>const TranslationLibraryPage(favorites:false))),
    onFeature:(feature){
      if(feature=='audio'){
        Navigator.push<void>(context,MaterialPageRoute<void>(builder:(_)=>const OfflineAudioPage()));
      }else{
        Navigator.push<void>(context,MaterialPageRoute<void>(builder:(_)=>TranslatorScreen(toggleTheme:toggleTheme,initialFeature:feature)));
      }
    },
  );
}

class TranslatorScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final String initialFeature;
  const TranslatorScreen({super.key, required this.toggleTheme,this.initialFeature='offline'});
  @override State<TranslatorScreen> createState()=>_TranslatorScreenState();
}
class _TranslatorScreenState extends State<TranslatorScreen> {
  final input=TextEditingController();
  final manager=OnDeviceTranslatorModelManager();
  final FlutterTts tts=FlutterTts();
  bool busy=false;
  @override void initState(){
    super.initState(); input.addListener(_refreshInputStats);
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(!mounted)return;
      switch(widget.initialFeature){
        case 'photo':
        case 'photo_translate': importImage(false); break;
        case 'conversation':
        case 'live': Navigator.push<void>(context,MaterialPageRoute<void>(builder:(_)=>VoiceConversationPage(translate:(text,s,t)=>local(text,sourceCode:s,targetCode:t)))); break;
        case 'chat': openAiTools(); break;
        case 'english': Navigator.push<void>(context,MaterialPageRoute<void>(builder:(_)=>const LearningScreen())); break;
        default: break;
      }
    });
  }
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
    message='';
    if(output.isNotEmpty){final old=input.text;input.text=output;output=old;_translatedInput=input.text;}
  });
  Future<void> translate() async {
    if(busy||input.text.trim().isEmpty)return;
    if(source==target){setState(()=>message='اختر لغتين مختلفتين للترجمة');return;}
    final requestedText=input.text.trim();
    final requestedSource=source;
    final requestedTarget=target;
    setState((){busy=true;message='';output='';});
    try {
      final result=await local(requestedText,sourceCode:requestedSource,targetCode:requestedTarget);
      if(mounted && input.text.trim()==requestedText && source==requestedSource && target==requestedTarget){
        setState((){_translatedInput=input.text;output=result;});
        await SavedTranslations.add('$requestedSource → $requestedTarget | $requestedText | $result');
      }
    } catch(e) {
      if(mounted)setState(()=>message='$e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> importImage(bool camera) async {
    if(busy)return;
    setState((){busy=true;message='';});
    try {
      final text=await ImageTextReader.selectAndExtract(camera:camera,context:context);
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
  Future<void> speakText(String value, String language) async {
    if(value.trim().isEmpty)return;
    try {
      await tts.stop();
      final locale=SpeechLocales.forLanguage(language);
      final available=await tts.isLanguageAvailable(locale);
      if(available==false || available==0 || available=='0') {
        throw StateError('صوت $locale غير مثبت على الهاتف؛ ثبّت بيانات النطق من إعدادات تحويل النص إلى كلام');
      }
      await tts.setLanguage(locale);
      await tts.speak(value);
    } catch(e) {if(mounted)setState(()=>message='تعذر النطق: $e');}
  }
  @override void dispose(){input.removeListener(_refreshInputStats);input.dispose();tts.stop();super.dispose();}
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(title:Text(UiLanguage.t('Aidict • المترجم','Aidict • Translator')),
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
        OutlinedButton.icon(onPressed:busy?null:download,
          icon:const Icon(Icons.download),label:Text(UiLanguage.t('تنزيل العربية والإنجليزية','Download Arabic and English'))),
        Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('١. اتجاه الترجمة — مطلوب',
            style:Theme.of(context).textTheme.titleMedium),
          Text(UiLanguage.t('اختر اتجاهًا واحدًا؛ تتحدد اللغة الثانية تلقائيًا.','Choose one direction; the other language is set automatically.')),
          const SizedBox(height:10),
          SegmentedButton<String>(
            segments:[
              ButtonSegment(value:'ar',label:Text(UiLanguage.t('عربي ← إنجليزي','Arabic → English'))),
              ButtonSegment(value:'en',label:Text(UiLanguage.t('English → عربي','English → Arabic'))),
            ],
            selected:{source},
            onSelectionChanged:busy?null:(values)=>setState((){
              source=values.first;target=source=='ar'?'en':'ar';output='';
            }),
          ),
          Text('المحدد: ${source=='ar'?'العربية إلى الإنجليزية':'الإنجليزية إلى العربية'}'),
        ]))),
        const SizedBox(height:16),
        TextField(controller:input,minLines:3,maxLines:6,
          decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'٢. النص المراد ترجمته — مطلوب')),
        if(input.text.trim().isNotEmpty)Padding(
          padding:const EdgeInsets.symmetric(vertical:6),
          child:Text('عدد الكلمات: ${TextPreparation.wordCount(input.text)} — عدد الأحرف: ${input.text.length}')),
        Card(child:ExpansionTile(
          leading:const Icon(Icons.widgets_outlined),
          title:Text(UiLanguage.t('مصادر النص والأدوات','Text sources and tools')),
          subtitle:Text(UiLanguage.t('اختياري • اختر أداة واحدة عند الحاجة','Optional • Choose a tool when needed')),
          children:[
            ListTile(leading:const Icon(Icons.camera_alt_outlined,color:Colors.blue),
              title:Text(UiLanguage.t('تصوير نص بالكاميرا','Scan text with camera')),
              subtitle:Text(UiLanguage.t('التقاط صورة، قص الجزء المطلوب، ثم استخراج النص','Take a photo, crop, then recognize text')),
              trailing:const Icon(Icons.chevron_left),
              enabled:!busy,onTap:()=>importImage(true)),
            ListTile(leading:const Icon(Icons.photo_library_outlined,color:Colors.purple),
              title:Text(UiLanguage.t('اختيار صورة','Choose an image')),
              subtitle:Text(UiLanguage.t('استخراج نص عربي أو إنجليزي من المعرض','Extract Arabic or English text from gallery')),
              trailing:const Icon(Icons.chevron_left),
              enabled:!busy,onTap:()=>importImage(false)),
            ListTile(leading:const Icon(Icons.picture_as_pdf_outlined,color:Colors.redAccent),
              title:Text(UiLanguage.t('قراءة مستند','Read document')),
              subtitle:Text(UiLanguage.t('PDF أو Word أو TXT','PDF, Word or TXT')),
              trailing:const Icon(Icons.chevron_left),
              enabled:!busy,onTap:importDocument),
            const Divider(),
            ListTile(leading:const Icon(Icons.preview_outlined),
              title:Text(UiLanguage.t('معاينة النص','Preview text')),
              subtitle:Text(UiLanguage.t('اختياري • مراجعة قبل الترجمة','Optional • Review before translating')),
              enabled:!busy,onTap:showDocumentPreview),
            ListTile(leading:const Icon(Icons.auto_fix_high),
              title:Text(UiLanguage.t('تنظيف النص','Clean text')),
              subtitle:Text(UiLanguage.t('اختياري • تحسين تنسيق النص','Optional • Improve formatting')),
              enabled:!busy,onTap:cleanImportedText),
            ListTile(leading:const Icon(Icons.delete_outline),
              title:Text(UiLanguage.t('مسح النص','Clear text')),
              subtitle:Text(UiLanguage.t('اختياري • بدء إدخال جديد','Optional • Start again')),
              enabled:!busy,onTap:clearText),
          ],
        )),
        const SizedBox(height:12),
        FilledButton(onPressed:busy?null:translate,child:Text(UiLanguage.t('٣. ترجمة النص','3. Translate text'))),
        if(busy)const LinearProgressIndicator(),
        if(message.isNotEmpty)Text(message),
        if(hasTranslation)Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[
              Expanded(child:Text('النص الأصلي (${source=='ar'?'العربية':'English'})',
                style:Theme.of(context).textTheme.titleSmall)),
              IconButton(tooltip:'استمع إلى النص الأصلي',
                onPressed:()=>speakText(input.text,source),
                icon:const Icon(Icons.volume_up_outlined)),
            ]),
            SelectableText(input.text),
            const Divider(height:24),
            Row(children:[
              Expanded(child:Text('الترجمة (${target=='ar'?'العربية':'English'})',
                style:Theme.of(context).textTheme.titleSmall)),
              IconButton(tooltip:'استمع إلى الترجمة',
                onPressed:()=>speakText(output,target),
                icon:const Icon(Icons.volume_up_outlined)),
            ]),
            SelectableText(output),
            Wrap(children:[
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
          },icon:const Icon(Icons.paste),label:Text(UiLanguage.t('لصق','Paste'))),
          OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>VoiceConversationPage(translate:(text,s,t)=>local(text,sourceCode:s,targetCode:t)))),icon:const Icon(Icons.mic),label:Text(UiLanguage.t('محادثة صوتية','Voice conversation'))),
          OutlinedButton.icon(onPressed:openAiTools,icon:const Icon(Icons.auto_awesome),label:Text(UiLanguage.t('أدوات الكتابة المحلية','Offline writing tools'))),
          OutlinedButton(onPressed:()=>openSavedTranslations(false),child:Text(UiLanguage.t('السجل','History'))),
          OutlinedButton(onPressed:()=>openSavedTranslations(true),child:Text(UiLanguage.t('المفضلة','Favorites'))),
          OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const LearningScreen())),child:Text(UiLanguage.t('تعلم الكلمات','Learn words'))),
        ]),
        ExpansionTile(title:Text(UiLanguage.t('قاموس عربي–إنجليزي','Arabic–English dictionary')),children:[
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
            Padding(padding:const EdgeInsets.all(12),
              child:Text(UiLanguage.t('لا توجد نتائج في القاموس المحلي المصغر.','No matches in the offline dictionary.'))),
        ]),
      ]));
  }
}
