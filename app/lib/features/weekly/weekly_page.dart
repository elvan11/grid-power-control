import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/plants_provider.dart';
import '../../data/schedules_provider.dart';

class WeeklyPage extends ConsumerStatefulWidget {
  const WeeklyPage({super.key});

  @override
  ConsumerState<WeeklyPage> createState() => _WeeklyPageState();
}

class _WeeklyPageState extends ConsumerState<WeeklyPage> {
  Map<int, String?> _assignments = {};
  bool _initialized = false;
  bool _saving = false;

  static const _days = <int, String>{
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  void _initializeFromBundle(WeekScheduleBundle bundle) {
    if (_initialized) {
      return;
    }
    _assignments = Map<int, String?>.from(bundle.assignmentsByDay);
    _initialized = true;
  }

  Future<void> _saveAssignments(
    PlantSummary plant,
    WeekScheduleBundle bundle,
  ) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null || plant.id.startsWith('local-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved in preview mode only.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await client
          .from('week_schedule_day_assignments')
          .delete()
          .eq('week_schedule_id', bundle.weekScheduleId);

      final rows = <Map<String, dynamic>>[];
      _assignments.forEach((day, scheduleId) {
        if (scheduleId == null) {
          return;
        }
        rows.add({
          'week_schedule_id': bundle.weekScheduleId,
          'day_of_week': day,
          'daily_schedule_id': scheduleId,
          'priority': 0,
        });
      });
      if (rows.isNotEmpty) {
        await client.from('week_schedule_day_assignments').insert(rows);
      }
      ref.invalidate(
        weekScheduleBundleProvider(plant.activeScheduleCollectionId!),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly assignments saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save assignments: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlant = ref.watch(selectedPlantProvider);
    if (selectedPlant == null ||
        selectedPlant.activeScheduleCollectionId == null) {
      return const GpPageScaffold(
        title: 'Weekly Planner',
        body: Center(child: Text('Select an installation first.')),
      );
    }

    final collectionId = selectedPlant.activeScheduleCollectionId!;
    final schedulesAsync = ref.watch(dailySchedulesProvider(collectionId));
    final weekBundleAsync = ref.watch(weekScheduleBundleProvider(collectionId));

    return GpPageScaffold(
      title: 'Weekly Planner',
      body: weekBundleAsync.when(
        data: (bundle) {
          _initializeFromBundle(bundle);
          return schedulesAsync.when(
            data: (schedules) {
              return ListView(
                children: [
                  GpSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Assign',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        GpSecondaryButton(
                          label: 'Apply Monday to Mon-Fri',
                          icon: Icons.repeat,
                          onPressed: () {
                            final monday = _assignments[1];
                            setState(() {
                              for (var day = 1; day <= 5; day++) {
                                _assignments[day] = monday;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._days.entries.map(
                    (day) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GpSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day.value,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String?>(
                              value: _assignments[day.key],
                              decoration: const InputDecoration(
                                labelText: 'Assigned schedule',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Use plant defaults'),
                                ),
                                ...schedules.map(
                                  (schedule) => DropdownMenuItem<String?>(
                                    value: schedule.id,
                                    child: Text(schedule.name),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _assignments[day.key] = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GpPrimaryButton(
                    label: _saving ? 'Applying...' : 'Apply Changes',
                    icon: Icons.check,
                    onPressed: _saving
                        ? null
                        : () => _saveAssignments(selectedPlant, bundle),
                  ),
                ],
              );
            },
            error: (error, _) =>
                Center(child: Text('Could not load schedules: $error')),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
        error: (error, _) =>
            Center(child: Text('Could not load weekly assignments: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
