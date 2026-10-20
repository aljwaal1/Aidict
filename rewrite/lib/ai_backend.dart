import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';

/// Optional user-supplied HTTPS backend. No secret is embedded in the APK.
/// The backend must implement POST /v1/aidict with {task,text,language}.
class AiBackend {
  static Uri validate(String endpoint) {
    final uri=Uri.tryParse(endpoint.trim());
    if(uri==null||uri.scheme!='https'||uri.host.isEmpty||uri.userInfo.isNotEmpty||uri.hasFragment) {
      throw const FormatException('يتطلب عنوان HTTPS صالحًا لخادم المعالجة');
    }
    return uri;
  }
  static Future<String?> transcribeAudio({required String endpoint,String accessToken=''}) async {
    final uri=validate(endpoint);
    const types=XTypeGroup(label:'Audio',extensions:['mp3','wav','m4a','aac','ogg','flac']);
    final file=await openFile(acceptedTypeGroups:[types]);
    if(file==null)return null;
    if(await file.length()>12*1024*1024) {
      throw const FormatException('الحد الأقصى للتسجيل 12 ميغابايت');
    }
    final request=http.MultipartRequest('POST',uri);
    if(accessToken.trim().isNotEmpty)request.headers['Authorization']='Bearer ${accessToken.trim()}';
    request.fields['task']='transcribe';
    request.files.add(http.MultipartFile.fromBytes('audio',await file.readAsBytes(),filename:file.name));
    final streamed=await request.send().timeout(const Duration(seconds:90));
    final response=await http.Response.fromStream(streamed);
    if(response.statusCode!=200)throw StateError('تعذر تفريغ الصوت: HTTP ${response.statusCode}');
    final data=jsonDecode(utf8.decode(response.bodyBytes));
    if(data is! Map||data['result'] is! String||(data['result'] as String).trim().isEmpty) {
      throw const FormatException('استجابة غير صالحة من خدمة التفريغ');
    }
    return data['result'] as String;
  }
  /// Arabic/multilingual OCR requires an external OCR-capable endpoint.
  static Future<String?> recognizeImage({required String endpoint,required bool camera,String accessToken=''}) async {
    final uri=validate(endpoint);
    final image=await ImagePicker().pickImage(
      source:camera?ImageSource.camera:ImageSource.gallery,imageQuality:90);
    if(image==null)return null;
    if(await image.length()>12*1024*1024) {
      throw const FormatException('حجم الصورة أكبر من 12 ميغابايت');
    }
    final request=http.MultipartRequest('POST',uri);
    request.fields['task']='ocr';
    request.files.add(http.MultipartFile.fromBytes('image',await image.readAsBytes(),
      filename:image.name));
    final streamed=await request.send().timeout(const Duration(seconds:90));
    final response=await http.Response.fromStream(streamed);
    if(response.statusCode!=200)throw StateError('تعذر استخراج النص العربي: HTTP ${response.statusCode}');
    final data=jsonDecode(utf8.decode(response.bodyBytes));
    if(data is! Map||data['result'] is! String||(data['result'] as String).trim().isEmpty) {
      throw const FormatException('استجابة OCR غير صالحة');
    }
    return data['result'] as String;
  }
  static Future<String> process({required String endpoint,required String task,
    required String text,String language='ar',String accessToken=''}) async {
    if(!const {'rewrite','proofread','summarize'}.contains(task)) {
      throw const FormatException('نوع معالجة غير مدعوم');
    }
    if(text.trim().isEmpty||text.length>12000) {
      throw const FormatException('النص يجب ألا يتجاوز 12000 حرف');
    }
    final uri=validate(endpoint);
    final response=await http.post(uri,
      headers:{'Content-Type':'application/json',
        if(accessToken.trim().isNotEmpty)'Authorization':'Bearer ${accessToken.trim()}'},
      body:jsonEncode({'task':task,'text':text,'language':language}))
        .timeout(const Duration(seconds:120));
    if(response.statusCode!=200) {
      throw StateError('فشلت المعالجة: HTTP ${response.statusCode}');
    }
    final data=jsonDecode(utf8.decode(response.bodyBytes));
    if(data is! Map || data['result'] is! String || (data['result'] as String).trim().isEmpty) {
      throw const FormatException('الخادم أعاد نتيجة غير صالحة');
    }
    return data['result'] as String;
  }
}
