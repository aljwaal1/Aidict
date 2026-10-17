import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'translation_policy.dart';
import 'vocabulary_data.dart';
import 'learning_page.dart';
import 'voice_conversation_page.dart';
import 'document_text_reader.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const AidictApp()); }

const languageNames = <String, String>{
  'ar': 'العربية', 'en': 'English', 'sv': 'Svenska',
  'fr': 'Français', 'de': 'Deutsch', 'es': 'Español',
  'it': 'Italiano', 'tr': 'Türkçe', 'pt': 'Português'
};

class AidictApp extends StatefulWidget {
  const AidictApp({super.key});
  @override State<AidictApp> createState() => _AidictAppState();
}

class _AidictAppState extends State<AidictApp> {
  bool dark = false;
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Aidict', debugShowCheckedModeBanner: false,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xff236be4)),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xff236be4)),
    home: Directionality(textDirection: TextDirection.rtl, child: TranslationPage(
      onToggleTheme: () => setState(() => dark = !dark), dark: dark)),
  );
}

class TranslationPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool dark;
  const TranslationPage({super.key, required this.onToggleTheme, required this.dark});
  @override State<TranslationPage> createState() => _TranslationPageState();
}

class _TranslationPageState extends State<TranslationPage> {
  final input = TextEditingController();
  final dictionaryInput = TextEditingController();
  String dictionaryAnswer = '';
  final manager = OnDeviceTranslatorModelManager();
  bool offline = true, busy = false;
  String source = 'ar', target = 'en', result = '', status = '';
  List<String> history = [], favorites = [];

