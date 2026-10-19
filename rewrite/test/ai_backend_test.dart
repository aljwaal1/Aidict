import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/ai_backend.dart';
void main() {
  test('Rejects insecure and malformed AI endpoints', () {
    expect(()=>AiBackend.validate('http://example.com/v1/aidict'),throwsFormatException);
    expect(()=>AiBackend.validate(''),throwsFormatException);
    expect(AiBackend.validate('https://example.com/v1/aidict').host,'example.com');
  });
}
