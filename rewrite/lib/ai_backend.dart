import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';

/// Optional user-supplied HTTPS backend. No secret is embedded in the APK.
/// The backend must implement POST /v1/aidict with {task,text,language}.
class AiBackend {
  static Uri validate(String endpoint) {
    final uri=Uri.tryParse(endpoint.trim());
    if(uri==null||uri.scheme!='https'||uri.host.isEmpty||uri.userInfo.isNotEmpty) {
      throw const FormatException('يتطلب عنوان HTTPS صالحًا لخادم المعالجة');
    }
    return uri;
  }
  static Future<String?> transcribeAudio({required String endpoint}) async {
    const types=XTypeGroup(label:'Audio',extensions:['mp3','wav','m4a','aac','ogg','flac']);
    final file=await openFile(acceptedTypeGroups:[types]);
    if(file==null)return null;
    if(await file.length()>12*1024*1024) {
      throw const FormatException('الحد الأقصى للتسجيل 12 ميغابايت');
    }
    final request=http.MultipartRequest('POST',validate(endpoint));
    request.fields['task']='transcribe';
    request.files.add(http.MultipartFile.fromBytes('audio',await file.readAsBytes(),filename:file.name));
    final streamed=await request.send().timeout(const Duration(seconds:90));
    final response=await http.Response.fromStream(streamed);
    if(response.statusCode!=200)throw StateError('تعذر تفريغ الصوت: HTTP ${response.statusCode}');
    final data=jsonDecode(utf8.decode(response.bodyBytes));
    if(data is! Map||data['result'] is! String) {
      throw const FormatException('استجابة غير صالحة من خدمة التفريغ');
    }
    return data['result'] as String;
  }
  static Future<String> process({required String endpoint,required String task,
    required String text,String language='ar'}) async {
    if(!const {'rewrite','proofread','summarize'}.contains(task)) {
      throw const FormatException('نوع معالجة غير مدعوم');
    }
    if(text.trim().isEmpty||text.length>12000) {
      throw const FormatException('النص يجب ألا يتجاوز 12000 حرف');
    }
    final uri=validate(endpoint);
    final response=await http.post(uri,
      headers:{'Content-Type':'application/json'},
      body:jsonEncode({'task':task,'text':text,'language':language}))
        .timeout(const Duration(seconds:45));
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
