import 'package:app/features/installations/connect_service_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('preferNonEmptyValue', () {
    test('returns primary value when non-empty', () {
      expect(preferNonEmptyValue('primary', 'fallback'), 'primary');
    });

    test('returns fallback value when primary is empty', () {
      expect(preferNonEmptyValue('', 'fallback'), 'fallback');
    });
  });

  group('parseSolisConfigValues', () {
    test('returns stored Solis config values for editable fields', () {
      final values = parseSolisConfigValues({
        'inverterSn': 'INV-123',
        'apiId': 'api-id',
        'apiSecret': 'api-secret',
        'apiBaseUrl': 'https://api.example.com',
      });

      expect(values['inverterSn'], 'INV-123');
      expect(values['apiId'], 'api-id');
      expect(values['apiSecret'], 'api-secret');
      expect(values['apiBaseUrl'], 'https://api.example.com');
    });

    test('falls back to empty strings for missing or non-string values', () {
      final values = parseSolisConfigValues({
        'inverterSn': 123,
        'apiSecret': null,
      });

      expect(values['inverterSn'], isEmpty);
      expect(values['apiId'], isEmpty);
      expect(values['apiSecret'], isEmpty);
      expect(values['apiBaseUrl'], isEmpty);
    });
  });
}
