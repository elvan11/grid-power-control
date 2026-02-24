import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/supabase/supabase_provider.dart';
import '../core/theme/theme_mode_controller.dart';

class PlantSummary {
  const PlantSummary({
    required this.id,
    required this.name,
    required this.timeZone,
    required this.defaultPeakShavingW,
    required this.defaultGridChargingAllowed,
    required this.scheduleControlEnabled,
    this.activeScheduleCollectionId,
  });

  final String id;
  final String name;
  final String timeZone;
  final int defaultPeakShavingW;
  final bool defaultGridChargingAllowed;
  final bool scheduleControlEnabled;
  final String? activeScheduleCollectionId;

  factory PlantSummary.fromMap(Map<String, dynamic> map) {
    return PlantSummary(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'Unnamed',
      timeZone: (map['time_zone'] as String?) ?? 'UTC',
      defaultPeakShavingW:
          (map['default_peak_shaving_w'] as num?)?.toInt() ?? 0,
      defaultGridChargingAllowed:
          (map['default_grid_charging_allowed'] as bool?) ?? false,
      scheduleControlEnabled:
          (map['schedule_control_enabled'] as bool?) ?? true,
      activeScheduleCollectionId:
          map['active_schedule_collection_id'] as String?,
    );
  }
}

class PlantRuntimeSnapshot {
  const PlantRuntimeSnapshot({
    required this.lastAppliedPeakShavingW,
    required this.lastAppliedGridChargingAllowed,
    this.lastAppliedAt,
    this.nextDueAt,
  });

  final int? lastAppliedPeakShavingW;
  final bool? lastAppliedGridChargingAllowed;
  final DateTime? lastAppliedAt;
  final DateTime? nextDueAt;

  factory PlantRuntimeSnapshot.fromMap(Map<String, dynamic> map) {
    return PlantRuntimeSnapshot(
      lastAppliedPeakShavingW: (map['last_applied_peak_shaving_w'] as num?)
          ?.toInt(),
      lastAppliedGridChargingAllowed:
          map['last_applied_grid_charging_allowed'] as bool?,
      lastAppliedAt: map['last_applied_at'] == null
          ? null
          : DateTime.tryParse(map['last_applied_at'] as String),
      nextDueAt: map['next_due_at'] == null
          ? null
          : DateTime.tryParse(map['next_due_at'] as String),
    );
  }
}

class ControlLogEntry {
  const ControlLogEntry({
    required this.providerResult,
    required this.requestedPeakShavingW,
    required this.requestedGridChargingAllowed,
    required this.attemptedAt,
  });

  final String providerResult;
  final int requestedPeakShavingW;
  final bool requestedGridChargingAllowed;
  final DateTime attemptedAt;

  factory ControlLogEntry.fromMap(Map<String, dynamic> map) {
    return ControlLogEntry(
      providerResult: (map['provider_result'] as String?) ?? 'unknown',
      requestedPeakShavingW:
          (map['requested_peak_shaving_w'] as num?)?.toInt() ?? 0,
      requestedGridChargingAllowed:
          (map['requested_grid_charging_allowed'] as bool?) ?? false,
      attemptedAt:
          DateTime.tryParse((map['attempted_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

final plantsProvider = FutureProvider<List<PlantSummary>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return const [
      PlantSummary(
        id: 'local-demo-plant',
        name: 'Demo Installation',
        timeZone: 'Europe/Stockholm',
        defaultPeakShavingW: 2000,
        defaultGridChargingAllowed: false,
        scheduleControlEnabled: true,
        activeScheduleCollectionId: 'local-default-collection',
      ),
    ];
  }

  final result = await client
      .from('plants')
      .select(
        'id,name,time_zone,active_schedule_collection_id,default_peak_shaving_w,default_grid_charging_allowed,schedule_control_enabled',
      )
      .order('created_at', ascending: true);
  return (result as List<dynamic>)
      .map((row) => PlantSummary.fromMap(row as Map<String, dynamic>))
      .toList();
});

class SelectedPlantController extends StateNotifier<String?> {
  SelectedPlantController(this._prefs) : super(_prefs.getString(_prefsKey));

  static const String _prefsKey = 'selected_plant_id';
  final SharedPreferences _prefs;

  Future<void> setSelected(String? plantId) async {
    state = plantId;
    if (plantId == null || plantId.isEmpty) {
      await _prefs.remove(_prefsKey);
      return;
    }
    await _prefs.setString(_prefsKey, plantId);
  }
}

final selectedPlantIdProvider =
    StateNotifierProvider<SelectedPlantController, String?>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return SelectedPlantController(prefs);
    });

final selectedPlantProvider = Provider<PlantSummary?>((ref) {
  final plants =
      ref.watch(plantsProvider).valueOrNull ?? const <PlantSummary>[];
  if (plants.isEmpty) {
    return null;
  }
  final selectedId = ref.watch(selectedPlantIdProvider);
  if (selectedId == null || selectedId.isEmpty) {
    return plants.first;
  }
  for (final plant in plants) {
    if (plant.id == selectedId) {
      return plant;
    }
  }
  return plants.first;
});

final plantRuntimeProvider = FutureProvider.family<PlantRuntimeSnapshot?, String>((
  ref,
  plantId,
) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null || plantId.startsWith('local-')) {
    return const PlantRuntimeSnapshot(
      lastAppliedPeakShavingW: 1800,
      lastAppliedGridChargingAllowed: false,
    );
  }

  final result = await client
      .from('plant_runtime')
      .select(
        'last_applied_peak_shaving_w,last_applied_grid_charging_allowed,last_applied_at,next_due_at',
      )
      .eq('plant_id', plantId)
      .maybeSingle();
  if (result == null) {
    return null;
  }
  return PlantRuntimeSnapshot.fromMap(result);
});

final recentControlLogProvider =
    FutureProvider.family<List<ControlLogEntry>, String>((ref, plantId) async {
      final client = ref.watch(supabaseClientProvider);
      if (client == null || plantId.startsWith('local-')) {
        return [
          ControlLogEntry(
            providerResult: 'success',
            requestedPeakShavingW: 1800,
            requestedGridChargingAllowed: false,
            attemptedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
          ControlLogEntry(
            providerResult: 'success',
            requestedPeakShavingW: 2000,
            requestedGridChargingAllowed: false,
            attemptedAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ];
      }

      final result = await client
          .from('control_apply_log')
          .select(
            'provider_result,requested_peak_shaving_w,requested_grid_charging_allowed,attempted_at',
          )
          .eq('plant_id', plantId)
          .order('attempted_at', ascending: false)
          .limit(8);
      return (result as List<dynamic>)
          .map((row) => ControlLogEntry.fromMap(row as Map<String, dynamic>))
          .toList();
    });
