import 'package:flutter/material.dart';
import 'vocabulary_data.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});
  @override State<LearningPage> createState() => _LearningPageState();
}
class _LearningPageState extends State<LearningPage> {
  int index = 0;
  int correct = 0;
  bool answered = false;
  String? selected;
  final entries = vocabulary.entries.toList();
  // Options are built once for each question to avoid changing after setState.
  late List<String> currentOptions = _optionsFor(index);
  List<String> _optionsFor(int i) {
    final correct = entries[i].value;
    final other = entries.where((e) => e.key != entries[i].key)
      .skip((i * 3) % (entries.length - 4)).take(3).map((e) => e.value).toList();
    return [correct, ...other]..sort((a,b) => (a.length + i * 7) % 11 - ((b.length + i * 7) % 11));
  }
  @override Widget build(BuildContext context) {
    final done = index >= entries.length;
    return Scaffold(appBar: AppBar(title: const Text('تعلم المفردات')),
      body: Padding(padding: const EdgeInsets.all(20), child: done ?
        Column(children: [
          Text('النتيجة: $correct من ${entries.length}'),
          FilledButton(onPressed: () => setState(() {
            index=0; correct=0; answered=false; selected=null; currentOptions=_optionsFor(0);
          }),child: const Text('إعادة الاختبار'))
        ]) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LinearProgressIndicator(value: index/entries.length),
          const SizedBox(height: 30),
          Text('ما معنى: ${entries[index].key}؟',style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          for (final option in currentOptions) Padding(padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(onPressed: answered ? null : () => setState(() {
              answered=true; selected=option;
              if(option==entries[index].value) correct++;
            }), child: Text(option))),
          if(answered) ...[
            Text(selected==entries[index].value ? 'إجابة صحيحة!' :
              'الإجابة الصحيحة: ${entries[index].value}'),
            FilledButton(onPressed: () => setState(() {
              index++; answered=false; selected=null;
              if(index<entries.length) currentOptions=_optionsFor(index);
            }), child: const Text('التالي'))
          ],
        ])));
  }
}
