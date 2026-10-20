import 'package:image_picker/image_picker.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

/// Arabic and English OCR runs on Android using bundled Tesseract assets.
/// No image data is uploaded or sent to a remote OCR service.
class ImageTextReader {
  static Future<String?> selectAndExtract({required bool camera}) async {
    final photo=await ImagePicker().pickImage(
      source:camera?ImageSource.camera:ImageSource.gallery,
      imageQuality:90);
    if(photo==null)return null;
    final result=await TesseractOcr.extractText(
      photo.path,
      config:OCRConfig(language:'ara+eng',engine:OCREngine.tesseract),
    );
    if(result.trim().isEmpty){
      throw const FormatException('لم يعثر OCR المحلي على نص واضح في الصورة');
    }
    return result.trim();
  }
}
