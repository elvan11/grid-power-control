import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase/supabase_provider.dart';

class DailyScheduleSummary {
  const DailyScheduleSummary({
    required this.id,
    required this.name,
    required this.segmentCount,
  });

  final String id;
  final String name;
  final int segmentCount;
}

enum SegmentControlKind { fixed, spotImport }

class TimeSegmentModel {
  const TimeSegmentModel({
    this.id,
    this.controlKind = SegmentControlKind.fixed,
    this.importEnergyWh,
    required this.startTime,
    required this.endTime,
    required this.peakShavingW,
    required this.gridChargingAllowed,
    required this.sortOrder,
  });

  final String? id;
  final SegmentControlKind controlKind;
  final int? importEnergyWh;

  factory TimeSegmentModel.fromMap(Map<String, dynamic> map) =>
      TimeSegmentModel(
        id: map['id'] as String?,
        startTime: map['start_time'] as String,
        endTime: map['end_time'] as String,
        peakShavingW: (map['peak_shaving_w'] as num).toInt(),
        gridChargingAllowed: map['grid_charging_allowed'] as bool? ?? false,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        controlKind: map['control_kind'] == 'spot_import'
            ? SegmentControlKind.spotImport
            : SegmentControlKind.fixed,
        importEnergyWh: (map['import_energy_wh'] as num?)?.toInt(),
      );

  final String startTime;
  final String endTime;
  final int peakShavingW;
  final bool gridChargingAllowed;
  final int sortOrder;

  Map<String, dynamic> toRpcJson() {
    return {
      if (id != null) 'id': id,
      'control_kind': controlKind == SegmentControlKind.spotImport
          ? 'spot_import'
          : 'fixed',
      'import_energy_wh': controlKind == SegmentControlKind.spotImport
          ? importEnergyWh
          : null,
      'start_time': startTime,
      'end_time': endTime,
      'peak_shaving_w': peakShavingW,
      'grid_charging_allowed':
          controlKind == SegmentControlKind.fixed && gridChargingAllowed,
      'sort_order': sortOrder,
    };
  }
}

class DailyScheduleDetail {
  const DailyScheduleDetail({
    required this.id,
    required this.name,
    required this.segments,
  });

  final String id;
  final String name;
  final List<TimeSegmentModel> segments;
}

class WeekScheduleBundle {
  const WeekScheduleBundle({
    required this.weekScheduleId,
    required this.assignmentsByDay,
  });

  final String weekScheduleId;
  final Map<int, String?> assignmentsByDay;
}

final dailySchedulesProvider =
    FutureProvider.family<List<DailyScheduleSummary>, String>((
      ref,
      collectionId,
    ) async {
      final client = ref.watch(supabaseClientProvider);
      if (collectionId.startsWith('local-') || client == null) {
        return const [
          DailyScheduleSummary(
            id: 'local-schedule-1',
            name: 'Weekday Balanced',
            segmentCount: 4,
          ),
          DailyScheduleSummary(
            id: 'local-schedule-2',
            name: 'Night Saver',
            segmentCount: 2,
          ),
        ];
      }

      final schedules = await client
          .from('daily_schedules')
          .select('id,name')
          .eq('schedule_collection_id', collectionId)
          .order('created_at', ascending: true);

      final rows = schedules as List<dynamic>;
      final ids = rows
          .map((row) => (row as Map<String, dynamic>)['id'] as String)
          .toList();
      final segmentCounts = <String, int>{};

      if (ids.isNotEmpty) {
        final segments = await client
            .from('time_segments')
            .select('daily_schedule_id')
            .inFilter('daily_schedule_id', ids);
        for (final segment in segments as List<dynamic>) {
          final scheduleId =
              (segment as Map<String, dynamic>)['daily_schedule_id'] as String;
          segmentCounts[scheduleId] = (segmentCounts[scheduleId] ?? 0) + 1;
        }
      }

      return rows.map((row) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        return DailyScheduleSummary(
          id: id,
          name: (map['name'] as String?) ?? 'Unnamed schedule',
          segmentCount: segmentCounts[id] ?? 0,
        );
      }).toList();
    });

final dailyScheduleDetailProvider =
    FutureProvider.family<DailyScheduleDetail, String>((ref, scheduleId) async {
      final client = ref.watch(supabaseClientProvider);
      if (scheduleId.startsWith('local-') || client == null) {
        return const DailyScheduleDetail(
          id: 'local-schedule-1',
          name: 'Weekday Balanced',
          segments: [
            TimeSegmentModel(
              startTime: '06:00:00',
              endTime: '09:00:00',
              peakShavingW: 3000,
              gridChargingAllowed: false,
              sortOrder: 0,
            ),
            TimeSegmentModel(
              startTime: '18:00:00',
              endTime: '22:00:00',
              peakShavingW: 2500,
              gridChargingAllowed: false,
              sortOrder: 1,
            ),
          ],
        );
      }

      final schedule = await client
          .from('daily_schedules')
          .select('id,name')
          .eq('id', scheduleId)
          .single();
      final segments = await client
          .from('time_segments')
          .select(
            'id,start_time,end_time,peak_shaving_w,grid_charging_allowed,sort_order,control_kind,import_energy_wh',
          )
          .eq('daily_schedule_id', scheduleId)
          .order('sort_order', ascending: true);

      return DailyScheduleDetail(
        id: schedule['id'] as String,
        name: (schedule['name'] as String?) ?? 'Unnamed schedule',
        segments: (segments as List<dynamic>).map((segment) {
          final map = segment as Map<String, dynamic>;
          return TimeSegmentModel.fromMap(map);
        }).toList(),
      );
    });

final weekScheduleBundleProvider =
    FutureProvider.family<WeekScheduleBundle, String>((
      ref,
      collectionId,
    ) async {
      final client = ref.watch(supabaseClientProvider);
      if (collectionId.startsWith('local-') || client == null) {
        return const WeekScheduleBundle(
          weekScheduleId: 'local-week',
          assignmentsByDay: {
            1: 'local-schedule-1',
            2: 'local-schedule-1',
            3: 'local-schedule-1',
            4: 'local-schedule-1',
            5: 'local-schedule-1',
            6: 'local-schedule-2',
            7: 'local-schedule-2',
          },
        );
      }

      final week = await client
          .from('week_schedules')
          .select('id')
          .eq('schedule_collection_id', collectionId)
          .maybeSingle();
      if (week == null) {
        throw StateError('No week schedule exists for active collection.');
      }

      final weekScheduleId = week['id'] as String;
      final assignments = await client
          .from('week_schedule_day_assignments')
          .select('day_of_week,daily_schedule_id,priority')
          .eq('week_schedule_id', weekScheduleId)
          .order('priority', ascending: false);

      final map = <int, String?>{};
      for (var day = 1; day <= 7; day++) {
        map[day] = null;
      }
      for (final row in assignments as List<dynamic>) {
        final assignment = row as Map<String, dynamic>;
        final day = (assignment['day_of_week'] as num).toInt();
        map[day] ??= assignment['daily_schedule_id'] as String;
      }

      return WeekScheduleBundle(
        weekScheduleId: weekScheduleId,
        assignmentsByDay: map,
      );
    });
