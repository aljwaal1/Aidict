import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/offline_writing_tools.dart';
void main(){
  test('Offline formatting retains Arabic content',(){
    expect(OfflineWritingTools.proofreadFormatting('مرحبا   بك\r\n\r\n\r\nأهلا'),'مرحبا بك\n\nأهلا');
  });
  test('Summary is extractive and deterministic',(){
    const source='The cat is on the mat. The mat is soft. The dog runs outside. The cat sleeps.';
    final summary=OfflineWritingTools.extractiveSummary(source,maxSentences:2);
    expect(summary.isNotEmpty,isTrue);
    expect(summary.split('.').where((s)=>s.trim().isNotEmpty).length,2);
  });
  test('Empty summary and invalid limit',(){
    expect(OfflineWritingTools.extractiveSummary('   '),'');
    expect(()=>OfflineWritingTools.extractiveSummary('A.',maxSentences:0),throwsFormatException);
  });
}
