import 'package:flutter/material.dart';
import 'offline_writing_tools.dart';

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
  @override void dispose(){text.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('أدوات النص المحلية')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('كل الأدوات في هذه الصفحة تعمل على الهاتف دون خادم أو API. '
        'التلخيص استخراجي؛ والتنسيق ليس تدقيقًا لغويًا بنموذج ذكاء اصطناعي.'),
      const SizedBox(height:16),
      TextField(controller:text,maxLines:8,minLines:4,
        decoration:const InputDecoration(labelText:'النص',
          border:OutlineInputBorder())),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        FilledButton.icon(onPressed:()=>runOffline(true),
          icon:const Icon(Icons.short_text),label:const Text('تلخيص محلي')),
        OutlinedButton.icon(onPressed:()=>runOffline(false),
          icon:const Icon(Icons.format_align_left),label:const Text('تنسيق النص')),
      ]),
      const SizedBox(height:12),
      const Text('استخراج النص العربي من الصور، وتفريغ التسجيلات، '
        'وإعادة الصياغة بنموذج محلي تحتاج محركات تعمل على Android '
        'وستُتاح بعد دمجها والتحقق منها. لا توجد خدمة سحابية مخفية.'),
      if(error.isNotEmpty)Text(error,
        style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(result.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          SelectableText(result),
          const SizedBox(height:8),
          FilledButton(onPressed:(){
            widget.onResult(result);
            Navigator.pop(context);
          },child:const Text('إرسال النتيجة إلى المترجم')),
        ]))),
    ]),
  );
}
