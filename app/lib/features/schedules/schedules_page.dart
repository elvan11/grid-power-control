import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_responsive.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/plants_provider.dart';
import '../../data/schedules_provider.dart';

class SchedulesPage extends ConsumerStatefulWidget {
  const SchedulesPage({super.key});

  @override
  ConsumerState<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends ConsumerState<SchedulesPage> {
  Map<int, String?> _dayAssignments = <int, String?>{};
  bool _dayAssignmentsInitialized = false;
  String? _assignmentsCollectionId;
  bool _savingDayAssignments = false;

  static const List<_DaySpec> _daySpecs = <_DaySpec>[
    _DaySpec(day: 1, shortLabel: 'M', fullLabel: 'Monday'),
    _DaySpec(day: 2, shortLabel: 'T', fullLabel: 'Tuesday'),
    _DaySpec(day: 3, shortLabel: 'W', fullLabel: 'Wednesday'),
    _DaySpec(day: 4, shortLabel: 'T', fullLabel: 'Thursday'),
    _DaySpec(day: 5, shortLabel: 'F', fullLabel: 'Friday'),
    _DaySpec(day: 6, shortLabel: 'S', fullLabel: 'Saturday'),
    _DaySpec(day: 7, shortLabel: 'S', fullLabel: 'Sunday'),
  ];

  Widget _buildScheduleCard(
    BuildContext context,
    PlantSummary plant,
    DailyScheduleSummary schedule,
  ) {
    final assignedLabels = _assignedShortLabelsForSchedule(schedule.id);
    return GpSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  schedule.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit schedule',
                onPressed: () => context.go('/schedules/${schedule.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${schedule.segmentCount} segments'),
          const SizedBox(height: 8),
          Text(
            assignedLabels.isEmpty
                ? 'Assigned days: none'
                : 'Assigned days: ${assignedLabels.join(', ')}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _daySpecs
                .map(
                  (daySpec) => Tooltip(
                    message: daySpec.fullLabel,
                    child: FilterChip(
                      label: Text(daySpec.shortLabel),
                      selected: _dayAssignments[daySpec.day] == schedule.id,
                      showCheckmark: false,
                      onSelected: (_) =>
                          _toggleDayForSchedule(daySpec.day, schedule.id),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GpSecondaryButton(
                  label: 'Duplicate',
                  icon: Icons.copy_outlined,
                  onPressed: () => _duplicateSchedule(plant, schedule),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createSchedule(PlantSummary plant) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Schedule'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Schedule name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(nameController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }

    final collectionId = plant.activeScheduleCollectionId;
    if (collectionId == null || collectionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plant has no active schedule collection.'),
        ),
      );
      return;
    }
    final client = ref.read(supabaseClientProvider);
    if (client == null || collectionId.startsWith('local-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Created in preview mode only.')),
      );
      return;
    }
    try {
      await client.from('daily_schedules').insert({
        'schedule_collection_id': collectionId,
        'name': name,
      });
      ref.invalidate(dailySchedulesProvider(collectionId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schedule created.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create schedule: $error')),
      );
    }
  }

  Future<void> _duplicateSchedule(
    PlantSummary plant,
    DailyScheduleSummary schedule,
  ) async {
    final client = ref.read(supabaseClientProvider);
    final collectionId = plant.activeScheduleCollectionId;
    if (collectionId == null ||
        client == null ||
        collectionId.startsWith('local-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Duplicate is available only with Supabase connection.',
          ),
        ),
      );
      return;
    }
    try {
      final created = await client
          .from('daily_schedules')
          .insert({
            'schedule_collection_id': collectionId,
            'name': '${schedule.name} (Copy)',
          })
          .select('id')
          .single();
      final newScheduleId = created['id'] as String;

      final segments = await client
          .from('time_segments')
          .select(
            'start_time,end_time,peak_shaving_w,grid_charging_allowed,sort_order',
          )
          .eq('daily_schedule_id', schedule.id)
          .order('sort_order', ascending: true);

      final payload = (segments as List<dynamic>)
          .map(
            (segment) => {
              'start_time': (segment as Map<String, dynamic>)['start_time'],
              'end_time': segment['end_time'],
              'peak_shaving_w': segment['peak_shaving_w'],
              'grid_charging_allowed': segment['grid_charging_allowed'],
              'sort_order': segment['sort_order'],
            },
          )
          .toList();
      await client.rpc(
        'replace_daily_schedule_segments',
        params: {'p_daily_schedule_id': newScheduleId, 'p_segments': payload},
      );
      ref.invalidate(dailySchedulesProvider(collectionId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schedule duplicated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not duplicate schedule: $error')),
      );
    }
  }

  void _hydrateAssignmentsFromBundle(
    String collectionId,
    WeekScheduleBundle weekBundle,
  ) {
    if (_assignmentsCollectionId != collectionId) {
      _assignmentsCollectionId = collectionId;
      _dayAssignmentsInitialized = false;
    }
    if (_dayAssignmentsInitialized) {
      return;
    }
    _dayAssignments = Map<int, String?>.from(weekBundle.assignmentsByDay);
    _dayAssignmentsInitialized = true;
  }

  void _toggleDayForSchedule(int day, String scheduleId) {
    setState(() {
      if (_dayAssignments[day] == scheduleId) {
        _dayAssignments[day] = null;
      } else {
        _dayAssignments[day] = scheduleId;
      }
    });
  }

  List<String> _assignedShortLabelsForSchedule(String scheduleId) {
    final labels = <String>[];
    for (final day in _daySpecs) {
      if (_dayAssignments[day.day] == scheduleId) {
        labels.add(day.shortLabel);
      }
    }
    return labels;
  }

  Future<void> _saveDayAssignments(
    String collectionId,
    WeekScheduleBundle weekBundle,
  ) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null || collectionId.startsWith('local-')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day assignments saved in preview mode.')),
      );
      return;
    }

