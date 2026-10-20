import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:aidict/document_text_reader_v2.dart';

void main() {
  test('local selectable PDF extraction does not need OCR or a server', () async {
    final pdf=PdfDocument();
    pdf.pages.add().graphics.drawString(
      'Hello local PDF extraction',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );
    final bytes=await pdf.save();
    pdf.dispose();
    final extracted=await DocumentTextReaderV2.extractPdfText(bytes);
    expect(extracted,contains('Hello local PDF extraction'));
  });
}
