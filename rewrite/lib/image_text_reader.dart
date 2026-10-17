import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ImageTextReader {
  static Future<String?> selectAndExtract({required bool camera}) async {
    final photo=await ImagePicker().pickImage(
      source:camera?ImageSource.camera:ImageSource.gallery,
      imageQuality:90);
    if(photo==null)return null;
    final recognizer=TextRecognizer(script:TextRecognitionScript.latin);
    try {
      final result=await recognizer.processImage(InputImage.fromFilePath(photo.path));
      if(result.text.trim().isEmpty)throw const FormatException('لم يتم العثور على نص لاتيني واضح في الصورة');
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }
}
