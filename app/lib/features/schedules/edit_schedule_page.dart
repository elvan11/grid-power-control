import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_responsive.dart';
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

  static const String _endOfDayTime = '24:00:00';

  static final List<String> _startTimeOptions = List<String>.generate(96, (
    index,
  ) {
    final hour = index ~/ 4;
    final minute = (index % 4) * 15;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
  });

  static final List<String> _endTimeOptions = <String>[
    ..._startTimeOptions,
    _endOfDayTime,
  ];

  static int _minutesOf(String value) {
    if (value == _endOfDayTime) {
      return 24 * 60;
    }
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  static String _displayTime(String value) {
    if (value == _endOfDayTime) {
      return '00:00';
    }
    return value.substring(0, 5);
  }

  static String _nextEndAfter(String startTime) {
    final index = _endTimeOptions.indexOf(startTime);
    final nextIndex = (index + 1).clamp(1, _endTimeOptions.length - 1);
    return _endTimeOptions[nextIndex];
  }

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
      if (previousEnd == _endOfDayTime) {
        return;
      }
      _segments.add(
        _SegmentDraft(
          startTime: previousEnd,
          endTime: _nextEndAfter(previousEnd),
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
      if (!_startTimeOptions.contains(segment.startTime) ||
          !_endTimeOptions.contains(segment.endTime)) {
        return 'Segment ${i + 1} has invalid 15-minute alignment.';
      }
      if (_minutesOf(segment.startTime) >= _minutesOf(segment.endTime)) {
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
      backFallbackRoute: '/schedules',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _deleteSchedule,
        ),
      ],
      body: detailAsync.when(
        data: (detail) {
          _initializeFrom(detail);
          return LayoutBuilder(
            builder: (context, constraints) {
              final layout = GpResponsiveBreakpoints.layoutForWidth(
                constraints.maxWidth,
              );
              final isCompact = layout == GpWindowSize.compact;

              return ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Schedule name',
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: 12),
                    GpSectionCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_segments.length} segment${_segments.length == 1 ? '' : 's'} configured',
                            ),
                          ),
                          Text(
                            '15-minute boundaries',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
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
                                  child: DropdownMenu<String>(
                                    key: ValueKey(
                                      'start-$index-${segment.startTime}',
                                    ),
                                    initialSelection: segment.startTime,
                                    label: const Text('Start'),
                                    dropdownMenuEntries: _startTimeOptions
                                        .map(
                                          (time) => DropdownMenuEntry<String>(
                                            value: time,
                                            label: _displayTime(time),
                                          ),
                                        )
                                        .toList(),
                                    onSelected: (value) {
                                      if (value != null) {
                                        setState(() {
                                          segment.startTime = value;
                                          if (_minutesOf(segment.endTime) <=
                                              _minutesOf(value)) {
                                            segment.endTime = _nextEndAfter(
                                              value,
                                            );
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownMenu<String>(
                                    key: ValueKey(
                                      'end-$index-${segment.endTime}-${segment.startTime}',
                                    ),
                                    initialSelection: segment.endTime,
                                    label: const Text('End'),
                                    dropdownMenuEntries: _endTimeOptions
                                        .where(
                                          (option) =>
                                              _minutesOf(option) >
                                              _minutesOf(segment.startTime),
                                        )
                                        .map(
                                          (time) => DropdownMenuEntry<String>(
                                            value: time,
                                            label: _displayTime(time),
                                          ),
                                        )
                                        .toList(),
                                    onSelected: (value) {
                                      if (value != null) {
                                        setState(() => segment.endTime = value);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
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
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Allow grid charging'),
                                ),
                                Switch(
                                  value: segment.gridChargingAllowed,
                                  onChanged: (value) => setState(
                                    () => segment.gridChargingAllowed = value,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (isCompact)
                    OutlinedButton.icon(
                      onPressed:
                          _segments.isNotEmpty &&
                              _segments.last.endTime == _endOfDayTime
                          ? null
                          : _addSegment,
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Segment'),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _segments.isNotEmpty &&
                                    _segments.last.endTime == _endOfDayTime
                                ? null
                                : _addSegment,
                            icon: const Icon(Icons.add),
                            label: const Text('Add New Segment'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GpPrimaryButton(
                            label: _isSaving ? 'Saving...' : 'Save',
                            icon: Icons.save_outlined,
                            onPressed: _isSaving ? null : _save,
                          ),
                        ),
                      ],
                    ),
                  if (isCompact) ...[
                    const SizedBox(height: 12),
                    GpPrimaryButton(
                      label: _isSaving ? 'Saving...' : 'Save',
                      icon: Icons.save_outlined,
                      onPressed: _isSaving ? null : _save,
                    ),
                  ],
                ],
              );
            },
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
