const priceAreas = [
  'SE1',
  'SE2',
  'SE3',
  'SE4',
  'NO1',
  'NO2',
  'NO3',
  'NO4',
  'NO5',
  'DK1',
  'DK2',
  'FI',
];

int? parseImportWh(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,7}(\.\d{1,3})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final wh =
      int.parse(parts[0]) * 1000 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(3, '0')));
  return wh <= 2147483647 ? wh : null;
}

int importQuarterCount(int targetWh, int powerW) =>
    powerW <= 0 ? 0 : (targetWh * 4 + powerW - 1) ~/ powerW;
String? validateSpotImport({
  required int powerW,
  required int? targetWh,
  required int durationMinutes,
  required String? priceArea,
}) {
  if (powerW <= 0 || powerW > 10000 || powerW % 100 != 0) {
    return 'Maximum power must be 100–10000 W in 100 W steps.';
  }
  if (targetWh == null || targetWh <= 0) {
    return 'Enter positive kWh with at most three decimals.';
  }
  if (targetWh * 60 > powerW * durationMinutes) {
    return 'Energy target exceeds the window capacity.';
  }
  if (!priceAreas.contains(priceArea)) {
    return 'Select an installation price area in Settings first.';
  }
  return null;
}
