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
    appBar:AppBar(title:const Text('تفريغ التسجيلات محليًا')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('اختر ملفات نموذج Whisper ONNX المتوافقة: encoder وdecoder وtokens.txt، ثم ملف WAV أحادي القناة 16 kHz. المعالجة بالكامل على الهاتف، ولا يتم رفع الصوت أو النص لأي خادم.'),
      const SizedBox(height:12),
      OutlinedButton(onPressed:busy?null:() async {
        final path=await choose('encoder.onnx',['onnx']);
        if(path!=null)setState(()=>encoder=path);
      },child:Text(encoder==null?'اختيار encoder.onnx':'تم اختيار Encoder')),
      OutlinedButton(onPressed:busy?null:() async {
        final path=await choose('decoder.onnx',['onnx']);
        if(path!=null)setState(()=>decoder=path);
      },child:Text(decoder==null?'اختيار decoder.onnx':'تم اختيار Decoder')),
      OutlinedButton(onPressed:busy?null:() async {
        final path=await choose('tokens.txt',['txt']);
        if(path!=null)setState(()=>tokens=path);
      },child:Text(tokens==null?'اختيار tokens.txt':'تم اختيار Tokens')),
      OutlinedButton(onPressed:busy?null:() async {
        final path=await choose('WAV',['wav']);
        if(path!=null)setState(()=>wav=path);
      },child:Text(wav==null?'اختيار WAV للتفريغ':'تم اختيار WAV')),
      FilledButton.icon(
        onPressed:busy||encoder==null||decoder==null||tokens==null||wav==null?null:transcribe,
        icon:const Icon(Icons.record_voice_over),
        label:const Text('تفريغ الصوت على الجهاز')),
      if(busy)const LinearProgressIndicator(),
      if(error.isNotEmpty)Text(error,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(output.isNotEmpty)SelectableText(output),
    ]),
  );
}
