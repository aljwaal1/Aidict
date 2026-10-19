import 'dart:convert';
import 'package:http/http.dart' as http;

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
