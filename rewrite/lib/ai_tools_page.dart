import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_backend.dart';

/// User-owned HTTPS processing endpoint; no provider tokens are bundled.
class AiToolsPage extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onResult;
  const AiToolsPage({super.key,required this.initialText,required this.onResult});
  @override State<AiToolsPage> createState()=>_AiToolsPageState();
}
class _AiToolsPageState extends State<AiToolsPage> {
  static const endpointKey='aidict.backend.endpoint';
  final endpoint=TextEditingController();
  final text=TextEditingController();
  bool busy=false;
  String result='', error='';
  @override void initState(){
    super.initState();
    text.text=widget.initialText;
    _loadEndpoint();
  }
  Future<void> _loadEndpoint() async {
    final prefs=await SharedPreferences.getInstance();
    if(mounted)endpoint.text=prefs.getString(endpointKey)??'';
  }
  Future<void> _saveEndpoint() async {
    final uri=AiBackend.validate(endpoint.text);
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(endpointKey,uri.toString());
  }
  Future<void> runOcr(bool camera) async {
    if(busy)return;
    setState((){busy=true;error='';result='';});
    try {
      await _saveEndpoint();
      final extracted=await AiBackend.recognizeImage(endpoint:endpoint.text,camera:camera);
      if(mounted)setState(()=>result=extracted??'لم تُختر صورة');
    } catch(e) {
      if(mounted)setState(()=>error='$e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  Future<void> run(String task) async {
    if(busy)return;
    setState((){busy=true;error='';result='';});
    try {
      await _saveEndpoint();
      final response=task=='transcribe'
        ? await AiBackend.transcribeAudio(endpoint:endpoint.text)
        : await AiBackend.process(endpoint:endpoint.text,task:task,text:text.text);
      if(mounted)setState(()=>result=response??'لم يُختر تسجيل');
    } catch(e) {
      if(mounted)setState(()=>error='$e');
    } finally {if(mounted)setState(()=>busy=false);}
  }
  @override void dispose(){endpoint.dispose();text.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('المستندات والصوت والذكاء الاصطناعي')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('الخدمات التالية تحتاج خادم معالجة HTTPS تملكه أو تثق به. '
        'لن تُرسل أي بيانات حتى تضغط زر المعالجة. لا تدخل مفتاح API هنا؛ '
        'المفاتيح تُحفظ في الخادم فقط.'),
      const SizedBox(height:12),
      TextField(controller:endpoint,keyboardType:TextInputType.url,
        decoration:const InputDecoration(
          labelText:'رابط خدمة المعالجة HTTPS',
          hintText:'https://example.com/v1/aidict',
          border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:text,maxLines:6,minLines:3,
        decoration:const InputDecoration(labelText:'النص',border:OutlineInputBorder())),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        FilledButton.icon(onPressed:busy?null:()=>run('rewrite'),
          icon:const Icon(Icons.edit_note),label:const Text('إعادة صياغة')),
        FilledButton.icon(onPressed:busy?null:()=>run('proofread'),
          icon:const Icon(Icons.spellcheck),label:const Text('تدقيق')),
        FilledButton.icon(onPressed:busy?null:()=>run('summarize'),
          icon:const Icon(Icons.summarize),label:const Text('تلخيص')),
        OutlinedButton.icon(onPressed:busy?null:()=>runOcr(false),
          icon:const Icon(Icons.image_search),label:const Text('OCR عربي من صورة')),
        OutlinedButton.icon(onPressed:busy?null:()=>runOcr(true),
          icon:const Icon(Icons.camera_alt),label:const Text('OCR عربي بالكاميرا')),
        OutlinedButton.icon(onPressed:busy?null:()=>run('transcribe'),
          icon:const Icon(Icons.audio_file),label:const Text('تفريغ ملف صوتي')),
      ]),
      const SizedBox(height:12),
      const Text('عقد الخدمة: POST JSON للكتابة أو multipart/form-data '
        'بحقل audio للتفريغ أو image للتعرف على النص العربي؛ النتيجة JSON باسم result.'),
      if(busy)const LinearProgressIndicator(),
      if(error.isNotEmpty)Text(error,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(result.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          SelectableText(result),
          FilledButton(onPressed:(){
            widget.onResult(result);
            Navigator.pop(context);
          },child:const Text('إرسال النتيجة إلى المترجم')),
        ]))),
    ]),
  );
}
