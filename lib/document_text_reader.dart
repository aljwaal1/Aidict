import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class DocumentTextReader {
  static const int maxFileBytes = 12 * 1024 * 1024;
  static const int maxCharacters = 40000;

  static Future<String?> selectAndExtract() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.size > maxFileBytes) {
      throw const FormatException('الحد الأقصى لحجم المستند 12 ميغابايت');
    }
    final bytes = file.bytes;
    if (bytes == null) throw const FormatException('تعذرت قراءة بيانات المستند');
    final lower = file.extension?.toLowerCase();
    String text;
    switch (lower) {
      case 'txt':
        text = utf8.decode(bytes, allowMalformed: true);
        break;
      case 'pdf':
        final document = PdfDocument(inputBytes: bytes);
        try {
          text = PdfTextExtractor(document).extractText();
        } finally {
          document.dispose();
        }
        break;
      case 'docx':
        final archive = ZipDecoder().decodeBytes(bytes);
        final documentXml = archive.findFile('word/document.xml');
        if (documentXml == null) {
          throw const FormatException('الملف ليس مستند DOCX صالحًا');
        }
        final xmlBytes = documentXml.readBytes();
        if (xmlBytes == null) {
          throw const FormatException('تعذرت قراءة محتوى ملف Word');
        }
        final xml = XmlDocument.parse(utf8.decode(xmlBytes));
        final paragraphs = xml.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'p');
        text = paragraphs.map((paragraph) => paragraph.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 't')
            .map((element) => element.innerText)
            .join()).join('\n');
      default:
        throw const FormatException('صيغة الملف غير مدعومة');
    }
    text = text.trim();
    if (text.isEmpty) {
      throw const FormatException(
          'لم يتم العثور على نص قابل للاستخراج. ملفات PDF المصورة تحتاج OCR.');
    }
    if (text.length > maxCharacters) {
      throw const FormatException('المستند طويل جدًا؛ يدعم المستخرج الحالي 40000 حرف');
    }
    return text;
  }
}
