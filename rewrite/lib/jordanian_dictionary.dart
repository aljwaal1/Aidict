import 'dart:convert';
import 'package:flutter/services.dart';

/// Jordanian school vocabulary is packaged with the app for offline lookup.
/// This is a reference dictionary, not a machine-translation model.
class JordanianDictionary {
  static Future<Map<String,String>> load({AssetBundle? bundle}) async {
    final data=await (bundle??rootBundle).loadString('assets/jordanian_words.json');
    final parsed=jsonDecode(data);
    if(parsed is! Map || parsed['words'] is! List) {
      throw const FormatException('Invalid Jordanian dictionary');
    }
    final result=<String,String>{};
    for(final item in parsed['words'] as List) {
      if(item is! Map)continue;
      final en=(item['word_en']??'').toString().trim().toLowerCase();
      final ar=(item['meaning_ar']??'').toString().trim();
      if(en.isNotEmpty && ar.isNotEmpty)result.putIfAbsent(en,()=>ar);
    }
    return result;
  }

  static List<MapEntry<String,String>> search(
    String query,Map<String,String> dictionary,{
    Map<String,String> fallback=const {},int limit=12,
  }) {
    final q=query.trim().toLowerCase();
    if(q.isEmpty || limit<=0)return [];
    final seen=<String>{};
    final exact=<MapEntry<String,String>>[];
    final prefixes=<MapEntry<String,String>>[];
    final partial=<MapEntry<String,String>>[];
    for(final entry in [...dictionary.entries,...fallback.entries]) {
      final key=entry.key.toLowerCase();
      final value=entry.value.toLowerCase();
      if(!seen.add(key))continue;
      if(key==q || value==q){exact.add(entry);}
      else if(key.startsWith(q)||value.startsWith(q)){prefixes.add(entry);}
      else if(key.contains(q)||value.contains(q)){partial.add(entry);}
    }
    return [...exact,...prefixes,...partial].take(limit).toList();
  }
}
