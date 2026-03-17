import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
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

  Future<void> _confirmAndEndOverride(
    PlantSummary plant,
    ActiveOverrideSnapshot activeOverride,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End temporary override?'),
        content: const Text(
          'This will remove the active override and immediately apply the current schedule settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final client = ref.read(supabaseClientProvider);
    if (client == null || plant.id.startsWith('local-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Override ended in preview mode only.')),
      );
      return;
    }

    setState(() => _applying = true);
    try {
      await client
          .from('overrides')
          .delete()
          .eq('id', activeOverride.id)
          .eq('plant_id', plant.id);

      final desiredRaw = await client.rpc(
        'compute_plant_desired_control',
        params: {
          'p_plant_id': plant.id,
          'p_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      final desiredMap = switch (desiredRaw) {
        List<dynamic> list when list.isNotEmpty =>
          list.first is Map<String, dynamic>
              ? list.first as Map<String, dynamic>
              : null,
        Map<String, dynamic> map => map,
        _ => null,
      };
      final desiredPeak = (desiredMap?['desired_peak_shaving_w'] as num?)
          ?.toInt();
      final desiredGrid = desiredMap?['desired_grid_charging_allowed'] as bool?;
      if (desiredPeak == null || desiredGrid == null) {
        throw StateError('Could not resolve current schedule state.');
      }

      final applyResult = await ref
          .read(providerFunctionsServiceProvider)
          .applyControl(
            plantId: plant.id,
            peakShavingW: desiredPeak,
            gridChargingAllowed: desiredGrid,
          );
      if (!mounted) return;

      final applyOk = applyResult['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            applyOk
                ? 'Temporary override ended. Current schedule applied.'
                : 'Temporary override ended, but schedule apply failed: '
                      '${applyResult['error'] ?? 'Unknown error'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not end override: $error')));
    } finally {
      ref.invalidate(activeOverrideProvider(plant.id));
      ref.invalidate(plantRuntimeProvider(plant.id));
      ref.invalidate(recentControlLogProvider(plant.id));
      if (mounted) {
        setState(() => _applying = false);
      }
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
                            IconButton(
                              tooltip: 'End override',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _applying
                                  ? null
                                  : () => _confirmAndEndOverride(
                                      selectedPlant,
                                      activeOverride,
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                    error: (_, _) => const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                  );
                  final activeCard = _TodayStatusDashboardCard(
                    plant: selectedPlant,
                    currentPeak: currentPeak,
                    currentGrid: currentGrid,
                    nextDueAt: runtime?.nextDueAt,
                    overrideBanner: overrideBanner,
                    batterySocSection: batterySocAsync.when(
                      data: (soc) {
                        if (soc == null) {
                          return const _DashboardMessageCard(
                            title: 'Battery SOC',
                            message: 'Battery SOC unavailable.',
                          );
                        }
                        final percentage = soc.batteryPercentage
                            .clamp(0, 100)
                            .toDouble();
                        final statusColor = percentage >= 60
                            ? AppTheme.primary
                            : (percentage >= 20 ? Colors.orange : Colors.red);
                        return _DashboardBatteryCard(
                          percentageLabel: _formatPercent(percentage),
                          updatedLabel: soc.fetchedAt == null
                              ? null
                              : 'Updated ${_formatDateTime(soc.fetchedAt!)}',
                          value: percentage / 100,
                          statusColor: statusColor,
                        );
                      },
                      error: (error, _) => const _DashboardMessageCard(
                        title: 'Battery SOC',
                        message: 'Battery SOC unavailable.',
                      ),
                      loading: () => const _DashboardLoadingCard(
                        title: 'Battery SOC',
                        message: 'Loading battery SOC...',
                      ),
                    ),
                    onCreateOverride: () => _createOverride(
                      selectedPlant,
                      initialPeakShavingW: manualPeak,
                      initialGridChargingAllowed: manualGridCharging,
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

class _TodayStatusDashboardCard extends StatelessWidget {
  const _TodayStatusDashboardCard({
    required this.plant,
    required this.currentPeak,
    required this.currentGrid,
    required this.nextDueAt,
    required this.overrideBanner,
    required this.batterySocSection,
    required this.onCreateOverride,
  });

  final PlantSummary plant;
  final int currentPeak;
  final bool currentGrid;
  final DateTime? nextDueAt;
  final Widget overrideBanner;
  final Widget batterySocSection;
  final VoidCallback onCreateOverride;

  @override
  Widget build(BuildContext context) {
    const cardBackground = Color(0xFF193322);
    const cardBackgroundDark = Color(0xFF112419);
    const glassBorder = Color(0x3313EC5B);
    const mutedText = Color(0xFF9BB0A1);
    final countdown = _countdownParts(nextDueAt);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardBackground, cardBackgroundDark],
        ),
        border: Border.all(color: glassBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x2213EC5B),
            blurRadius: 24,
            spreadRadius: -8,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active control',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: mutedText,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'System Status',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                _DashboardPill(
                  icon: plant.scheduleControlEnabled
                      ? Icons.check_circle
                      : Icons.pause_circle,
                  label: plant.scheduleControlEnabled
                      ? 'Schedule Enabled'
                      : 'Schedule Paused',
                  active: plant.scheduleControlEnabled,
                ),
              ],
            ),
            if (overrideBanner is! SizedBox) ...[
              const SizedBox(height: 14),
              overrideBanner,
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DashboardMetric(
                    icon: Icons.bolt,
                    accentColor: AppTheme.primary,
                    label: 'Peak Shaving',
                    value: '$currentPeak',
                    unit: 'W',
                    footnote: plant.scheduleControlEnabled
                        ? 'Schedule active'
                        : 'Manual-only mode',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashboardMetric(
                    icon: currentGrid ? Icons.electrical_services : Icons.lock,
                    accentColor: currentGrid ? AppTheme.primary : mutedText,
                    label: 'Grid Charging',
                    value: currentGrid ? 'Allowed' : 'Blocked',
                    footnote: currentGrid
                        ? 'Charging window open'
                        : 'Economy mode',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            batterySocSection,
            const SizedBox(height: 20),
            Text(
              'Next change in',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: mutedText,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CountdownTile(
                    value: countdown.hours,
                    label: 'Hours',
                    emphasize: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CountdownTile(
                    value: countdown.minutes,
                    label: 'Minutes',
                    emphasize: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CountdownTile(
                    value: countdown.seconds,
                    label: 'Seconds',
                    emphasize: false,
                  ),
                ),
              ],
            ),
            if (nextDueAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Scheduled for ${_formatDashboardDateTime(nextDueAt!)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: mutedText),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'No scheduled change is available right now.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: mutedText),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreateOverride,
                icon: const Icon(Icons.touch_app),
                label: const Text('Temporary Override'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.backgroundDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _CountdownParts _countdownParts(DateTime? nextDueAt) {
    if (nextDueAt == null) {
      return const _CountdownParts('00', '00', '00');
    }
    final remaining = nextDueAt.toLocal().difference(DateTime.now());
    if (remaining.isNegative) {
      return const _CountdownParts('00', '00', '00');
    }
    final totalSeconds = remaining.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return _CountdownParts(
      hours.toString().padLeft(2, '0'),
      minutes.toString().padLeft(2, '0'),
      seconds.toString().padLeft(2, '0'),
    );
  }

  static String _formatDashboardDateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.icon,
    required this.accentColor,
    required this.label,
    required this.value,
    required this.footnote,
    this.unit,
  });

  final IconData icon;
  final Color accentColor;
  final String label;
  final String value;
  final String footnote;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9BB0A1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            footnote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: accentColor.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBatteryCard extends StatelessWidget {
  const _DashboardBatteryCard({
    required this.percentageLabel,
    required this.updatedLabel,
    required this.value,
    required this.statusColor,
  });

  final String percentageLabel;
  final String? updatedLabel;
  final double value;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Battery SOC',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF9BB0A1),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.battery_charging_full_outlined,
                      size: 22,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        percentageLabel,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              if (updatedLabel != null) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    updatedLabel!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9BB0A1),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              color: statusColor,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingCard extends StatelessWidget {
  const _DashboardLoadingCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title\n$message',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMessageCard extends StatelessWidget {
  const _DashboardMessageCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF9BB0A1),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _DashboardPill extends StatelessWidget {
  const _DashboardPill({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppTheme.primary : const Color(0xFFFFC266);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: foreground.withValues(alpha: 0.14),
        border: Border.all(color: foreground.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownTile extends StatelessWidget {
  const _CountdownTile({
    required this.value,
    required this.label,
    required this.emphasize,
  });

  final String value;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: emphasize
              ? AppTheme.primary.withValues(alpha: 0.26)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: emphasize ? AppTheme.primary : Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF9BB0A1),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownParts {
  const _CountdownParts(this.hours, this.minutes, this.seconds);

  final String hours;
  final String minutes;
  final String seconds;
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
