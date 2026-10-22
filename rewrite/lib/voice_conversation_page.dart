import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'extra_features.dart';

/// Requests recognition on-device only. Availability depends on installed
/// offline speech packs. No remote speech fallback is permitted.
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
  bool speechReady = false;
  final TextEditingController manual = TextEditingController();
  List<stt.LocaleName> installedLocales = [];
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
      final ready = await speech.initialize(onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() { listening = false;
            if (recognized.trim().isEmpty && message.isEmpty) {
              message = 'انتهى الاستماع دون التقاط كلام. تحقق من لغة التعرف الصوتي وحزمته المحلية، أو اكتب النص يدويًا.';
            }
          });
        }
      }, onError: (error) {
        if (mounted) setState(() { message = error.errorMsg; listening = false; });
      });
      if (!ready) throw StateError('التعرف الصوتي المحلي غير متاح؛ ثبّت حزمة التعرف دون إنترنت من إعدادات الجهاز');
      installedLocales = await speech.locales();
      final prefix = language == 'ar' ? 'ar' : 'en';
      final matches = installedLocales.where((entry) =>
        entry.localeId.toLowerCase().replaceAll('-', '_').startsWith(prefix)).toList();
      if (matches.isEmpty) {
        throw StateError('لغة التعرف الصوتي المطلوبة غير متوفرة على هذا الجهاز: $prefix. يمكنك إدخال النص يدويًا.');
      }
      final selected = matches.firstWhere((entry) =>
        entry.localeId.toLowerCase().replaceAll('-', '_') ==
          (language == 'ar' ? 'ar_sa' : 'en_us'),
        orElse: () => matches.first);
      if (!mounted) return;
      setState(() => listening = true);
      await speech.listen(
        onResult: (event) {
          if (mounted) setState(() { recognized = event.recognizedWords;
            if (recognized.isNotEmpty) message = ''; });
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: selected.localeId,
          onDevice: true,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      if (!speech.isListening && mounted) {
        setState(() { listening = false;
          if (recognized.isEmpty) message = 'لم يبدأ التعرف الصوتي على هذا الهاتف. راجع إعدادات التعرف دون إنترنت أو أدخل النص يدويًا.';
        });
      }
    } catch (e) {
      if (mounted) setState(() { listening = false; message = '$e'; });
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
    manual.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('محادثة صوتية بين شخصين')),
    body: Directionality(textDirection:TextDirection.rtl,child:ListView(padding: const EdgeInsets.all(16), children: [
      const Text('التعرف على الصوت محلي فقط. قد تحتاج تثبيت حزم التعرف الصوتي العربية والإنجليزية على جهازك أولًا. لن نستخدم التعرف السحابي كبديل.'),
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
      TextField(controller: manual, maxLines: 2,
        decoration: InputDecoration(labelText: 'إدخال النص يدويًا عند تعذر التعرف الصوتي',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(tooltip:'استخدام النص المكتوب',
            onPressed: () => setState(() { recognized = manual.text.trim(); message = ''; }),
            icon: const Icon(Icons.check_circle_outline))),
        onSubmitted: (value) => setState(() { recognized=value.trim(); message=''; })),
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
