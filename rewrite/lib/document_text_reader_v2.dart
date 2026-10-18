import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class DocumentTextReaderV2 {
  static const maxFileBytes=12*1024*1024;
  static const maxCharacters=40000;

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
        final pdf=PdfDocument(inputBytes:bytes);
        try {result=PdfTextExtractor(pdf).extractText();}
        finally {pdf.dispose();}
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
    if(result.isEmpty)throw const FormatException('No text found; scanned PDFs require OCR');
    if(result.length>maxCharacters)throw const FormatException('Text exceeds 40000 characters');
    return result;
  }
}
