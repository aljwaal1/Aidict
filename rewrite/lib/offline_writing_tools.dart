/// Offline, deterministic text utilities; no AI model or network calls.
/// Extractive summary selects original sentences, not generative paraphrasing.
class OfflineWritingTools {
  static String proofreadFormatting(String text) {
    return text.replaceAll('\r\n','\n').replaceAll('\r','\n')
      .replaceAll(RegExp(r'[ \\t]+'),' ')
      .replaceAll(RegExp(r' *\n *'),'\n')
      .replaceAll(RegExp(r'\n{3,}'),'\n\n').trim();
  }

  static String extractiveSummary(String text,{int maxSentences=3}) {
    if(maxSentences<1)throw const FormatException('Invalid sentence limit');
    final cleaned=proofreadFormatting(text);
    if(cleaned.isEmpty)return '';
    final sentences=cleaned.split(RegExp(r'(?<=[.!؟?])\\s+|\\n+'))
      .map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();
    if(sentences.length<=maxSentences)return sentences.join(' ');
    final frequency=<String,int>{};
    final words=RegExp(r'[\\p{L}]{3,}',unicode:true);
    for(final sentence in sentences){
      for(final match in words.allMatches(sentence.toLowerCase())){
        final word=match.group(0)!;
        frequency[word]=(frequency[word]??0)+1;
      }
    }
    final indexed=List<int>.generate(sentences.length,(i)=>i);
    indexed.sort((a,b){
      double score(int i){
        final terms=words.allMatches(sentences[i].toLowerCase()).map((m)=>m.group(0)!);
        return terms.fold<double>(0,(sum,w)=>sum+(frequency[w]??0));
      }
      final comparison=score(b).compareTo(score(a));
      return comparison!=0?comparison:a.compareTo(b);
    });
    final chosen=indexed.take(maxSentences).toList()..sort();
    return chosen.map((i)=>sentences[i]).join(' ');
  }
}
