import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_responsive.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/plants_provider.dart';

class InstallationsPage extends ConsumerWidget {
  const InstallationsPage({super.key});

  Widget _buildPlantCard(
    BuildContext context,
    WidgetRef ref,
    PlantSummary plant,
  ) {
    return GpSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plant.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cloud settings',
                onPressed: () {
                  ref
                      .read(selectedPlantIdProvider.notifier)
                      .setSelected(plant.id);
                  context.go('/installations/${plant.id}/connect-service');
                },
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Time zone: ${plant.timeZone}'),
          const SizedBox(height: 4),
          Text(
            'Defaults: ${plant.defaultPeakShavingW} W, '
            '${plant.defaultGridChargingAllowed ? 'Grid charging ON' : 'Grid charging OFF'}',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GpPrimaryButton(
                  label: 'Open Today',
                  icon: Icons.today_outlined,
                  onPressed: () async {
                    await ref
                        .read(selectedPlantIdProvider.notifier)
                        .setSelected(plant.id);
                    if (!context.mounted) return;
                    context.go('/today');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePlantDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final values = await showDialog<_CreatePlantValues>(
      context: context,
      builder: (context) => const _CreatePlantDialog(),
    );
    if (values == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Supabase not configured. Running in offline preview mode.',
          ),
        ),
      );
      return;
    }

    try {
      final plantId = await client.rpc(
        'create_plant_with_defaults',
        params: {
          'p_name': values.name,
          'p_time_zone': values.timeZone,
          'p_default_peak_shaving_w': values.defaultPeakShavingW,
          'p_default_grid_charging_allowed': values.defaultGridChargingAllowed,
          'p_collection_name': 'Default',
          'p_week_schedule_name': 'Week',
        },
      );
      ref.invalidate(plantsProvider);
      await ref
          .read(selectedPlantIdProvider.notifier)
          .setSelected(plantId as String);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Installation created.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create installation: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(plantsProvider);
    return GpPageScaffold(
      title: 'My Installations',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(plantsProvider),
        ),
      ],
      body: plants.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No installations yet.'),
                  const SizedBox(height: 12),
                  GpPrimaryButton(
                    label: 'Add Installation',
                    icon: Icons.add,
                    onPressed: () => _showCreatePlantDialog(context, ref),
                  ),
                ],
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final layout = GpResponsiveBreakpoints.layoutForWidth(
                constraints.maxWidth,
              );
              if (layout == GpWindowSize.compact) {
                return ListView.separated(
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return GpPrimaryButton(
                        label: 'Add Installation',
                        icon: Icons.add_circle_outline,
                        onPressed: () => _showCreatePlantDialog(context, ref),
                      );
                    }
                    return _buildPlantCard(context, ref, items[index]);
                  },
                );
              }

              final columns = constraints.maxWidth >= 1100 ? 3 : 2;
              const spacing = 12.0;
              final availableWidth =
                  constraints.maxWidth - ((columns - 1) * spacing);
              final cardWidth = availableWidth / columns;

              return ListView(
                children: [
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: items
                        .map(
                          (plant) => SizedBox(
                            width: cardWidth,
                            child: _buildPlantCard(context, ref, plant),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 320,
                    child: GpPrimaryButton(
                      label: 'Add Installation',
                      icon: Icons.add_circle_outline,
                      onPressed: () => _showCreatePlantDialog(context, ref),
                    ),
                  ),
                ],
              );
            },
          );
        },
        error: (error, _) =>
            Center(child: Text('Could not load installations: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _CreatePlantValues {
  const _CreatePlantValues({
    required this.name,
    required this.timeZone,
    required this.defaultPeakShavingW,
    required this.defaultGridChargingAllowed,
  });

  final String name;
  final String timeZone;
  final int defaultPeakShavingW;
  final bool defaultGridChargingAllowed;
}

class _CreatePlantDialog extends StatefulWidget {
  const _CreatePlantDialog();

  @override
  State<_CreatePlantDialog> createState() => _CreatePlantDialogState();
}

class _CreatePlantDialogState extends State<_CreatePlantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _timeZoneController = TextEditingController(text: 'Europe/Stockholm');
  final _defaultPeakController = TextEditingController(text: '0');
  bool _defaultGridCharging = false;

  @override
  void dispose() {
    _nameController.dispose();
    _timeZoneController.dispose();
    _defaultPeakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Installation'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Installation name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _timeZoneController,
                decoration: const InputDecoration(
                  labelText: 'Time zone (IANA)',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Time zone is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _defaultPeakController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Default peak shaving (W)',
                ),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  if (number == null || number < 0 || number % 100 != 0) {
                    return 'Use a non-negative number in 100W steps';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Default grid charging allowed'),
                value: _defaultGridCharging,
                onChanged: (value) =>
                    setState(() => _defaultGridCharging = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              _CreatePlantValues(
                name: _nameController.text.trim(),
                timeZone: _timeZoneController.text.trim(),
                defaultPeakShavingW: int.parse(_defaultPeakController.text),
                defaultGridChargingAllowed: _defaultGridCharging,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