    setState(() => _savingDayAssignments = true);
    try {
      await client
          .from('week_schedule_day_assignments')
          .delete()
          .eq('week_schedule_id', weekBundle.weekScheduleId);

      final rows = <Map<String, dynamic>>[];
      _dayAssignments.forEach((day, scheduleId) {
        if (scheduleId == null) {
          return;
        }
        rows.add({
          'week_schedule_id': weekBundle.weekScheduleId,
          'day_of_week': day,
          'daily_schedule_id': scheduleId,
          'priority': 0,
        });
      });

      if (rows.isNotEmpty) {
        await client.from('week_schedule_day_assignments').insert(rows);
      }

      ref.invalidate(weekScheduleBundleProvider(collectionId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Day assignments saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save day assignments: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingDayAssignments = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlant = ref.watch(selectedPlantProvider);
    if (selectedPlant == null) {
      return GpPageScaffold(
        title: 'Schedules',
        body: Center(
          child: GpPrimaryButton(
            label: 'Open Installations',
            icon: Icons.grid_view_outlined,
            onPressed: () => context.go('/installations'),
          ),
        ),
      );
    }

    final collectionId = selectedPlant.activeScheduleCollectionId;
    if (collectionId == null || collectionId.isEmpty) {
      return const GpPageScaffold(
        title: 'Schedules',
        body: Center(
          child: Text('No active schedule collection for this plant.'),
        ),
      );
    }

    final schedulesAsync = ref.watch(dailySchedulesProvider(collectionId));
    final weekBundleAsync = ref.watch(weekScheduleBundleProvider(collectionId));
    return DefaultTabController(
      length: 3,
      child: GpPageScaffold(
        title: 'Daily Schedule Library',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(dailySchedulesProvider(collectionId)),
          ),
        ],
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Templates'),
                Tab(text: 'Active'),
                Tab(text: 'History'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: weekBundleAsync.when(
                data: (weekBundle) {
                  _hydrateAssignmentsFromBundle(collectionId, weekBundle);
                  return schedulesAsync.when(
                    data: (schedules) {
                      if (schedules.isEmpty) {
                        return Center(
                          child: GpPrimaryButton(
                            label: 'Create New Schedule',
                            icon: Icons.add,
                            onPressed: () => _createSchedule(selectedPlant),
                          ),
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final layout = GpResponsiveBreakpoints.layoutForWidth(
                            constraints.maxWidth,
                          );
                          final columns = switch (layout) {
                            GpWindowSize.compact => 1,
                            GpWindowSize.medium => 2,
                            GpWindowSize.expanded =>
                              constraints.maxWidth >= 1100 ? 3 : 2,
                          };

                          const spacing = 10.0;
                          final availableWidth =
                              constraints.maxWidth - ((columns - 1) * spacing);
                          final cardWidth = availableWidth / columns;

                          return ListView(
                            children: [
                              GpSectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Day-of-week assignment',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Set days directly on each schedule card using M T W T F S S buttons.',
                                    ),
                                    const SizedBox(height: 10),
                                    GpPrimaryButton(
                                      label: _savingDayAssignments
                                          ? 'Saving assignments...'
                                          : 'Save Day Assignments',
                                      icon: Icons.save_outlined,
                                      onPressed: _savingDayAssignments
                                          ? null
                                          : () => _saveDayAssignments(
                                              collectionId,
                                              weekBundle,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (layout == GpWindowSize.compact)
                                ...schedules.map(
                                  (schedule) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildScheduleCard(
                                      context,
                                      selectedPlant,
                                      schedule,
                                    ),
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: schedules
                                      .map(
                                        (schedule) => SizedBox(
                                          width: cardWidth,
                                          child: _buildScheduleCard(
                                            context,
                                            selectedPlant,
                                            schedule,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: layout == GpWindowSize.compact
                                    ? double.infinity
                                    : 320,
                                child: GpPrimaryButton(
                                  label: 'Create New Schedule',
                                  icon: Icons.add,
                                  onPressed: () =>
                                      _createSchedule(selectedPlant),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    error: (error, _) =>
                        Center(child: Text('Could not load schedules: $error')),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                  );
                },
                error: (error, _) => Center(
                  child: Text('Could not load day assignments: $error'),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySpec {
  const _DaySpec({
    required this.day,
    required this.shortLabel,
    required this.fullLabel,
  });

  final int day;
  final String shortLabel;
  final String fullLabel;
}
