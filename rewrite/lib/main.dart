import 'contextual_translation.dart';
import 'jordanian_dictionary.dart';
import 'translation_memory.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'translation_policy.dart';
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
  final navigatorKey=GlobalKey<NavigatorState>();
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
    final navContext=navigatorKey.currentContext;
    if(!mounted||navContext==null)return;
    final picked=await showDialog<String>(
      context:navContext,
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
    if(picked!=null){
      await _setLanguage(picked);
      if(firstTime && mounted){
        Navigator.push<void>(navContext,MaterialPageRoute<void>(
          builder:(_)=>const LanguageModelSettingsPage()));
      }
    }
  }
  Future<void> _openSettings() async {
    final navContext=navigatorKey.currentContext;
    if(!mounted||navContext==null)return;
    final ar=uiLanguage!='en';
    await showModalBottomSheet<void>(
      context:navContext,
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
          ListTile(leading:const Icon(Icons.download_for_offline_outlined),
            title:Text(ar?'نماذج الترجمة دون إنترنت':'Offline translation models'),
            subtitle:Text(ar?'تنزيل العربية والإنجليزية وفحص جاهزيتهما':'Download and verify Arabic and English'),
            onTap:(){
              Navigator.pop(sheetContext);
              Navigator.push<void>(navContext,MaterialPageRoute<void>(builder:(_)=>const LanguageModelSettingsPage()));
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
    title:'Aidict', navigatorKey:navigatorKey, debugShowCheckedModeBanner:false,
    builder:(context,child)=>Directionality(
      textDirection:UiLanguage.arabic?TextDirection.rtl:TextDirection.ltr,
      child:child??const SizedBox.shrink()),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(useMaterial3:true,colorSchemeSeed:const Color(0xFF007F86),scaffoldBackgroundColor:const Color(0xFFF5F9FA),appBarTheme:const AppBarTheme(centerTitle:false),cardTheme:CardThemeData(elevation:0,color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18))))),
    darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:const Color(0xFF22BDC2),cardTheme:const CardThemeData(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18))))),
    home: loaded
      ? DashboardShell(toggleTheme:_toggleTheme,onSettings:_openSettings,language:uiLanguage??'ar')
      : const Scaffold(body:Center(child:CircularProgressIndicator())),
  );
}


