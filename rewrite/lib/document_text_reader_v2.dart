import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:pdfx/pdfx.dart' as renderer;
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class DocumentTextReaderV2 {
  static const maxFileBytes=12*1024*1024;
  static const maxCharacters=40000;
  static const maxScannedPages=20;

  /// OCR only the specified pages. Every rendered image is deleted on completion.
  static Future<Map<int,String>> _ocrPages(List<int> bytes,List<int> indices) async {
    if(indices.length>maxScannedPages) {
      throw const FormatException('لا يمكن إجراء OCR لأكثر من 20 صفحة مصورة في ملف واحد');
    }
    final pdf=await renderer.PdfDocument.openData(Uint8List.fromList(bytes));
    final recognized=<int,String>{};
    try {
      final temp=await getTemporaryDirectory();
      for(final index in indices){
        final page=await pdf.getPage(index+1);
        try {
          final scale=math.min(2.0,1800/math.max(page.width,page.height));
          final image=await page.render(
            width:math.max(1,(page.width*scale).round()).toDouble(),
            height:math.max(1,(page.height*scale).round()).toDouble(),
            format:renderer.PdfPageImageFormat.png,
          );
          if(image==null)continue;
          final file=File('${temp.path}/aidict_page_${DateTime.now().microsecondsSinceEpoch}_$index.png');
          try {
            await file.writeAsBytes(image.bytes,flush:true);
            final text=await TesseractOcr.extractText(file.path,
              config:const OCRConfig(language:'ara+eng',engine:OCREngine.tesseract));
            if(text.trim().isNotEmpty)recognized[index]=text.trim();
          }finally{
            if(await file.exists())await file.delete();
          }
        }finally{await page.close();}
      }
    }finally{await pdf.close();}
    return recognized;
  }

  /// Combine selectable and scanned pages in their original order, on-device.
  static Future<String> extractPdfText(List<int> bytes) async {
    final pdf=PdfDocument(inputBytes:bytes);
    final results=<int,String>{};
    final missing=<int>[];
    final count=pdf.pages.count;
    try {
      final extractor=PdfTextExtractor(pdf);
      for(var i=0;i<count;i++){
        final text=extractor.extractText(startPageIndex:i,endPageIndex:i).trim();
        if(text.isEmpty){missing.add(i);}
        else{results[i]=text;}
      }
    }finally{pdf.dispose();}
    if(missing.isNotEmpty){
      results.addAll(await _ocrPages(bytes,missing));
    }
    final buffer=StringBuffer();
    for(var i=0;i<count;i++){
      final text=results[i];
      if(text==null || text.isEmpty)continue;
      if(buffer.isNotEmpty)buffer.write('\n\n');
      buffer.write(text);
      if(buffer.length>maxCharacters){
        throw const FormatException('النص المستخرج تجاوز 40000 حرف');
      }
    }
    return buffer.toString().trim();
  }

  static Future<String?> selectAndExtract() async {
    const type=XTypeGroup(label:'Documents',extensions:['pdf','docx','txt']);
    final file=await openFile(acceptedTypeGroups:[type]);
    if(file==null)return null;
    if(await file.length()>maxFileBytes)throw const FormatException('File is too large (12 MB maximum)');
    final bytes=await file.readAsBytes();
    if(bytes.length>maxFileBytes)throw const FormatException('File is too large (12 MB maximum)');
    final extension=file.name.split('.').last.toLowerCase();
    String result;
    switch(extension) {
      case 'txt':
        result=utf8.decode(bytes,allowMalformed:true);
        break;
      case 'pdf':
        result=await extractPdfText(bytes);
        break;
      case 'docx':
        final zip=ZipDecoder().decodeBytes(bytes);
        final doc=zip.findFile('word/document.xml');
        if(doc==null)throw const FormatException('Invalid DOCX');
        final raw=doc.readBytes();
        if(raw==null||raw.length>maxFileBytes*2)throw const FormatException('DOCX content exceeds safe limit');
        final xml=XmlDocument.parse(utf8.decode(raw));
        final paragraphs=xml.descendants.whereType<XmlElement>().where((e)=>e.name.local=='p');
        result=paragraphs.map((p)=>p.descendants.whereType<XmlElement>().where((e)=>e.name.local=='t').map((e)=>e.innerText).join()).join('\n');
        break;
      default:
        throw const FormatException('Unsupported document');
    }
    result=result.trim();
    if(result.isEmpty)throw const FormatException('لم يتم العثور على نص واضح في المستند');
    if(result.length>maxCharacters)throw const FormatException('Text exceeds 40000 characters');
    return result;
  }
}
