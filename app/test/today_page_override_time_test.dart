import 'package:app/features/today/today_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ceilToQuarterHour', () {
    test('keeps values already on quarter-hour boundaries', () {
      final value = DateTime(2026, 2, 26, 10, 30);
      expect(ceilToQuarterHour(value), DateTime(2026, 2, 26, 10, 30));
    });

    test('rounds up values between quarter-hour boundaries', () {
      final value = DateTime(2026, 2, 26, 10, 7);
      expect(ceilToQuarterHour(value), DateTime(2026, 2, 26, 10, 15));
    });

    test('rolls into next hour when needed', () {
      final value = DateTime(2026, 2, 26, 10, 59);
      expect(ceilToQuarterHour(value), DateTime(2026, 2, 26, 11, 0));
    });
  });
}
