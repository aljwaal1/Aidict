import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

/// Arabic/English OCR is performed entirely on-device.
/// Source photos and temporary processed images are never uploaded.
class ImageTextReader {
  static Future<String?> selectAndExtract({required bool camera, BuildContext? context}) async {
    final photo=await ImagePicker().pickImage(
      source:camera?ImageSource.camera:ImageSource.gallery,
      // Avoid degrading small text through JPEG compression.
      imageQuality:100,
      requestFullMetadata:true,
    );
    if(photo==null)return null;
    final file=File(photo.path);
    if(await file.length()>24*1024*1024) {
      throw const FormatException('الصورة كبيرة جدًا؛ اختر صورة أصغر من 24 MB');
    }
    final bytes=await file.readAsBytes();
    final decoded=img.decodeImage(bytes);
    if(decoded==null)throw const FormatException('تعذّر قراءة تنسيق الصورة');
    var upright=img.bakeOrientation(decoded);
    if(context!=null && context.mounted){
      final reviewed=await Navigator.of(context).push<img.Image>(
        MaterialPageRoute(builder:(_)=>_ReviewPhotoPage(image:upright)));
      if(reviewed==null)return null;
      upright=reviewed;
    }
    // Limit memory while keeping letters large enough for OCR.
    final ratio=upright.width>upright.height
        ? 2200/upright.width : 2200/upright.height;
    final prepared=ratio<1
        ? img.copyResize(upright,width:(upright.width*ratio).round(),
            height:(upright.height*ratio).round())
        : upright;
    final temp=await getTemporaryDirectory();
    final processed=File('${temp.path}/aidict_camera_${DateTime.now().microsecondsSinceEpoch}.png');
    try {
      // Text can appear on colored paper. Try the original colors first.
      await processed.writeAsBytes(img.encodePng(prepared),flush:true);
      var recognized=await TesseractOcr.extractText(
        processed.path,
        config:const OCRConfig(language:'ara+eng',engine:OCREngine.tesseract),
      );
      if(recognized.trim().isEmpty) {
        // A second, local pass helps text against uneven colors.
        final mono=img.grayscale(prepared);
        await processed.writeAsBytes(img.encodePng(mono),flush:true);
        recognized=await TesseractOcr.extractText(processed.path,
          config:const OCRConfig(language:'ara+eng',engine:OCREngine.tesseract));
      }
      if(recognized.trim().isEmpty) {
        throw const FormatException(
          'لم يظهر نص واضح. قرّب الكاميرا وثبّت الهاتف واجعل الورقة مضاءة دون انعكاس.');
      }
      return recognized.replaceAll(RegExp(r'\r\n?'),'\n')
        .replaceAll(RegExp(r'[ \t]+'),' ').trim();
    } finally {
      if(await processed.exists())await processed.delete();
    }
  }
}

class _ReviewPhotoPage extends StatefulWidget {
  const _ReviewPhotoPage({required this.image});
  final img.Image image;
  @override State<_ReviewPhotoPage> createState()=>_ReviewPhotoPageState();
}

class _ReviewPhotoPageState extends State<_ReviewPhotoPage> {
  late img.Image picture=widget.image;
  Rect? selection;
  Offset? origin;
  Size? displaySize;

  void rotate(){
    setState((){
      picture=img.copyRotate(picture,angle:90);
      selection=null;
    });
  }

  void finish(){
    final area=selection;
    if(area==null || area.width<10 || area.height<10){
      Navigator.pop(context,picture);
      return;
    }
    final w=displaySize;
    if(w==null){Navigator.pop(context,picture);return;}
    final x=(area.left/w.width*picture.width).round().clamp(0,picture.width-1);
    final y=(area.top/w.height*picture.height).round().clamp(0,picture.height-1);
    final cw=(area.width/w.width*picture.width).round().clamp(1,picture.width-x);
    final ch=(area.height/w.height*picture.height).round().clamp(1,picture.height-y);
    Navigator.pop(context,img.copyCrop(picture,x:x,y:y,width:cw,height:ch));
  }

  @override Widget build(BuildContext context){
    final raw=img.encodeJpg(picture,quality:85);
    return Scaffold(
      appBar:AppBar(title:const Text('مراجعة الصورة قبل قراءة النص')),
      body:SafeArea(child:Column(children:[
        const Padding(padding:EdgeInsets.all(12),
          child:Text('اسحب بإصبعك مستطيلاً حول النص لقصّه، أو استخرج النص من الصورة كاملة.')),
        Expanded(child:Center(child:LayoutBuilder(builder:(context,box){
          final aspect=picture.width/picture.height;
          final bounds=Size(box.maxWidth-24,box.maxHeight-16);
          final width=bounds.width/bounds.height>aspect
              ? bounds.height*aspect : bounds.width;
          final height=width/aspect;
          displaySize=Size(width,height);
          return SizedBox(width:width,height:height,child:GestureDetector(
            onPanStart:(d)=>setState((){
              origin=Offset(d.localPosition.dx.clamp(0,width),
                d.localPosition.dy.clamp(0,height));
              selection=null;
            }),
            onPanUpdate:(d){
              if(origin==null)return;
              final end=Offset(d.localPosition.dx.clamp(0,width),
                d.localPosition.dy.clamp(0,height));
              setState(()=>selection=Rect.fromPoints(origin!,end));
            },
            child:Stack(fit:StackFit.expand,children:[
              Image.memory(raw,fit:BoxFit.fill),
              if(selection!=null)Positioned(
                left:selection!.left,top:selection!.top,
                width:selection!.width,height:selection!.height,
                child:IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(
                  color:Colors.blue.withValues(alpha:0.12),
                  border:Border.all(color:Colors.lightBlueAccent,width:3))))),
            ]),
          ));
        }))),
        Padding(padding:const EdgeInsets.all(12),child:Wrap(
          spacing:10,runSpacing:8,alignment:WrapAlignment.center,children:[
            OutlinedButton.icon(onPressed:rotate,
              icon:const Icon(Icons.rotate_right),label:const Text('تدوير 90°')),
            OutlinedButton.icon(onPressed:()=>setState(()=>selection=null),
              icon:const Icon(Icons.crop_free),label:const Text('الصورة كاملة')),
            FilledButton.icon(onPressed:finish,
              icon:const Icon(Icons.document_scanner),label:const Text('استخراج النص')),
          ],
        )),
      ])),
    );
  }
}
