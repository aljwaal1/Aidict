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

  /// Render pages on-device, recognize Arabic and English, and delete temporary images.
  static Future<String> extractScannedPdf(List<int> bytes) async {
    final pdf=await renderer.PdfDocument.openData(Uint8List.fromList(bytes));
    final parts=<String>[];
    try {
      if(pdf.pagesCount>maxScannedPages){
        throw const FormatException('OCR يدعم أول 20 صفحة فقط لكل ملف حفاظًا على الذاكرة');
      }
      final temp=await getTemporaryDirectory();
      for(var i=1;i<=pdf.pagesCount;i++) {
        final page=await pdf.getPage(i);
        try {
          final scale=math.min(2.0,1800/math.max(page.width,page.height));
          final image=await page.render(
            width:math.max(1,(page.width*scale).round()).toDouble(),
            height:math.max(1,(page.height*scale).round()).toDouble(),
            format:renderer.PdfPageImageFormat.png,
          );
          if(image==null)continue;
          final file=File('${temp.path}/aidict_ocr_${DateTime.now().microsecondsSinceEpoch}_$i.png');
          try {
            await file.writeAsBytes(image.bytes,flush:true);
            final recognized=await TesseractOcr.extractText(file.path,
              config:const OCRConfig(language:'ara+eng',engine:OCREngine.tesseract));
            if(recognized.trim().isNotEmpty){
              parts.add(recognized.trim());
              if(parts.join('\n').length>maxCharacters){
                throw const FormatException('نص PDF المستخرج تجاوز 40000 حرف');
              }
            }
          }finally{
            if(await file.exists())await file.delete();
          }
        }finally{await page.close();}
      }
    }finally{await pdf.close();}
    return parts.join('\\n\\n');
  }


  /// Extract selectable PDF text first and OCR scanned-only PDFs on-device.
  static Future<String> extractPdfText(List<int> bytes) async {
    final pdf=PdfDocument(inputBytes:bytes);
    String result;
    try {result=PdfTextExtractor(pdf).extractText();}
    finally {pdf.dispose();}
    if(result.trim().isEmpty)result=await extractScannedPdf(bytes);
    return result.trim();
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
