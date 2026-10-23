import 'ui_language.dart';
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
  String status='idle';
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
    setState(() { source = language; recognized = ''; translated = ''; message = ''; status='preparing'; busy = true; });
    try {
      final ready = await speech.initialize(onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() { listening = false; status=recognized.isEmpty?'noSpeech':'ready';
            if (recognized.trim().isEmpty && message.isEmpty) {
              message = 'انتهى الاستماع دون التقاط كلام. تحقق من لغة التعرف الصوتي وحزمته المحلية، أو اكتب النص يدويًا.';
            }
          });
        }
      }, onError: (error) {
        if (mounted) setState(() { message = UiLanguage.t('خطأ التعرف الصوتي: ','Speech recognition error: ')+error.errorMsg; listening = false; status='error'; });
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
      setState(() {listening = true;status='listening';});
      await speech.listen(
        onResult: (event) {
          if (mounted) setState(() { recognized = event.recognizedWords;
            if (recognized.isNotEmpty){ message = '';status='ready';} });
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: selected.localeId,
          onDevice: true,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      if (!speech.isListening && mounted) {
        setState(() { listening = false;status='error';
          if (recognized.isEmpty) message = 'لم يبدأ التعرف الصوتي على هذا الهاتف. راجع إعدادات التعرف دون إنترنت أو أدخل النص يدويًا.';
        });
      }
    } catch (e) {
      if (mounted) setState(() { listening = false;status='error'; message = '$e'; });
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
    appBar: AppBar(title: Text(UiLanguage.t('محادثة صوتية بين شخصين','Two-person voice conversation'))),
    body: Directionality(textDirection:UiLanguage.arabic?TextDirection.rtl:TextDirection.ltr,child:ListView(padding: const EdgeInsets.all(16), children: [
      Text(UiLanguage.t('التعرف على الصوت محلي فقط. قد تحتاج تثبيت حزم التعرف الصوتي العربية والإنجليزية على جهازك أولًا. لن نستخدم التعرف السحابي كبديل.','Voice recognition works offline only. Install Arabic and English offline speech recognition languages on your device if necessary. Cloud recognition is not used.')),
      const SizedBox(height: 16),
      Card(color:Theme.of(context).colorScheme.primaryContainer,child:Padding(
        padding:const EdgeInsets.all(12),child:Row(children:[
          Icon(status=='listening'?Icons.mic:status=='error'||status=='noSpeech'?Icons.warning_amber:Icons.info_outline),
          const SizedBox(width:10),
          Expanded(child:Text(status=='listening'?UiLanguage.t('الميكروفون يستمع الآن','Listening now')
            :status=='preparing'?UiLanguage.t('جارٍ تجهيز الميكروفون...','Preparing microphone...')
            :status=='error'||status=='noSpeech'?UiLanguage.t('لم يُلتقط كلام — راجع الرسالة أدناه','No speech captured — see details below')
            :recognized.isNotEmpty?UiLanguage.t('تم التقاط الكلام','Speech captured')
            :UiLanguage.t('اختر المتحدث وابدأ الكلام','Choose a speaker and start talking'))),
        ]))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: FilledButton.icon(
          onPressed: busy ? null : () => capture('ar'),
          icon: const Icon(Icons.mic), label: Text(UiLanguage.t('المتحدث بالعربية','Arabic speaker')))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton.icon(
          onPressed: busy ? null : () => capture('en'),
          icon: const Icon(Icons.mic), label: Text(UiLanguage.t('English speaker','English speaker')))),
      ]),
      if (listening) ...[
        Text(UiLanguage.t('الميكروفون يعمل — يمكنك إنهاء الاستماع الآن','Microphone active — stop listening when done')),
        OutlinedButton.icon(onPressed: () async {
          await speech.stop();
          if (mounted) setState(() => listening = false);
        },icon:const Icon(Icons.stop_circle_outlined),label:Text(UiLanguage.t('إيقاف الاستماع','Stop listening'))),
      ],
      const SizedBox(height: 16),
      Text(UiLanguage.t('الكلام المسموع:','Recognized speech:'), style: Theme.of(context).textTheme.titleMedium),
      SelectableText(recognized.isEmpty ? '—' : recognized),
      if (recognized.isNotEmpty) TextButton.icon(
        onPressed:()=>Clipboard.setData(ClipboardData(text:recognized)),
        icon:const Icon(Icons.copy),label:Text(UiLanguage.t('نسخ الكلام','Copy speech'))),
      const SizedBox(height: 12),
      TextField(controller: manual, maxLines: 2,
        decoration: InputDecoration(labelText: UiLanguage.t('إدخال النص يدويًا عند تعذر التعرف الصوتي','Type text if speech recognition is unavailable'),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(tooltip:UiLanguage.t('استخدام النص المكتوب','Use typed text'),
            onPressed: () => setState(() { recognized = manual.text.trim(); message = ''; }),
            icon: const Icon(Icons.check_circle_outline))),
        onSubmitted: (value) => setState(() { recognized=value.trim(); message=''; })),
      const SizedBox(height: 12),
      FilledButton(onPressed: busy || recognized.trim().isEmpty ? null : translateCaptured,
        child: Text(UiLanguage.t('ترجمة ونطق','Translate and speak'))),
      const SizedBox(height: 16),
      Text(UiLanguage.t('الترجمة:','Translation:'), style: Theme.of(context).textTheme.titleMedium),
      SelectableText(translated.isEmpty ? '—' : translated),
      if (translated.isNotEmpty) Wrap(children:[
        TextButton.icon(onPressed:()=>Clipboard.setData(ClipboardData(text:translated)),
          icon:const Icon(Icons.copy),label:Text(UiLanguage.t('نسخ الترجمة','Copy translation'))),
        TextButton.icon(onPressed:() async {
          await tts.setLanguage(target=='ar'?'ar':'en-US');
          await tts.speak(translated);
        },icon:const Icon(Icons.volume_up),label:Text(UiLanguage.t('إعادة النطق','Speak again'))),
      ]),
      if(message.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(message,style:TextStyle(color:Theme.of(context).colorScheme.error)),
          Text(UiLanguage.t('تحقق من إذن الميكروفون، وتثبيت حزمة التعرف المحلية، ثم جرّب مجددًا.','Check microphone permission and offline speech packs, then retry.')),
          TextButton.icon(onPressed:busy?null:()=>capture(source),
            icon:const Icon(Icons.refresh),label:Text(UiLanguage.t('إعادة المحاولة','Retry'))),
        ]))),
    ])),
  );
}
