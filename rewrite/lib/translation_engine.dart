import 'dart:convert';
import 'package:http/http.dart' as http;

enum OnlineEngine { myMemory, libreTranslate }

class TranslationEngine {
  static Uri validateEndpoint(String raw) {
    final uri=Uri.tryParse(raw.trim());
    if(uri==null || uri.scheme!='https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('خادم LibreTranslate يتطلب عنوان HTTPS صالحًا');
    }
    return uri;
  }

  static Future<String> translate({
    required String text,
    required String source,
    required String target,
    required OnlineEngine engine,
    String endpoint='',
  }) async {
    if(text.trim().isEmpty) return '';
    if(engine==OnlineEngine.myMemory) {
      final uri=Uri.https('api.mymemory.translated.net','/get',{
        'q':text,'langpair':'$source|$target',
      });
      final response=await http.get(uri).timeout(const Duration(seconds:25));
      if(response.statusCode!=200)throw StateError('MyMemory HTTP ${response.statusCode}');
      final body=jsonDecode(utf8.decode(response.bodyBytes));
      if(body is! Map || (body['responseStatus'] is num && body['responseStatus']!=200)) {
        throw const FormatException('خدمة الترجمة رفضت الطلب');
      }
      final translated=(body['responseData'] as Map?)?['translatedText'];
      if(translated is! String || translated.trim().isEmpty) {
        throw const FormatException('ترجمة فارغة');
      }
      return translated;
    }
    final uri=validateEndpoint(endpoint);
    final response=await http.post(uri,headers:{'Content-Type':'application/json'},
      body:jsonEncode({'q':text,'source':source,'target':target,'format':'text'}))
      .timeout(const Duration(seconds:40));
    if(response.statusCode!=200)throw StateError('LibreTranslate HTTP ${response.statusCode}');
    final body=jsonDecode(utf8.decode(response.bodyBytes));
    if(body is! Map || body['translatedText'] is! String) {
      throw const FormatException('استجابة LibreTranslate غير صالحة');
    }
    return body['translatedText'] as String;
  }
}
