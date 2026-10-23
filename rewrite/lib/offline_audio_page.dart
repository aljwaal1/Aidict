import 'ui_language.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Whisper ONNX inference is entirely on-device; no audio leaves the phone.
/// Requires user-provided compatible encoder/decoder/tokens model files.
class OfflineAudioPage extends StatefulWidget {
  const OfflineAudioPage({super.key});
  @override
  State<OfflineAudioPage> createState() => _OfflineAudioPageState();
}

class _OfflineAudioPageState extends State<OfflineAudioPage> {
  String? encoder,decoder,tokens,wav;
  String output='',error='';
  bool busy=false;
  Future<String?> choose(String name,List<String> extensions) async {
    final picked=await openFile(acceptedTypeGroups:[
      XTypeGroup(label:name,extensions:extensions),
    ]);
    if(picked==null)return null;
    final length=await picked.length();
    final limit=name=='WAV' ? 100*1024*1024 : 3*1024*1024*1024;
    if(length==0 || length>limit) {
      throw FormatException('حجم الملف غير مدعوم: الحد المسموح ${name=='WAV'?'100 MB':'3 GB'}');
    }
    final dir=await getApplicationSupportDirectory();
    final folder=Directory('${dir.path}/whisper_models');
    await folder.create(recursive:true);
    final dest=File('${folder.path}/${name=='WAV'?'input.wav':name}');
    final stage=File('${dest.path}.part');
    try {
      await picked.saveTo(stage.path);
      if(await stage.length()!=length)throw const FormatException('نسخ الملف غير مكتمل');
      if(await dest.exists())await dest.delete();
      await stage.rename(dest.path);
      return dest.path;
    } finally {
      if(await stage.exists())await stage.delete();
    }
  }

  Future<void> transcribe() async {
    if(encoder==null||decoder==null||tokens==null||wav==null||busy)return;
    setState((){busy=true;output='';error='';});
    sherpa.OfflineRecognizer? recognizer;
    sherpa.OfflineStream? stream;
    try {
      await sherpa.initBindingsAsync();
      recognizer=sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
        model:sherpa.OfflineModelConfig(
          whisper:sherpa.OfflineWhisperModelConfig(
            encoder:encoder!,decoder:decoder!),
          tokens:tokens!,modelType:'whisper',numThreads:2,
        ),
      ));
      final wave=sherpa.readWave(wav!);
      if(wave.sampleRate!=16000){
        throw const FormatException('استخدم ملف WAV بمعدل 16000 Hz؛ التحويل الصوتي لم يُضف بعد');
      }
      stream=recognizer.createStream();
      stream.acceptWaveform(samples:wave.samples,sampleRate:wave.sampleRate);
      recognizer.decode(stream);
      final recognized=recognizer.getResult(stream).text.trim();
      if(mounted)setState(()=>output=recognized.isEmpty?'لم يتم اكتشاف كلام واضح':recognized);
    }catch(e){
      if(mounted)setState(()=>error='تعذر تفريغ التسجيل محليًا: $e');
    }finally{
      stream?.free();
      recognizer?.free();
      if(mounted)setState(()=>busy=false);
    }
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(UiLanguage.t('تفريغ التسجيلات محليًا','Offline audio transcription'))),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Card(color:Theme.of(context).colorScheme.primaryContainer,
        child:Padding(padding:const EdgeInsets.all(16),
          child:Text(UiLanguage.t(
            'حوّل كلام التسجيلات إلى نص على هاتفك. حاليًا ندعم ملفات WAV أحادية القناة 16 kHz بعد تجهيز نموذج Whisper محلي.',
            'Turn recorded speech into text offline. Currently supports 16 kHz mono WAV after configuring a local Whisper model.')))),
      const SizedBox(height:12),
      Text(UiLanguage.t('١. اختر التسجيل','1. Choose recording'),
        style:Theme.of(context).textTheme.titleMedium),
      OutlinedButton(onPressed:busy?null:() async {
        try {
          final path=await choose('WAV',['wav']);
          if(path!=null && mounted)setState(()=>wav=path);
        }catch(e){if(mounted)setState(()=>error='تعذر فتح الملف: $e');}
      },child:Text(wav==null?UiLanguage.t('اختيار WAV للتفريغ','Select WAV to transcribe'):UiLanguage.t('تم اختيار WAV','WAV selected'))),
      const SizedBox(height:12),
      Card(child:ExpansionTile(
        leading:Icon(encoder!=null&&decoder!=null&&tokens!=null
          ?Icons.check_circle:Icons.settings_outlined,
          color:encoder!=null&&decoder!=null&&tokens!=null?Colors.green:null),
        title:Text(UiLanguage.t('٢. إعداد نموذج التعرف الصوتي','2. Configure speech model')),
        subtitle:Text(encoder!=null&&decoder!=null&&tokens!=null
          ?UiLanguage.t('النموذج جاهز','Model ready')
          :UiLanguage.t('مطلوب لأول مرة — 3 ملفات Whisper','First-time setup — 3 Whisper files')),
        children:[
          Padding(padding:const EdgeInsets.all(12),child:Text(UiLanguage.t(
            'هذه ملفات تقنية لنموذج Whisper ONNX. اخترها من وحدة التخزين. لا يمكن تنزيلها تلقائيًا في هذا الإصدار.',
            'These are Whisper ONNX model files. Import them from storage. Automatic model downloads are not available yet.'))),
      OutlinedButton(onPressed:busy?null:() async {
        try {
          final path=await choose('encoder.onnx',['onnx']);
          if(path!=null && mounted)setState(()=>encoder=path);
        }catch(e){if(mounted)setState(()=>error='تعذر فتح الملف: $e');}
      },child:Text(encoder==null?UiLanguage.t('اختيار encoder.onnx','Select encoder.onnx'):UiLanguage.t('تم اختيار Encoder','Encoder selected'))),
      OutlinedButton(onPressed:busy?null:() async {
        try {
          final path=await choose('decoder.onnx',['onnx']);
          if(path!=null && mounted)setState(()=>decoder=path);
        }catch(e){if(mounted)setState(()=>error='تعذر فتح الملف: $e');}
      },child:Text(decoder==null?UiLanguage.t('اختيار decoder.onnx','Select decoder.onnx'):UiLanguage.t('تم اختيار Decoder','Decoder selected'))),
      OutlinedButton(onPressed:busy?null:() async {
        try {
          final path=await choose('tokens.txt',['txt']);
          if(path!=null && mounted)setState(()=>tokens=path);
        }catch(e){if(mounted)setState(()=>error='تعذر فتح الملف: $e');}
      },child:Text(tokens==null?UiLanguage.t('اختيار tokens.txt','Select tokens.txt'):UiLanguage.t('تم اختيار Tokens','Tokens selected'))),
        ])),
      const SizedBox(height:12),
      Text(UiLanguage.t('٣. تحويل التسجيل','3. Transcribe recording'),
        style:Theme.of(context).textTheme.titleMedium),
      FilledButton.icon(
        onPressed:busy||encoder==null||decoder==null||tokens==null||wav==null?null:transcribe,
        icon:const Icon(Icons.record_voice_over),
        label:Text(UiLanguage.t('تفريغ الصوت على الجهاز','Transcribe audio on device'))),
      if(busy)const LinearProgressIndicator(),
      if(error.isNotEmpty)Text(error,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(output.isNotEmpty)SelectableText(output),
    ]),
  );
}
