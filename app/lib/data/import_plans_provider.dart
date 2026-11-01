import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/supabase/supabase_provider.dart';

class ImportQuarter {
  const ImportQuarter({
    required this.start,
    required this.end,
    required this.selected,
    required this.energyWh,
  });
  final DateTime start, end;
  final bool selected;
  final double energyWh;
  factory ImportQuarter.fromMap(Map<String, dynamic> map) => ImportQuarter(
    start: DateTime.parse(map['start'] as String),
    end: DateTime.parse(map['end'] as String),
    selected: map['selected'] == true,
    energyWh: (map['energy_wh'] as num?)?.toDouble() ?? 0,
  );
}

class ImportPlan {
  const ImportPlan({
    required this.targetWh,
    required this.powerW,
    required this.status,
    required this.slots,
  });
  final int targetWh, powerW;
  final String status;
  final List<ImportQuarter> slots;
  double get nominalWh =>
      slots.where((s) => s.selected).fold(0, (total, s) => total + s.energyWh);
  factory ImportPlan.fromMap(Map<String, dynamic> map) => ImportPlan(
    targetWh: (map['target_wh'] as num).toInt(),
    powerW: (map['peak_shaving_w'] as num).toInt(),
    status: map['status'] as String,
    slots: (map['slots'] as List)
        .map((s) => ImportQuarter.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList(),
  );
}

final importPlansProvider = FutureProvider.family<List<ImportPlan>, String>((
  ref,
  plantId,
) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null || plantId.startsWith('local-')) return const [];
  final rows = await client.rpc(
    'get_plant_import_plan',
    params: {'p_plant_id': plantId},
  );
  return (rows as List)
      .map((row) => ImportPlan.fromMap(Map<String, dynamic>.from(row as Map)))
      .toList();
});
