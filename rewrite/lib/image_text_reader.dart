import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

/// Arabic/English OCR is performed entirely on-device.
/// Source photos and temporary processed images are never uploaded.
class ImageTextReader {
  static Future<String?> selectAndExtract({required bool camera}) async {
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
    final upright=img.bakeOrientation(decoded);
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
