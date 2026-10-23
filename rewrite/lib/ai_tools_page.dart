import 'ui_language.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:flutter/material.dart';
import 'offline_writing_tools.dart';
import 'offline_audio_page.dart';

/// All actions on this page work on-device and never contact a server.
class AiToolsPage extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onResult;
  const AiToolsPage({super.key,required this.initialText,required this.onResult});
  @override State<AiToolsPage> createState()=>_AiToolsPageState();
}

class _AiToolsPageState extends State<AiToolsPage> {
  final text=TextEditingController();
  String result='',error='';
  final LlamaController llama=LlamaController();
  bool modelReady=false,generating=false;
  String modelName='لم يتم اختيار نموذج GGUF';
  StreamSubscription<String>? generation;

  Future<void> chooseModel() async {
    final picked=await openFile(acceptedTypeGroups:[const XTypeGroup(label:'GGUF',extensions:['gguf'])]);
    if(picked==null)return;
    setState((){generating=true;error='';modelReady=false;});
    try {
      final size=await picked.length();
      if(size<1000000)throw const FormatException('ملف النموذج صغير أو غير صالح');
      if(size>3*1024*1024*1024)throw const FormatException('النموذج أكبر من 3 GB؛ اختر نموذجًا أصغر مناسبًا لذاكرة الهاتف');
      final support=await getApplicationSupportDirectory();
      final modelDirectory=Directory('${support.path}/local_llm');
      await modelDirectory.create(recursive:true);
      final persistent=File('${modelDirectory.path}/active.gguf');
      if(picked.path!=persistent.path){
        final staging=File('${modelDirectory.path}/importing.gguf');
        try {
          await picked.saveTo(staging.path);
          if(await staging.length()!=size)throw const FormatException('نسخ النموذج غير مكتمل');
          if(await persistent.exists())await persistent.delete();
          await staging.rename(persistent.path);
        } finally {if(await staging.exists())await staging.delete();}
      }
      await llama.loadModel(modelPath:persistent.path,threads:4,contextSize:2048);
      if(mounted)setState((){modelName=picked.name;modelReady=true;});
    }catch(e){if(mounted)setState(()=>error='تعذر تحميل نموذج GGUF المحلي: $e');}
    finally{if(mounted)setState(()=>generating=false);}
  }

  Future<void> rewriteLocally() async {
    final source=text.text.trim();
    if(source.isEmpty||!modelReady||generating)return;
    setState((){result='';error='';generating=true;});
    try {
      generation=llama.generateChat(messages:[
        ChatMessage(role:'system',content:'أعد صياغة النص مع حفظ المعنى واللغة دون إضافة معلومات جديدة. أجب بالنص المعاد صياغته فقط.'),
        ChatMessage(role:'user',content:source),
      ],maxTokens:512,temperature:0.3).listen((chunk){
        if(mounted)setState(()=>result+=chunk);
      },onError:(Object e){if(mounted)setState((){error='تعذر تشغيل النموذج محليًا: $e';generating=false;});},
      onDone:(){if(mounted)setState(()=>generating=false);});
    }catch(e){if(mounted)setState((){error='$e';generating=false;});}
  }

  @override void initState(){
    super.initState();
    text.text=widget.initialText;
  }
  void runOffline(bool summarize) {
    final source=text.text.trim();
    if(source.isEmpty){
      setState(()=>error='أدخل النص أولًا');
      return;
    }
    setState((){
      error='';
      result=summarize
        ? OfflineWritingTools.extractiveSummary(source)
        : OfflineWritingTools.proofreadFormatting(source);
    });
  }
  @override void dispose(){
    generation?.cancel();
    llama.stop();
    llama.dispose();
    text.dispose();super.dispose();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(UiLanguage.t('أدوات النص المحلية','Offline AI writing tools'))),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Text(UiLanguage.t('كل الأدوات في هذه الصفحة تعمل على الهاتف دون خادم أو API. التلخيص استخراجي؛ والتنسيق ليس تدقيقًا لغويًا بنموذج ذكاء اصطناعي.','All tools on this page run locally. Summarization is extractive, and formatting is not AI-powered proofreading.')),
      const SizedBox(height:16),
      TextField(controller:text,maxLines:8,minLines:4,
        decoration:InputDecoration(labelText:UiLanguage.t('النص','Text'),
          border:const OutlineInputBorder())),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        FilledButton.icon(onPressed:()=>runOffline(true),
          icon:const Icon(Icons.short_text),label:Text(UiLanguage.t('تلخيص محلي','Offline summary'))),
        OutlinedButton.icon(onPressed:()=>runOffline(false),
          icon:const Icon(Icons.format_align_left),label:Text(UiLanguage.t('تنسيق النص','Format text'))),
      ]),
      Card(child:ExpansionTile(
        leading:const Icon(Icons.auto_awesome,color:Colors.purple),
        title:Text(UiLanguage.t('إعادة الصياغة الذكية','AI rewriting')),
        subtitle:Text(UiLanguage.t(
          'اختياري — يحتاج نموذجًا محليًا متوافقًا على الهاتف',
          'Optional — requires a compatible offline model')),
        children:[
          Padding(padding:const EdgeInsets.all(12),child:Column(
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text(UiLanguage.t(
                'النموذج المحلي: لا تُرسل بياناتك إلى أي خادم. يمكن استيراد نموذج GGUF من الهاتف.',
                'Local model: no data leaves the device. Import a GGUF model from your phone.')),
              OutlinedButton.icon(onPressed:generating?null:chooseModel,
                icon:const Icon(Icons.folder_open),
                label:Text(UiLanguage.t('استيراد نموذج ذكاء اصطناعي','Import AI model'))),
              Text(modelReady?UiLanguage.t('جاهز: $modelName','Ready: $modelName'):
                UiLanguage.t('النموذج غير مجهز','Model not configured')),
              FilledButton.icon(onPressed:generating||!modelReady?null:rewriteLocally,
                icon:const Icon(Icons.auto_fix_high),
                label:Text(UiLanguage.t('إعادة صياغة النص','Rewrite text'))),
              if(generating)const LinearProgressIndicator(),
            ])),
          ),
        ],
      )),
      const SizedBox(height:12),
      if(error.isNotEmpty)Text(error,
        style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(result.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          SelectableText(result),
          const SizedBox(height:8),
          FilledButton(onPressed:(){
            widget.onResult(result);
            Navigator.pop(context);
          },child:Text(UiLanguage.t('إرسال النتيجة إلى المترجم','Send result to translator'))),
        ]))),
    ]),
  );
}