  @override void initState() { super.initState(); _restore(); }
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      history = prefs.getStringList('translations') ?? [];
      favorites = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('translations', history);
    await prefs.setStringList('favorites', favorites);
  }

  void _message(String text) {
    if (!mounted) return;
    setState(() => status = text);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _downloadModels() async {
    if (busy) return;
    setState(() { busy = true; status = 'جارٍ تنزيل نموذجي العربية والإنجليزية'; });
    try {
      for (final code in ['ar', 'en']) {
        final language = code == 'ar' ? TranslateLanguage.arabic : TranslateLanguage.english;
        final present = await manager.isModelDownloaded(language.bcpCode);
        if (!present) {
          final ok = await manager.downloadModel(language.bcpCode);
          if (!ok) throw StateError('فشل تحميل نموذج $code');
        }
      }
      _message('النموذجان جاهزان للترجمة دون إنترنت');
    } catch (e) {
      _message('تعذّر تنزيل النماذج. تحقق من اتصال الإنترنت والمساحة: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String> _translateOffline(String text) async {
    if (!TranslationPolicy.allowsOfflinePair(source, target)) {
      throw StateError('الترجمة المحلية تدعم العربية والإنجليزية فقط');
    }
    final from = source == 'ar' ? TranslateLanguage.arabic : TranslateLanguage.english;
    final to = target == 'ar' ? TranslateLanguage.arabic : TranslateLanguage.english;
    if (!await manager.isModelDownloaded(from.bcpCode) ||
        !await manager.isModelDownloaded(to.bcpCode)) {
      throw StateError('نزّل نموذجي العربية والإنجليزية أولًا');
    }
    final translator = OnDeviceTranslator(sourceLanguage: from, targetLanguage: to);
    try { return await translator.translateText(text); }
    finally { await translator.close(); }
  }

  Future<String> _translateOnline(String text, {String? fromCode, String? toCode}) async {
    if (text.length > 450) throw StateError('الترجمة المتصلة التجريبية محدودة بـ450 حرفًا');
    final uri = Uri.https('api.mymemory.translated.net', '/get',
        {'q': text, 'langpair': '${fromCode ?? source}|${toCode ?? target}'});
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('خدمة الترجمة غير متاحة');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final value = (data['responseData'] as Map?)?['translatedText']?.toString() ?? '';
    final responseStatus = data['responseStatus'];
    if (value.isEmpty || (responseStatus is num && responseStatus >= 400)) {
      throw StateError('لم تُرجع الخدمة ترجمة صالحة');
    }
    return value.replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&amp;', '&');
  }

  Future<void> _recognizeImage(ImageSource origin) async {
    if (busy) return;
    try {
      final selected = await ImagePicker().pickImage(source: origin);
      if (selected == null) return;
      setState(() => busy = true);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognized = await recognizer.processImage(InputImage.fromFilePath(selected.path));
        if (!mounted) return;
        if (recognized.text.trim().isEmpty) {
          _message('لم يُستخرج نص. التعرف العربي يحتاج محرك OCR إضافيًا.');
        } else {
          setState(() { input.text = recognized.text; result = ''; });
          _message('تم استخراج النص. راجعه ثم اضغط ترجمة.');
        }
      } finally { await recognizer.close(); }
    } catch (e) {
      _message('تعذر قراءة الصورة: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _importDocument() async {
    if (busy) return;
    setState(() { busy = true; status = ''; });
    try {
      final extracted = await DocumentTextReader.selectAndExtract();
      if (extracted == null || !mounted) return;
      setState(() { input.text = extracted; result = ''; });
      _message('تم استخراج النص. خدمة الترجمة الحالية تقبل نصوصًا قصيرة فقط؛ اختر مقطعًا للترجمة.');
    } catch (e) {
      _message('تعذر استخراج المستند: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _translate() async {
    final value = input.text.trim();
    if (busy || value.isEmpty) return;
    setState(() { busy = true; status = ''; });
    try {
      final translated = offline
          ? await _translateOffline(value)
          : await _translateOnline(value);
      if (!mounted) return;
      setState(() {
        result = translated;
        history.insert(0, '$source → $target | $value | $translated');
        if (history.length > 100) history = history.take(100).toList();
      });
      await _save();
    } catch (e) { _message(e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _favorite() async {
    if (result.isEmpty) return;
    final value = '$source → $target | ${input.text} | $result';
    setState(() {
      if (favorites.contains(value)) { favorites.remove(value); }
      else { favorites.insert(0, value); }
    });
    await _save();
  }

  void _changeMode(bool useOffline) {
    setState(() {
      offline = useOffline;
      if (offline && !TranslationPolicy.allowsOfflinePair(source, target)) {
        source = 'ar'; target = 'en';
      }
      result = ''; status = '';
    });
  }

  Widget _languageSelector(bool isSource) {
    final options = offline ? const ['ar', 'en'] : languageNames.keys.toList();
    final selected = isSource ? source : target;
    return Expanded(child: DropdownButtonFormField<String>(
      value: selected, isExpanded: true,
      decoration: InputDecoration(border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14))),
      items: options.map((code) => DropdownMenuItem(
          value: code, child: Text(languageNames[code] ?? code))).toList(),
      onChanged: (code) {
        if (code == null) return;
        setState(() {
          if (isSource) { source = code; if (offline) target = code == 'ar' ? 'en' : 'ar'; }
          else { target = code; if (offline) source = code == 'ar' ? 'en' : 'ar'; }
          result = '';
        });
      },
    ));
  }

  @override void dispose() { input.dispose(); dictionaryInput.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aidict • AI Translator'), actions: [
      IconButton(onPressed: widget.onToggleTheme,
        icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode)),
    ]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('المترجم الذكي', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      const Text('ترجمة محلية بين العربية والإنجليزية، وبقية اللغات عبر الإنترنت'),
      const SizedBox(height: 20),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, icon: Icon(Icons.wifi_off), label: Text('دون إنترنت')),
          ButtonSegment(value: false, icon: Icon(Icons.wifi), label: Text('عبر الإنترنت')),
        ],
        selected: {offline}, onSelectionChanged: (s) => _changeMode(s.first),
      ),
      if (offline) Padding(padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(onPressed: busy ? null : _downloadModels,
          icon: const Icon(Icons.download), label: const Text('تنزيل نماذج العربية والإنجليزية'))),
      const SizedBox(height: 16),
      Row(children: [
        _languageSelector(true),
        IconButton(icon: const Icon(Icons.swap_horiz), onPressed: () {
          setState(() { final previous = source; source = target; target = previous; result = ''; });
        }),
        _languageSelector(false),
      ]),
      const SizedBox(height: 14),
      TextField(controller: input, maxLines: 5, minLines: 3,
        decoration: const InputDecoration(labelText: 'النص المراد ترجمته',
          border: OutlineInputBorder())),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(onPressed: busy ? null : _importDocument,
          icon: const Icon(Icons.description_outlined),
          label: const Text('استيراد PDF / Word / TXT')),
        OutlinedButton.icon(onPressed: busy ? null : () => _recognizeImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_outlined), label: const Text('التقاط نص')),
        OutlinedButton.icon(onPressed: busy ? null : () => _recognizeImage(ImageSource.gallery),
          icon: const Icon(Icons.image_outlined), label: const Text('صورة أو لقطة شاشة')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: busy ? null : _translate,
          icon: const Icon(Icons.translate), label: const Text('ترجمة'))),
        IconButton(tooltip: 'لصق', icon: const Icon(Icons.content_paste), onPressed: () async {
          final value = await Clipboard.getData(Clipboard.kTextPlain);
          if (value?.text != null) input.text = value!.text!;
        }),
      ]),
      if (busy) const LinearProgressIndicator(),
      if (status.isNotEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(status)),
      if (result.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('الترجمة', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SelectableText(result),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(tooltip: 'نسخ الترجمة', onPressed: () => Clipboard.setData(ClipboardData(text: result)),
              icon: const Icon(Icons.copy)),
            IconButton(tooltip: 'المفضلة', onPressed: _favorite, icon: const Icon(Icons.favorite_border)),
          ]),
        ]))),
      const SizedBox(height: 16),
      ExpansionTile(title: Text('السجل (${history.length})'), children: [
        for (final item in history.take(30))
          ListTile(title: Text(item, maxLines: 3, overflow: TextOverflow.ellipsis)),
        TextButton(onPressed: () async {
          setState(() => history.clear());
          await _save();
        }, child: const Text('حذف السجل')),
      ]),
      ExpansionTile(title: Text('المفضلة (${favorites.length})'), children: [
        for (final item in favorites)
          ListTile(title: Text(item, maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
              setState(() => favorites.remove(item)); await _save();
            })),
      ]),
      const SizedBox(height: 20),
      ExpansionTile(title: const Text('القاموس العربي–الإنجليزي'), children: [
        TextField(controller: dictionaryInput, decoration: const InputDecoration(
          hintText: 'اكتب كلمة عربية أو إنجليزية', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => setState(() {
          dictionaryAnswer = lookupWord(dictionaryInput.text) ??
            lookupWord(dictionaryInput.text, arabicToEnglish: true) ??
            'الكلمة غير موجودة في القاموس المحلي المصغر';
        }), child: const Text('بحث')),
        if (dictionaryAnswer.isNotEmpty) SelectableText(dictionaryAnswer),
      ]),
      ListTile(title: const Text('تعلم الكلمات والاختبارات'),
        subtitle: const Text('20 كلمة أساسية واختبار إجابات'),
        trailing: const Icon(Icons.chevron_left), onTap: () =>
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const LearningPage()))),
      const SizedBox(height: 25),
      const Text('الكاميرا المباشرة مع ترجمة فوق المشهد، والتسجيلات الصوتية والمستندات والتصحيح الذكي قيد التطوير. OCR الحالي للنص اللاتيني فقط.',
        textAlign: TextAlign.center),
    ]),
  );
}
