import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_responsive.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/plants_provider.dart';
import '../../data/provider_functions_service.dart';

DateTime ceilToQuarterHour(DateTime value) {
  final normalized = DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
  );
  final remainder = normalized.minute % 15;
  if (remainder == 0) {
    return normalized;
  }
  return normalized.add(Duration(minutes: 15 - remainder));
}

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  bool _applying = false;
  int? _manualPeak;
  bool? _manualGridCharging;
  String? _manualSeedPlantId;
  Timer? _activeControlRefreshTimer;
  String? _activeRefreshPlantId;

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatPercent(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return '${rounded.toInt()}%';
    }
    return '${value.toStringAsFixed(1)}%';
  }

  void _seedManualValuesIfNeeded({
    required String plantId,
    required int peakShavingW,
    required bool gridChargingAllowed,
  }) {
    if (_manualSeedPlantId == plantId &&
        _manualPeak != null &&
        _manualGridCharging != null) {
      return;
    }
    _manualSeedPlantId = plantId;
    _manualPeak = peakShavingW;
    _manualGridCharging = gridChargingAllowed;
  }

  void _startActiveControlAutoRefresh(String plantId) {
    if (_activeRefreshPlantId == plantId &&
        _activeControlRefreshTimer != null) {
      return;
    }
    _activeControlRefreshTimer?.cancel();
    _activeRefreshPlantId = plantId;
    _activeControlRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) {
      if (!mounted) return;
      ref.invalidate(plantRuntimeProvider(plantId));
      ref.invalidate(activeOverrideProvider(plantId));
    });
  }

  @override
  void dispose() {
    _activeControlRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _applyNow(
    PlantSummary plant, {
    required int peakShavingW,
    required bool gridChargingAllowed,
  }) async {
    setState(() => _applying = true);
    try {
      final result = await ref
          .read(providerFunctionsServiceProvider)
          .applyControl(
            plantId: plant.id,
            peakShavingW: peakShavingW,
            gridChargingAllowed: gridChargingAllowed,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['ok'] == true
                ? 'Apply sent to provider.'
                : 'Apply failed: ${result['error'] ?? 'Unknown error'}',
          ),
        ),
      );
      ref.invalidate(plantRuntimeProvider(plant.id));
      ref.invalidate(recentControlLogProvider(plant.id));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Apply failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  Future<void> _createOverride(
    PlantSummary plant, {
    required int initialPeakShavingW,
    required bool initialGridChargingAllowed,
  }) async {
    final result = await showDialog<_OverrideValues>(
      context: context,
      builder: (_) => _OverrideDialog(
        initialPeakShavingW: initialPeakShavingW,
        initialGridChargingAllowed: initialGridChargingAllowed,
      ),
    );
    if (result == null) {
      return;
    }

    final client = ref.read(supabaseClientProvider);
    if (client == null || plant.id.startsWith('local-')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Override saved in preview mode only.')),
      );
      return;
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      await client.from('overrides').insert({
        'plant_id': plant.id,
        'created_by_auth_user_id': userId,
        'starts_at': result.startsAt.toUtc().toIso8601String(),
        'ends_at': result.endsAt?.toUtc().toIso8601String(),
        'until_next_segment': result.untilNextSegment,
        'peak_shaving_w': result.peakShavingW,
        'grid_charging_allowed': result.gridChargingAllowed,
        'is_active': true,
      });
      var message = result.startsNow
          ? 'Temporary override created. Applying now...'
          : 'Temporary override scheduled.';

      if (result.startsNow) {
        final applyResult = await ref
            .read(providerFunctionsServiceProvider)
            .applyControl(
              plantId: plant.id,
              peakShavingW: result.peakShavingW,
              gridChargingAllowed: result.gridChargingAllowed,
            );
        final applyOk = applyResult['ok'] == true;
        message = applyOk
            ? 'Temporary override created and applied now.'
            : 'Temporary override created, but immediate apply failed: '
                  '${applyResult['error'] ?? 'Unknown error'}';
        if (applyOk) {
          ref.invalidate(recentControlLogProvider(plant.id));
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      ref.invalidate(activeOverrideProvider(plant.id));
      ref.invalidate(plantRuntimeProvider(plant.id));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create override: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(plantsProvider);
    final selectedPlant = ref.watch(selectedPlantProvider);

    return GpPageScaffold(
      title: "Today's Status",
      actions: [
        IconButton(
          icon: const Icon(Icons.location_city_outlined),
          onPressed: () => context.go('/installations'),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(plantsProvider);
            if (selectedPlant != null) {
              ref.invalidate(plantRuntimeProvider(selectedPlant.id));
              ref.invalidate(recentControlLogProvider(selectedPlant.id));
              ref.invalidate(plantBatterySocProvider(selectedPlant.id));
              ref.invalidate(activeOverrideProvider(selectedPlant.id));
            }
          },
        ),
      ],
      body: plantsAsync.when(
        data: (plants) {
          if (plants.isEmpty || selectedPlant == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No installation selected.'),
                  const SizedBox(height: 12),
                  GpPrimaryButton(
                    label: 'Open Installations',
                    icon: Icons.grid_view_outlined,
                    onPressed: () => context.go('/installations'),
                  ),
                ],
              ),
            );
          }

          _startActiveControlAutoRefresh(selectedPlant.id);

          final runtimeAsync = ref.watch(
            plantRuntimeProvider(selectedPlant.id),
          );
          final activeOverrideAsync = ref.watch(
            activeOverrideProvider(selectedPlant.id),
          );
          final logAsync = ref.watch(
            recentControlLogProvider(selectedPlant.id),
          );
          final batterySocAsync = ref.watch(
            plantBatterySocProvider(selectedPlant.id),
          );

          return ListView(
            padding: const EdgeInsets.only(top: 8),
            children: [
              DropdownMenu<String>(
                key: ValueKey('plant-selector-${selectedPlant.id}'),
                initialSelection: selectedPlant.id,
                label: const Text('Installation'),
                dropdownMenuEntries: plants
                    .map(
                      (plant) => DropdownMenuEntry<String>(
                        value: plant.id,
                        label: plant.name,
                      ),
                    )
                    .toList(),
                onSelected: (value) {
                  if (value != null) {
                    _manualSeedPlantId = null;
                    _manualPeak = null;
                    _manualGridCharging = null;
                    ref
                        .read(selectedPlantIdProvider.notifier)
                        .setSelected(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              runtimeAsync.when(
                data: (runtime) {
                  final currentPeak =
                      runtime?.lastAppliedPeakShavingW ??
                      selectedPlant.defaultPeakShavingW;
                  final currentGrid =
                      runtime?.lastAppliedGridChargingAllowed ??
                      selectedPlant.defaultGridChargingAllowed;
                  _seedManualValuesIfNeeded(
                    plantId: selectedPlant.id,
                    peakShavingW: currentPeak,
                    gridChargingAllowed: currentGrid,
                  );
                  final manualPeak = _manualPeak ?? currentPeak;
                  final manualGridCharging = _manualGridCharging ?? currentGrid;
                  final overrideBanner = activeOverrideAsync.when(
                    data: (activeOverride) {
                      if (activeOverride == null) {
                        return const SizedBox.shrink();
                      }
                      final endsAt =
                          activeOverride.endsAt ?? runtime?.nextDueAt;
                      final endsLabel = endsAt == null
                          ? 'Pending next refresh'
                          : _formatDateTime(endsAt);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.timer_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Temporary override active',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Ends at: $endsLabel'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    error: (_, _) => const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                  );
                  final activeCard = GpSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active control',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        overrideBanner,
                        Text('Peak shaving: $currentPeak W'),
                        const SizedBox(height: 4),
                        Text(
                          'Grid charging: ${currentGrid ? 'Allowed' : 'Blocked'}',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Battery SOC',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        batterySocAsync.when(
                          data: (soc) {
                            if (soc == null) {
                              return const Text('Battery SOC unavailable.');
                            }
                            final percentage = soc.batteryPercentage
                                .clamp(0, 100)
                                .toDouble();
                            final statusColor = percentage >= 60
                                ? Colors.green
                                : (percentage >= 20
                                      ? Colors.orange
                                      : Colors.red);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.battery_charging_full_outlined,
                                      size: 18,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatPercent(percentage),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    minHeight: 10,
                                    color: statusColor,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                                if (soc.fetchedAt != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Updated ${_formatDateTime(soc.fetchedAt!)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            );
                          },
                          error: (error, _) =>
                              const Text('Battery SOC unavailable.'),
                          loading: () => const Row(
                            children: [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Loading battery SOC...'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selectedPlant.scheduleControlEnabled
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedPlant.scheduleControlEnabled
                                    ? Icons.check_circle_outline
                                    : Icons.pause_circle_outline,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedPlant.scheduleControlEnabled
                                      ? 'Schedule control is enabled.'
                                      : 'Schedule control is disabled. Manual apply still works.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (runtime?.nextDueAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Next change: ${_formatDateTime(runtime!.nextDueAt!)}',
                          ),
                        ],
                      ],
                    ),
                  );

                  final manualCard = GpSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual apply now',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Peak shaving $manualPeak W'),
                        Slider(
                          min: 0,
                          max: 10000,
                          divisions: 100,
                          value: manualPeak.toDouble(),
                          onChanged: (value) => setState(() {
                            _manualPeak = (value ~/ 100) * 100;
                          }),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Allow grid charging'),
                          value: manualGridCharging,
                          onChanged: (value) =>
                              setState(() => _manualGridCharging = value),
                        ),
                        const SizedBox(height: 8),
                        GpPrimaryButton(
                          label: _applying ? 'Applying...' : 'Apply Now',
                          icon: Icons.bolt_outlined,
                          onPressed: _applying
                              ? null
                              : () => _applyNow(
                                  selectedPlant,
                                  peakShavingW: manualPeak,
                                  gridChargingAllowed: manualGridCharging,
                                ),
                        ),
                        const SizedBox(height: 8),
                        GpSecondaryButton(
                          label: 'Temporary Override',
                          icon: Icons.timer_outlined,
                          onPressed: () => _createOverride(
                            selectedPlant,
                            initialPeakShavingW: manualPeak,
                            initialGridChargingAllowed: manualGridCharging,
                          ),
                        ),
                      ],
                    ),
                  );

                  final isCompact = context.isCompact;
                  return Column(
                    children: [
                      if (isCompact) ...[
                        activeCard,
                        const SizedBox(height: 12),
                        manualCard,
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: activeCard),
                            const SizedBox(width: 12),
                            Expanded(child: manualCard),
                          ],
                        ),
                    ],
                  );
                },
                error: (error, _) => GpSectionCard(
                  child: Text('Could not load runtime data: $error'),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 12),
              GpSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Timeline",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    logAsync.when(
                      data: (entries) {
                        if (entries.isEmpty) {
                          return const Text('No apply log yet.');
                        }
                        return Column(
                          children: entries
                              .map(
                                (entry) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    entry.providerResult == 'success'
                                        ? Icons.check_circle_outline
                                        : Icons.error_outline,
                                  ),
                                  title: Text(
                                    '${entry.requestedPeakShavingW} W • '
                                    '${entry.requestedGridChargingAllowed ? 'Grid ON' : 'Grid OFF'}',
                                  ),
                                  subtitle: Text(
                                    _formatDateTime(entry.attemptedAt),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                      error: (error, _) => Text('Could not load log: $error'),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        error: (error, _) =>
            Center(child: Text('Could not load installations: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _OverrideValues {
  const _OverrideValues({
    required this.startsAt,
    required this.startsNow,
    required this.peakShavingW,
    required this.gridChargingAllowed,
    required this.untilNextSegment,
    this.endsAt,
  });

  final DateTime startsAt;
  final bool startsNow;
  final int peakShavingW;
  final bool gridChargingAllowed;
  final bool untilNextSegment;
  final DateTime? endsAt;
}

class _OverrideDialog extends StatefulWidget {
  const _OverrideDialog({
    required this.initialPeakShavingW,
    required this.initialGridChargingAllowed,
  });

  final int initialPeakShavingW;
  final bool initialGridChargingAllowed;

  @override
  State<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<_OverrideDialog> {
  late int _peakShavingW = widget.initialPeakShavingW;
  late bool _gridChargingAllowed = widget.initialGridChargingAllowed;
  bool _startsNow = true;
  DateTime? _startsAt;
  bool _untilNextSegment = true;
  DateTime? _endsAt;

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<DateTime?> _pickQuarterDateTime({
    required DateTime firstDateTime,
    required DateTime initialDateTime,
    required DateTime lastDateTime,
  }) async {
    final normalizedInitial = initialDateTime.isBefore(firstDateTime)
        ? firstDateTime
        : (initialDateTime.isAfter(lastDateTime)
              ? lastDateTime
              : initialDateTime);
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: firstDateTime,
      lastDate: lastDateTime,
      initialDate: normalizedInitial,
    );
    if (pickedDate == null || !mounted) {
      return null;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: normalizedInitial.hour,
        minute: normalizedInitial.minute,
      ),
    );
    if (pickedTime == null || !mounted) {
      return null;
    }

    var snapped = ceilToQuarterHour(
      DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
    );
    if (snapped.isBefore(firstDateTime)) {
      snapped = ceilToQuarterHour(firstDateTime);
    }
    if (snapped.isAfter(lastDateTime)) {
      snapped = lastDateTime;
    }
    return snapped;
  }

  DateTime _effectiveStartForValidation() {
    if (_startsNow) {
      return DateTime.now();
    }
    return _startsAt ?? DateTime.now();
  }

  String? _validationMessage() {
    if (!_startsNow && _startsAt == null) {
      return 'Pick a start time.';
    }
    if (!_untilNextSegment) {
      if (_endsAt == null) {
        return 'Pick an end time.';
      }
      final startsAt = _effectiveStartForValidation();
      if (!_endsAt!.isAfter(startsAt)) {
        return 'End time must be after start time.';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final validationMessage = _validationMessage();
    final canApply = validationMessage == null;
    return AlertDialog(
      title: const Text('Temporary override'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start time'),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: true, label: Text('Start now')),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Start at specific time'),
                ),
              ],
              selected: {_startsNow},
              onSelectionChanged: (selection) {
                final startsNow = selection.first;
                setState(() {
                  _startsNow = startsNow;
                  if (_startsNow) {
                    _startsAt = null;
                  }
                });
              },
            ),
            if (!_startsNow)
              TextButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final firstStart = ceilToQuarterHour(now);
                  final lastStart = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    23,
                    45,
                  ).add(const Duration(days: 7));
                  final picked = await _pickQuarterDateTime(
                    firstDateTime: firstStart,
                    initialDateTime: _startsAt ?? firstStart,
                    lastDateTime: lastStart,
                  );
                  if (picked == null) {
                    return;
                  }
                  setState(() {
                    _startsAt = picked;
                    if (_endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
                      _endsAt = null;
                    }
                  });
                },
                icon: const Icon(Icons.schedule),
                label: Text(
                  _startsAt == null
                      ? 'Pick start time'
                      : _formatDateTime(_startsAt!),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Times use 15-minute steps.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text('Peak shaving $_peakShavingW W'),
            Slider(
              min: 0,
              max: 10000,
              divisions: 100,
              value: _peakShavingW.toDouble(),
              onChanged: (value) =>
                  setState(() => _peakShavingW = (value ~/ 100) * 100),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow grid charging'),
              value: _gridChargingAllowed,
              onChanged: (value) =>
                  setState(() => _gridChargingAllowed = value),
            ),
            const SizedBox(height: 8),
            const Text('Duration'),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Until next segment'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Until specific time'),
                ),
              ],
              selected: {_untilNextSegment},
              onSelectionChanged: (selection) {
                final nextValue = selection.first;
                setState(() {
                  _untilNextSegment = nextValue;
                  if (_untilNextSegment) {
                    _endsAt = null;
                  }
                });
              },
            ),
            if (!_untilNextSegment)
              TextButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final firstEnd = ceilToQuarterHour(
                    _effectiveStartForValidation().add(
                      const Duration(minutes: 1),
                    ),
                  );
                  final lastEnd = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    23,
                    45,
                  ).add(const Duration(days: 7));
                  final picked = await _pickQuarterDateTime(
                    firstDateTime: firstEnd,
                    initialDateTime: _endsAt ?? firstEnd,
                    lastDateTime: lastEnd,
                  );
                  if (picked == null) {
                    return;
                  }
                  setState(() {
                    _endsAt = picked;
                  });
                },
                icon: const Icon(Icons.schedule),
                label: Text(
                  _endsAt == null ? 'Pick end time' : _formatDateTime(_endsAt!),
                ),
              ),
            if (validationMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                validationMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canApply
              ? () {
                  final startsAt = _startsNow ? DateTime.now() : _startsAt!;
                  final endsAt = _untilNextSegment ? null : _endsAt;
                  Navigator.of(context).pop(
                    _OverrideValues(
                      startsAt: startsAt,
                      startsNow: _startsNow,
                      peakShavingW: _peakShavingW,
                      gridChargingAllowed: _gridChargingAllowed,
                      untilNextSegment: _untilNextSegment,
                      endsAt: endsAt,
                    ),
                  );
                }
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
