import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:aidict/document_text_reader_v2.dart';

void main() {
  test('multi-page selectable PDF retains text from both pages', () async {
    final pdf=PdfDocument();
    pdf.pages.add().graphics.drawString('First English page',
      PdfStandardFont(PdfFontFamily.helvetica,12));
    pdf.pages.add().graphics.drawString('Second English page',
      PdfStandardFont(PdfFontFamily.helvetica,12));
    final bytes=await pdf.save();
    pdf.dispose();
    final result=await DocumentTextReaderV2.extractPdfText(bytes);
    expect(result,contains('First English page'));
    expect(result,contains('Second English page'));
    expect(result.indexOf('First English page'),lessThan(result.indexOf('Second English page')));
  });
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
