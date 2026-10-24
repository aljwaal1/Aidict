import 'dart:collection';
import 'dart:convert';

/// Session-only, bounded cache of successful offline translation requests.
/// Language direction and exact input are part of the key.
class TranslationMemory {
  TranslationMemory({this.maxEntries=120}) {
    if(maxEntries<1)throw ArgumentError.value(maxEntries,'maxEntries');
  }
  final int maxEntries;
  final _cache=LinkedHashMap<String,String>();
  final _pending=<String,Future<String>>{};

  Future<String> translate(String source,String target,String text,
      Future<String> Function() translator) async {
    final key=jsonEncode([source,target,text]);
    if(_cache.containsKey(key)) {
      final value=_cache.remove(key)!;
      _cache[key]=value;
      return value;
    }
    final inFlight=_pending[key];
    if(inFlight!=null)return inFlight;
    final request=translator();
    _pending[key]=request;
    try {
      final result=await request;
      if(result.trim().isNotEmpty) {
        _cache[key]=result;
        while(_cache.length>maxEntries){_cache.remove(_cache.keys.first);}
      }
      return result;
    } finally {
      _pending.remove(key);
    }
  }
}
