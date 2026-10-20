import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'extra_features.dart';

/// Voice capture follows device speech service availability; offline recognition
/// is not guaranteed, and no recording is stored by this screen.
class VoiceConversationPage extends StatefulWidget {
  final Future<String> Function(String text, String source, String target) translate;
  const VoiceConversationPage({super.key, required this.translate});
  @override State<VoiceConversationPage> createState() => _VoiceConversationPageState();
}

class _VoiceConversationPageState extends State<VoiceConversationPage> {
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  bool busy = false;
  bool listening = false;
  String recognized = '';
  String translated = '';
  String message = '';
  String source = 'ar';
  String get target => source == 'ar' ? 'en' : 'ar';

  Future<void> capture(String language) async {
    if (busy) return;
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    setState(() { source = language; recognized = ''; translated = ''; message = ''; busy = true; });
    try {
      final ready = await speech.initialize(onError: (error) {
        if (mounted) setState(() { message = error.errorMsg; listening = false; });
      });
      if (!ready) throw StateError('خدمة التعرف على الصوت غير متاحة على الجهاز');
      if (!mounted) return;
      setState(() => listening = true);
      await speech.listen(
        onResult: (event) {
          if (mounted) setState(() => recognized = event.recognizedWords);
        },
        options: stt.SpeechListenOptions(
          localeId: language == 'ar' ? 'ar' : 'en_US',
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> translateCaptured() async {
    if (recognized.trim().isEmpty || busy) return;
    await speech.stop();
    setState(() { listening = false; busy = true; message = ''; });
    try {
      final output = await widget.translate(recognized, source, target);
      if (!mounted) return;
      setState(() => translated = output);
      await tts.setLanguage(target == 'ar' ? 'ar' : 'en-US');
      await tts.speak(output);
      await SavedTranslations.add('$source → $target | $recognized | $output');
    } catch (e) {
      if (mounted) setState(() => message = 'تعذرت الترجمة أو قراءة الصوت: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override void dispose() {
    speech.stop();
    tts.stop();
    super.dispose();
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('محادثة صوتية بين شخصين')),
    body: Directionality(textDirection:TextDirection.rtl,child:ListView(padding: const EdgeInsets.all(16), children: [
      const Text('التعرف على الصوت قد يحتاج الإنترنت بحسب خدمات الجهاز. اضغط على المتحدث ثم ترجمة ونطق.'),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: FilledButton.icon(
          onPressed: busy ? null : () => capture('ar'),
          icon: const Icon(Icons.mic), label: const Text('المتحدث بالعربية'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton.icon(
          onPressed: busy ? null : () => capture('en'),
          icon: const Icon(Icons.mic), label: const Text('English speaker'))),
      ]),
      if (listening) ...[
        const Text('الميكروفون يعمل — يمكنك إنهاء الاستماع الآن'),
        OutlinedButton.icon(onPressed: () async {
          await speech.stop();
          if (mounted) setState(() => listening = false);
        },icon:const Icon(Icons.stop_circle_outlined),label:const Text('إيقاف الاستماع')),
      ],
      const SizedBox(height: 16),
      Text('الكلام المسموع:', style: Theme.of(context).textTheme.titleMedium),
      SelectableText(recognized.isEmpty ? '—' : recognized),
      if (recognized.isNotEmpty) TextButton.icon(
        onPressed:()=>Clipboard.setData(ClipboardData(text:recognized)),
        icon:const Icon(Icons.copy),label:const Text('نسخ الكلام')),
      const SizedBox(height: 12),
      FilledButton(onPressed: busy || recognized.trim().isEmpty ? null : translateCaptured,
        child: const Text('ترجمة ونطق')),
      const SizedBox(height: 16),
      Text('الترجمة:', style: Theme.of(context).textTheme.titleMedium),
      SelectableText(translated.isEmpty ? '—' : translated),
      if (translated.isNotEmpty) Wrap(children:[
        TextButton.icon(onPressed:()=>Clipboard.setData(ClipboardData(text:translated)),
          icon:const Icon(Icons.copy),label:const Text('نسخ الترجمة')),
        TextButton.icon(onPressed:() async {
          await tts.setLanguage(target=='ar'?'ar':'en-US');
          await tts.speak(translated);
        },icon:const Icon(Icons.volume_up),label:const Text('إعادة النطق')),
      ]),
      if (message.isNotEmpty) Text(message),
    ])),
  );
}