class LanguageModelSettingsPage extends StatefulWidget {
  const LanguageModelSettingsPage({super.key});
  @override State<LanguageModelSettingsPage> createState()=>_LanguageModelSettingsPageState();
}
class _LanguageModelSettingsPageState extends State<LanguageModelSettingsPage> {
  final manager=OnDeviceTranslatorModelManager();
  bool? arReady,enReady;
  bool busy=false;
  String status='';
  @override void initState(){super.initState();check();}
  Future<void> check() async {
    try {
      final ar=await manager.isModelDownloaded('ar');
      final en=await manager.isModelDownloaded('en');
      if(mounted)setState((){arReady=ar;enReady=en;});
    }catch(e){if(mounted)setState(()=>status='$e');}
  }
  Future<void> download() async {
    if(busy)return;
    setState((){busy=true;status=UiLanguage.t('جارٍ تنزيل النماذج...','Downloading models...');});
    try {
      for(final language in ['ar','en']) {
        if(!await manager.isModelDownloaded(language)){
          if(!await manager.downloadModel(language))throw StateError('Download failed: $language');
        }
      }
      await check();
      if(mounted)setState(()=>status=arReady==true&&enReady==true
        ?UiLanguage.t('تم التنزيل بنجاح؛ الترجمة جاهزة','Download successful; translation ready')
        :UiLanguage.t('التحميل غير مكتمل','Download incomplete'));
    }catch(e){if(mounted)setState(()=>status=UiLanguage.t('فشل التنزيل: ','Download failed: ')+'$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(UiLanguage.t('نماذج اللغة','Language models'))),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Text(UiLanguage.t('يلزم تنزيل نماذج الترجمة مرة واحدة مع الإنترنت؛ وبعدها تعمل الترجمة محليًا.','Download the models once using the internet. Translation then works offline.')),
      Card(child:Column(children:[
        ListTile(leading:Icon(arReady==true?Icons.check_circle:Icons.download_outlined,
          color:arReady==true?Colors.green:null),
          title:Text(UiLanguage.t('العربية','Arabic')),
          subtitle:Text(arReady==null?'...':arReady!?UiLanguage.t('مثبتة','Installed'):UiLanguage.t('غير مثبتة','Not installed'))),
        const Divider(height:1),
        ListTile(leading:Icon(enReady==true?Icons.check_circle:Icons.download_outlined,
          color:enReady==true?Colors.green:null),
          title:Text('English'),
          subtitle:Text(enReady==null?'...':enReady!?UiLanguage.t('مثبتة','Installed'):UiLanguage.t('غير مثبتة','Not installed'))),
      ])),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:busy?null:download,icon:const Icon(Icons.download),
        label:Text(arReady==true&&enReady==true
          ?UiLanguage.t('اللغات جاهزة — إعادة التحقق','Languages ready — recheck')
          :UiLanguage.t('تنزيل اللغات','Download languages'))),
      if(busy)const LinearProgressIndicator(),
      if(status.isNotEmpty)Padding(padding:const EdgeInsets.all(12),child:Text(status)),
      OutlinedButton.icon(onPressed:busy?null:check,icon:const Icon(Icons.refresh),
        label:Text(UiLanguage.t('تحديث الحالة','Refresh status'))),
    ]),
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
  bool? modelsReady;
  bool downloadingModels=false;
  String? lastSpokenLocale;
  bool detectLanguageAutomatically=true;
  String modelStatus='';
  String inputSource='type';
  @override void initState(){
    _refreshModels();
    _loadJordanianWords();
    tts.awaitSpeakCompletion(false);
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
    if(detectLanguageAutomatically){
      final ar=RegExp(r'[\u0600-\u06FF]').allMatches(input.text).length;
      final en=RegExp(r'[A-Za-z]').allMatches(input.text).length;
      if(ar+en>=2 && ar!=en){
        final detected=ar>en?'ar':'en';
        if(detected!=source){source=detected;target=detected=='ar'?'en':'ar';output='';}
      }
    }
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
  Map<String, String> jordanianWords=const {};
  final translationMemory=TranslationMemory(maxEntries: 120);
  Future<void> _loadJordanianWords() async {
    try {
      final loaded=await JordanianDictionary.load();
      if(mounted)setState(()=>jordanianWords=loaded);
    } catch (_) {
      // Keep the original built-in dictionary usable if the asset is missing.
    }
  }
  List<MapEntry<String,String>> get dictionaryMatches =>
      JordanianDictionary.search(dictionaryQuery,jordanianWords,
          fallback:words,limit:12);
  String source='ar',target='en',output='',message='';
  Future<void> _refreshModels() async {
    try {
      final ar=await manager.isModelDownloaded('ar');
      final en=await manager.isModelDownloaded('en');
      if(mounted)setState(()=>modelsReady=ar&&en);
    } catch(e) {if(mounted)setState(()=>modelsReady=false);}
  }
  Future<void> download() async {
    if(busy)return;
    setState((){busy=true;downloadingModels=true;modelStatus=UiLanguage.t('جارٍ تجهيز نماذج الترجمة...','Preparing translation models...');});
    try {
      for (final code in ['ar','en']) {
        if (!await manager.isModelDownloaded(code)) {
          if(!await manager.downloadModel(code)) throw StateError('تنزيل نموذج $code فشل');
        }
      }
      final ar=await manager.isModelDownloaded('ar');
      final en=await manager.isModelDownloaded('en');
      if(!ar||!en)throw StateError('Download did not install both models');
      if(mounted)setState((){modelsReady=true;message=UiLanguage.t('العربية والإنجليزية جاهزتان للاستخدام دون إنترنت','Arabic and English are ready offline');});
    } catch(e) {
      if(mounted)setState(()=>message='$e');
    } finally {if(mounted)setState((){busy=false;downloadingModels=false;});}
  }
  Future<String> local(String text,{String? sourceCode,String? targetCode}) async {
    final src=sourceCode??source;
    final dst=targetCode??target;
    if(!TranslationPolicy.offlineAllowed(src,dst))throw StateError('المحلي عربي ↔ إنجليزي فقط');
    if(!await manager.isModelDownloaded(src) || !await manager.isModelDownloaded(dst)) {
      throw StateError('نزّل نموذجي اللغة أولًا');
    }
    OnDeviceTranslator? translator;
    try {
      final parts = ContextualTranslation.planWithParagraphs(text, maxBytes: 2500);
      final translated = <String>[];
      for (final part in parts) {
        translated.add(await translationMemory.translate(src,dst,part.text,() async {
          translator ??= OnDeviceTranslator(
            sourceLanguage:src=='ar'?TranslateLanguage.arabic:TranslateLanguage.english,
            targetLanguage:dst=='ar'?TranslateLanguage.arabic:TranslateLanguage.english);
          return translator!.translateText(part.text);
        }));
      }
      return ContextualTranslation.finishWithParagraphs(parts, translated);
    } finally {await translator?.close();}
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
      title:Text(UiLanguage.t('معاينة النص المستخرج','Extracted text preview')),
      content:SizedBox(width:500,child:SingleChildScrollView(
        child:SelectableText(TextPreparation.preview(text,maxLength:3000)))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(UiLanguage.t('إغلاق','Close')))],
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
        inputSource=camera?'camera':'image';
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
        inputSource='document';
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
      final locale=SpeechLocales.forLanguage(language);
      if(lastSpokenLocale!=locale){
        final available=await tts.isLanguageAvailable(locale);
        if(available==false || available==0 || available=='0') {
          throw StateError('صوت $locale غير مثبت على الهاتف؛ ثبّت بيانات النطق من إعدادات تحويل النص إلى كلام');
        }
        await tts.setLanguage(locale);
        lastSpokenLocale=locale;
      }
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
              Text(UiLanguage.t('ترجم بسهولة','Translate simply'),
                style:Theme.of(context).textTheme.titleLarge),
              const SizedBox(height:4),
              Text(UiLanguage.t('اختر المصدر، ثم أدخل النص أو استخرجه، ثم اضغط ترجمة.','Choose a source, enter or extract text, then translate.')),
            ]))),
        const SizedBox(height:14),
        Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[
              Icon(modelsReady==true?Icons.check_circle:Icons.cloud_download_outlined,
                color:modelsReady==true?Colors.green:Colors.blue),
              const SizedBox(width:8),
              Expanded(child:Text(modelsReady==true
                ?UiLanguage.t('نماذج الترجمة مثبتة وجاهزة','Translation models installed and ready')
                :modelsReady==null?UiLanguage.t('جارٍ فحص اللغات...','Checking languages...')
                :UiLanguage.t('نماذج الترجمة تحتاج إلى تنزيل مرة واحدة','Download translation models once'))),
            ]),
            if(modelsReady!=true)OutlinedButton.icon(
              onPressed:busy?null:download,
              icon:Icon(downloadingModels?Icons.hourglass_top:Icons.download),
              label:Text(downloadingModels?UiLanguage.t('جارٍ التنزيل...','Downloading...')
                :UiLanguage.t('تنزيل العربية والإنجليزية','Download Arabic and English'))),
            if(downloadingModels)const LinearProgressIndicator(),
          ]))),
        const SizedBox(height:14),
        Text(UiLanguage.t('١. مصدر النص','1. Text source'),style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        Card(child:Column(children:[
          ListTile(
            leading:Icon(Icons.keyboard,color:inputSource=='type'?Colors.teal:null),
            title:Text(UiLanguage.t('كتابة أو لصق نص','Type or paste text')),
            subtitle:Text(UiLanguage.t('المصدر الافتراضي','Default source')),
            trailing:inputSource=='type'?const Icon(Icons.check_circle,color:Colors.teal):null,
            onTap:()=>setState(()=>inputSource='type')),
          const Divider(height:1),
          ListTile(leading:const Icon(Icons.camera_alt_outlined,color:Colors.blue),
            title:Text(UiLanguage.t('الكاميرا','Camera')),
            trailing:inputSource=='camera'?const Icon(Icons.check_circle,color:Colors.teal):const Icon(Icons.chevron_right),
            onTap:busy?null:()=>importImage(true)),
          ListTile(leading:const Icon(Icons.photo_library_outlined,color:Colors.purple),
            title:Text(UiLanguage.t('صورة من المعرض','Gallery image')),
            trailing:inputSource=='image'?const Icon(Icons.check_circle,color:Colors.teal):const Icon(Icons.chevron_right),
            onTap:busy?null:()=>importImage(false)),
          ListTile(leading:const Icon(Icons.picture_as_pdf_outlined,color:Colors.redAccent),
            title:Text(UiLanguage.t('PDF / Word / TXT','PDF / Word / TXT')),
            trailing:inputSource=='document'?const Icon(Icons.check_circle,color:Colors.teal):const Icon(Icons.chevron_right),
            onTap:busy?null:importDocument),
        ])),
        const SizedBox(height:12),
        TextField(controller:input,minLines:3,maxLines:7,
          decoration:InputDecoration(border:const OutlineInputBorder(),
            labelText:UiLanguage.t('٢. النص المراد ترجمته','2. Text to translate'),
            suffixIcon:IconButton(tooltip:UiLanguage.t('لصق','Paste'),
              onPressed:() async {
                final clip=await Clipboard.getData(Clipboard.kTextPlain);
                if(clip?.text!=null){input.text=clip!.text!;setState(()=>inputSource='type');}
              },icon:const Icon(Icons.paste)))),
        const SizedBox(height:12),
        Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text(UiLanguage.t('٣. لغة الترجمة','3. Translation language'),
              style:Theme.of(context).textTheme.titleMedium),
            const SizedBox(height:6),
            Text(UiLanguage.t('حدّد الاتجاه بوضوح؛ يدعم التطبيق العربية والإنجليزية.','Choose the direction; Arabic and English are supported.')),
            SwitchListTile.adaptive(
              contentPadding:EdgeInsets.zero,
              title:Text(UiLanguage.t('اكتشاف اللغة تلقائيًا','Detect text language automatically')),
              subtitle:Text(UiLanguage.t('يمكنك إيقافه لتحديد الاتجاه بنفسك','Turn off to choose manually')),
              value:detectLanguageAutomatically,
              onChanged:(v)=>setState((){detectLanguageAutomatically=v;_refreshInputStats();}),
            ),
            Text(UiLanguage.t('اللغة الحالية: ','Current language: ')+(source=='ar'?UiLanguage.t('العربية','Arabic'):'English')),
            const SizedBox(height:9),
            SegmentedButton<String>(segments:[
              ButtonSegment(value:'ar',label:Text(UiLanguage.t('عربي ← إنجليزي','Arabic → English'))),
              ButtonSegment(value:'en',label:Text(UiLanguage.t('إنجليزي ← عربي','English → Arabic'))),
            ],selected:{source},onSelectionChanged:busy?null:(v)=>setState((){
              source=v.first;target=source=='ar'?'en':'ar';output='';detectLanguageAutomatically=false;
            })),
          ]))),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:busy||input.text.trim().isEmpty?null:translate,
          icon:const Icon(Icons.translate),label:Text(UiLanguage.t('ترجمة النص','Translate text'))),
        ExpansionTile(
          leading:const Icon(Icons.tune),
          title:Text(UiLanguage.t('أدوات متقدمة','Advanced tools')),
          subtitle:Text(UiLanguage.t('اختياري: تنظيف ومعاينة ومسح النص','Optional: clean, preview or clear')),
          children:[
            ListTile(leading:const Icon(Icons.preview),title:Text(UiLanguage.t('معاينة النص','Preview')),
              onTap:showDocumentPreview),
            ListTile(leading:const Icon(Icons.auto_fix_high),title:Text(UiLanguage.t('تنظيف النص','Clean text')),
              onTap:cleanImportedText),
            ListTile(leading:const Icon(Icons.delete_outline),title:Text(UiLanguage.t('مسح النص','Clear text')),
              onTap:clearText),
          ]),
        if(busy)const LinearProgressIndicator(),
        if(message.isNotEmpty)Text(message),
        if(hasTranslation)Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[
              Expanded(child:Text(UiLanguage.t('النص الأصلي (${source=='ar'?'العربية':'English'})','Original text (${source=='ar'?'Arabic':'English'})'),
                style:Theme.of(context).textTheme.titleSmall)),
              IconButton(tooltip:UiLanguage.t('استمع إلى النص الأصلي','Listen to source text'),
                onPressed:()=>speakText(input.text,source),
                icon:const Icon(Icons.volume_up_outlined)),
            ]),
            SelectableText(input.text),
            const Divider(height:24),
            Row(children:[
              Expanded(child:Text(UiLanguage.t('الترجمة (${target=='ar'?'العربية':'English'})','Translation (${target=='ar'?'Arabic':'English'})'),
                style:Theme.of(context).textTheme.titleSmall)),
              IconButton(tooltip:UiLanguage.t('استمع إلى الترجمة','Listen to translation'),
                onPressed:()=>speakText(output,target),
                icon:const Icon(Icons.volume_up_outlined)),
            ]),
            SelectableText(output),
            Wrap(children:[
              IconButton(tooltip:UiLanguage.t('نسخ','Copy'),onPressed:()=>Clipboard.setData(ClipboardData(text:output)),icon:const Icon(Icons.copy)),
              IconButton(tooltip:UiLanguage.t('نسخ النص والترجمة معًا','Copy original and translation'),onPressed:shareTranslation,icon:const Icon(Icons.content_copy)),
              IconButton(tooltip:UiLanguage.t('حفظ في المفضلة','Save to favorites'),onPressed:()=>SavedTranslations.add('$source → $target | ${input.text} | $output',favorite:true),icon:const Icon(Icons.favorite_border)),
            ]),
          ]))),
        ExpansionTile(title:Text(UiLanguage.t('قاموس عربي–إنجليزي','Arabic–English dictionary')),children:[
          TextField(onChanged:(v)=>setState(()=>dictionaryQuery=v),decoration:const InputDecoration(hintText:'ابحث عن كلمة',border:OutlineInputBorder())),
          if(dictionaryQuery.trim().isNotEmpty)
            ...dictionaryMatches.map((entry)=>ListTile(
              title:Text(entry.key),subtitle:Text(entry.value),
              onTap:()=>setState((){
                input.text=entry.key;
                output=entry.value;
                _translatedInput=entry.key;
                source='en';target='ar';
                message='تم اختيار الكلمة من القاموس';
              }),
            )),
          if(dictionaryQuery.trim().isNotEmpty&&dictionaryMatches.isEmpty)
            Padding(padding:const EdgeInsets.all(12),
              child:Text(UiLanguage.t('لا توجد نتائج في القاموس المحلي المصغر.','No matches in the offline dictionary.'))),
        ]),
      ]));
  }
}
