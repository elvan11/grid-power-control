import 'package:app/features/settings/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAppVersionLabel', () {
    test('uses provided build date and build number when available', () {
      final label = buildAppVersionLabel(
        now: DateTime(2026, 2, 21),
        buildDate: '2026-01-05T03:45:00Z',
        buildNumber: '7',
      );

      expect(label, '2026.01.05+7');
    });

    test('falls back to current date and default build number', () {
      final label = buildAppVersionLabel(now: DateTime(2026, 2, 21));

      expect(label, '2026.02.21+1');
    });
  });
}
