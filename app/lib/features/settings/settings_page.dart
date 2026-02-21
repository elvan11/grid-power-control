import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_responsive.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/plants_provider.dart';

String buildAppVersionLabel({DateTime? now}) {
  final buildDate = const String.fromEnvironment('APP_BUILD_DATE');
  final buildNumber = const String.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: '1',
  );

  DateTime resolvedNow;
  if (buildDate.isNotEmpty) {
    resolvedNow = DateTime.tryParse(buildDate) ?? (now ?? DateTime.now());
  } else {
    resolvedNow = now ?? DateTime.now();
  }

  final year = resolvedNow.year.toString().padLeft(4, '0');
  final month = resolvedNow.month.toString().padLeft(2, '0');
  final day = resolvedNow.day.toString().padLeft(2, '0');

  return '$year.$month.$day+$buildNumber';
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _defaultPeakController = TextEditingController();
  bool _defaultGridCharging = false;
  String? _boundPlantId;
  bool _saving = false;

  @override
  void dispose() {
    _defaultPeakController.dispose();
    super.dispose();
  }

  void _bindPlant(PlantSummary? plant) {
    if (plant == null || _boundPlantId == plant.id) {
      return;
    }
    _boundPlantId = plant.id;
    _defaultPeakController.text = plant.defaultPeakShavingW.toString();
    _defaultGridCharging = plant.defaultGridChargingAllowed;
  }

  Future<void> _savePlantDefaults(PlantSummary plant) async {
    final peak = int.tryParse(_defaultPeakController.text.trim());
    if (peak == null || peak < 0 || peak % 100 != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peak shaving must be non-negative in 100W steps.'),
        ),
      );
      return;
    }

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
          .from('plants')
          .update({
            'default_peak_shaving_w': peak,
            'default_grid_charging_allowed': _defaultGridCharging,
          })
          .eq('id', plant.id);
      ref.invalidate(plantsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plant defaults saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save defaults: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _logout() async {
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      await client.auth.signOut();
    }
    if (!mounted) return;
    context.go('/auth/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final selectedPlant = ref.watch(selectedPlantProvider);
    _bindPlant(selectedPlant);

    final themeCard = GpSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theme mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) {
              ref
                  .read(themeModeControllerProvider.notifier)
                  .setMode(selection.first);
            },
          ),
        ],
      ),
    );

    final plantDefaultsCard = GpSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plant defaults',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (selectedPlant == null)
            const Text('Select an installation to edit defaults.')
          else ...[
            TextFormField(
              controller: _defaultPeakController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default peak shaving (W)',
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default grid charging allowed'),
              value: _defaultGridCharging,
              onChanged: (value) =>
                  setState(() => _defaultGridCharging = value),
            ),
            const SizedBox(height: 6),
            GpPrimaryButton(
              label: _saving ? 'Saving...' : 'Save Plant Defaults',
              icon: Icons.save_outlined,
              onPressed: _saving
                  ? null
                  : () => _savePlantDefaults(selectedPlant),
            ),
          ],
        ],
      ),
    );

    final linksCard = GpSectionCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Connect Cloud Service'),
            onTap: selectedPlant == null
                ? null
                : () => context.go(
                    '/installations/${selectedPlant.id}/connect-service',
                  ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.group_outlined),
            title: const Text('Sharing'),
            onTap: () => context.go('/settings/sharing'),
          ),
        ],
      ),
    );

    final aboutCard = GpSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('QA build version'),
            subtitle: Text(buildAppVersionLabel()),
          ),
        ],
      ),
    );

    return GpPageScaffold(
      title: 'Settings',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = GpResponsiveBreakpoints.layoutForWidth(
            constraints.maxWidth,
          );
          if (layout == GpWindowSize.compact) {
            return ListView(
              children: [
                themeCard,
                const SizedBox(height: 12),
                plantDefaultsCard,
                const SizedBox(height: 12),
                linksCard,
                const SizedBox(height: 12),
                aboutCard,
                const SizedBox(height: 12),
                GpSecondaryButton(
                  label: 'Logout',
                  icon: Icons.logout_outlined,
                  onPressed: _logout,
                ),
              ],
            );
          }

          return ListView(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: themeCard),
                  const SizedBox(width: 12),
                  Expanded(child: plantDefaultsCard),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: linksCard),
                  const SizedBox(width: 12),
                  Expanded(child: aboutCard),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: SizedBox.shrink()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GpSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          GpSecondaryButton(
                            label: 'Logout',
                            icon: Icons.logout_outlined,
                            onPressed: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
