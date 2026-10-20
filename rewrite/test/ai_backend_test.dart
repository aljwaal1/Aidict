import 'package:flutter_test/flutter_test.dart';
import 'package:aidict/ai_backend.dart';

void main() {
  group('Optional HTTPS backend endpoint validation', () {
    test('accepts secure endpoint with API path', () {
      final uri = AiBackend.validate(' https://example.org/v1/aidict ');
      expect(uri.scheme, 'https');
      expect(uri.path, '/v1/aidict');
    });
    test('rejects insecure or malformed endpoints', () {
      for (final value in [
        '', 'http://example.org/v1/aidict', 'not a URL',
        'https://user:pass@example.org/v1/aidict',
        'https://example.org/v1/aidict#fragment',
      ]) {
        expect(() => AiBackend.validate(value), throwsFormatException,
          reason: 'Unexpected accepted endpoint: $value');
      }
    });
  });
}
