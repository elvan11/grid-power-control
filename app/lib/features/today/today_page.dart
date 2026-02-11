import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_responsive.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/plants_provider.dart';
import '../../data/provider_functions_service.dart';

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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
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
        'starts_at': DateTime.now().toUtc().toIso8601String(),
        'ends_at': result.endsAt?.toUtc().toIso8601String(),
        'until_next_segment': result.untilNextSegment,
        'peak_shaving_w': result.peakShavingW,
        'grid_charging_allowed': result.gridChargingAllowed,
        'is_active': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Temporary override created.')),
      );
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

          final runtimeAsync = ref.watch(
            plantRuntimeProvider(selectedPlant.id),
          );
          final logAsync = ref.watch(
            recentControlLogProvider(selectedPlant.id),
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
                        Text('Peak shaving: $currentPeak W'),
                        const SizedBox(height: 4),
                        Text(
                          'Grid charging: ${currentGrid ? 'Allowed' : 'Blocked'}',
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
    required this.peakShavingW,
    required this.gridChargingAllowed,
    required this.untilNextSegment,
    this.endsAt,
  });

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
  bool _untilNextSegment = true;
  DateTime? _endsAt;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Temporary override'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  final pickedDate = await showDatePicker(
                    context: context,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 7)),
                    initialDate: now,
                  );
                  if (pickedDate == null || !context.mounted) return;
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (pickedTime == null || !context.mounted) return;
                  setState(() {
                    _endsAt = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                  });
                },
                icon: const Icon(Icons.schedule),
                label: Text(
                  _endsAt == null ? 'Pick end time' : _endsAt.toString(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_untilNextSegment && _endsAt == null) {
              return;
            }
            Navigator.of(context).pop(
              _OverrideValues(
                peakShavingW: _peakShavingW,
                gridChargingAllowed: _gridChargingAllowed,
                untilNextSegment: _untilNextSegment,
                endsAt: _endsAt,
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
