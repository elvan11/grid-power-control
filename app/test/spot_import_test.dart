import 'package:app/data/schedules_provider.dart';
import 'package:app/data/spot_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('spot segment preserves stable identity and target', () {
    final s = TimeSegmentModel.fromMap({
      'id': 'one',
      'start_time': '00:00:00',
      'end_time': '02:00:00',
      'peak_shaving_w': 6000,
      'grid_charging_allowed': true,
      'control_kind': 'spot_import',
      'import_energy_wh': 4500,
    });
    expect(s.controlKind, SegmentControlKind.spotImport);
    expect(s.toRpcJson()['id'], 'one');
    expect(s.toRpcJson()['import_energy_wh'], 4500);
    expect(s.toRpcJson()['grid_charging_allowed'], false);
  });
  test('nominal quarters and precise kWh validation', () {
    expect(importQuarterCount(4500, 6000), 3);
    expect(importQuarterCount(4000, 6000), 3);
    expect(parseImportWh('4.5'), 4500);
    expect(parseImportWh('0,001'), 1);
    expect(parseImportWh('1.0001'), isNull);
    expect(parseImportWh('-1'), isNull);
    expect(parseImportWh('9223372036854775807'), isNull);
    expect(parseImportWh('2147483.648'), isNull);
    expect(
      validateSpotImport(
        powerW: 6000,
        targetWh: 4500,
        durationMinutes: 120,
        priceArea: 'SE3',
      ),
      isNull,
    );
    expect(
      validateSpotImport(
        powerW: 0,
        targetWh: 4500,
        durationMinutes: 120,
        priceArea: 'SE3',
      ),
      isNotNull,
    );
    expect(
      validateSpotImport(
        powerW: 6000,
        targetWh: 13000,
        durationMinutes: 120,
        priceArea: 'SE3',
      ),
      isNotNull,
    );
    expect(
      validateSpotImport(
        powerW: 6000,
        targetWh: 4500,
        durationMinutes: 120,
        priceArea: null,
      ),
      contains('price area'),
    );
  });
}
