import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/schedules_provider.dart';

class EditSchedulePage extends ConsumerStatefulWidget {
  const EditSchedulePage({required this.scheduleId, super.key});

  final String scheduleId;

  @override
  ConsumerState<EditSchedulePage> createState() => _EditSchedulePageState();
}

class _EditSchedulePageState extends ConsumerState<EditSchedulePage> {
  final _nameController = TextEditingController();
  final List<_SegmentDraft> _segments = [];
  bool _initialized = false;
  bool _isSaving = false;

  static final List<String> _timeOptions = List<String>.generate(96, (index) {
    final hour = index ~/ 4;
    final minute = (index % 4) * 15;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
  });

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initializeFrom(DailyScheduleDetail detail) {
    if (_initialized) return;
    _nameController.text = detail.name;
    _segments
      ..clear()
      ..addAll(
        detail.segments
            .map(
              (segment) => _SegmentDraft(
                startTime: segment.startTime,
                endTime: segment.endTime,
                peakShavingW: segment.peakShavingW,
                gridChargingAllowed: segment.gridChargingAllowed,
              ),
            )
            .toList(),
      );
    if (_segments.isEmpty) {
      _segments.add(
        _SegmentDraft(
          startTime: '00:00:00',
          endTime: '00:15:00',
          peakShavingW: 0,
          gridChargingAllowed: false,
        ),
      );
    }
    _initialized = true;
  }

  void _addSegment() {
    setState(() {
      final previousEnd = _segments.isEmpty
          ? '00:00:00'
          : _segments.last.endTime;
      final nextIndex = (_timeOptions.indexOf(previousEnd) + 1).clamp(
        1,
        _timeOptions.length - 1,
      );
      _segments.add(
        _SegmentDraft(
          startTime: previousEnd,
          endTime: _timeOptions[nextIndex],
          peakShavingW: 0,
          gridChargingAllowed: false,
        ),
      );
    });
  }

  String? _validate() {
    if (_nameController.text.trim().isEmpty) {
      return 'Schedule name is required.';
    }
    if (_segments.isEmpty) {
      return 'At least one segment is required.';
    }
    for (var i = 0; i < _segments.length; i++) {
      final segment = _segments[i];
      if (!_timeOptions.contains(segment.startTime) ||
          !_timeOptions.contains(segment.endTime)) {
        return 'Segment ${i + 1} has invalid 15-minute alignment.';
      }
      if (segment.startTime.compareTo(segment.endTime) >= 0) {
        return 'Segment ${i + 1} start time must be before end time.';
      }
      if (segment.peakShavingW < 0 || segment.peakShavingW % 100 != 0) {
        return 'Segment ${i + 1} peak shaving must be non-negative in 100W steps.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final client = ref.read(supabaseClientProvider);
    if (client == null || widget.scheduleId.startsWith('local-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved in preview mode only.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await client
          .from('daily_schedules')
          .update({'name': _nameController.text.trim()})
          .eq('id', widget.scheduleId);

      final payload = <Map<String, dynamic>>[];
      for (var i = 0; i < _segments.length; i++) {
        payload.add(
          TimeSegmentModel(
            startTime: _segments[i].startTime,
            endTime: _segments[i].endTime,
            peakShavingW: _segments[i].peakShavingW,
            gridChargingAllowed: _segments[i].gridChargingAllowed,
            sortOrder: i,
          ).toRpcJson(),
        );
      }
      await client.rpc(
        'replace_daily_schedule_segments',
        params: {
          'p_daily_schedule_id': widget.scheduleId,
          'p_segments': payload,
        },
      );

      ref.invalidate(dailyScheduleDetailProvider(widget.scheduleId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schedule saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save schedule: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteSchedule() async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete schedule?'),
        content: const Text(
          'This removes the schedule and unassigns it from any days in weekly assignments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (isConfirmed != true) return;

    final client = ref.read(supabaseClientProvider);
    if (client == null || widget.scheduleId.startsWith('local-')) {
      if (!mounted) return;
      context.go('/schedules');
      return;
    }
    try {
      await client.rpc(
        'delete_daily_schedule_with_unassign',
        params: {'p_daily_schedule_id': widget.scheduleId},
      );
      ref.invalidate(dailyScheduleDetailProvider(widget.scheduleId));
      if (!mounted) return;
      context.go('/schedules');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete schedule: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      dailyScheduleDetailProvider(widget.scheduleId),
    );

    return GpPageScaffold(
      title: 'Edit Daily Schedule',
      showBack: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _deleteSchedule,
        ),
      ],
      body: detailAsync.when(
        data: (detail) {
          _initializeFrom(detail);
          return ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Schedule name'),
              ),
              const SizedBox(height: 12),
              ..._segments.asMap().entries.map((entry) {
                final index = entry.key;
                final segment = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GpSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Segment ${index + 1}'),
                            const Spacer(),
                            IconButton(
                              onPressed: _segments.length == 1
                                  ? null
                                  : () => setState(
                                      () => _segments.removeAt(index),
                                    ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: segment.startTime,
                                decoration: const InputDecoration(
                                  labelText: 'Start',
                                ),
                                items: _timeOptions
                                    .map(
                                      (time) => DropdownMenuItem(
                                        value: time,
                                        child: Text(time.substring(0, 5)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => segment.startTime = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: segment.endTime,
                                decoration: const InputDecoration(
                                  labelText: 'End',
                                ),
                                items: _timeOptions
                                    .where(
                                      (option) =>
                                          option.compareTo(segment.startTime) >
                                          0,
                                    )
                                    .map(
                                      (time) => DropdownMenuItem(
                                        value: time,
                                        child: Text(time.substring(0, 5)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => segment.endTime = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          initialValue: segment.peakShavingW.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Peak shaving (W, 100-step)',
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null) {
                              segment.peakShavingW = parsed;
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Allow grid charging'),
                          value: segment.gridChargingAllowed,
                          onChanged: (value) => setState(
                            () => segment.gridChargingAllowed = value,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: _addSegment,
                icon: const Icon(Icons.add),
                label: const Text('Add New Segment'),
              ),
              const SizedBox(height: 12),
              GpPrimaryButton(
                label: _isSaving ? 'Saving...' : 'Save',
                icon: Icons.save_outlined,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          );
        },
        error: (error, _) =>
            Center(child: Text('Could not load schedule: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SegmentDraft {
  _SegmentDraft({
    required this.startTime,
    required this.endTime,
    required this.peakShavingW,
    required this.gridChargingAllowed,
  });

  String startTime;
  String endTime;
  int peakShavingW;
  bool gridChargingAllowed;
}
