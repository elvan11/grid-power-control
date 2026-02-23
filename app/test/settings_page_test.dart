import 'package:app/features/settings/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAppVersionLabel', () {
    test('formats year month day and build number pattern', () {
      final label = buildAppVersionLabel(now: DateTime(2026, 2, 21));

      expect(label, matches(RegExp(r'^2026\.02\.21\+\d+$')));
    });
  });
}
