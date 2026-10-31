import 'package:app/core/widgets/import_energy_fields.dart';
import 'package:app/core/widgets/import_plan_timeline.dart';
import 'package:app/data/import_plans_provider.dart';
import 'package:app/data/schedules_provider.dart';
import 'package:app/features/schedules/edit_schedule_page.dart';
import 'package:app/features/settings/settings_page.dart';
import 'package:app/core/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [390.0, 768.0, 1280.0]) {
    testWidgets('import preview and timezone timeline fit $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final plan = ImportPlan.fromMap({
        'target_wh': 4500,
        'peak_shaving_w': 6000,
        'status': 'ready',
        'slots': [
          {
            'start': '2026-10-25T00:00:00Z',
            'end': '2026-10-25T00:15:00Z',
            'selected': true,
            'energy_wh': 1500,
          },
          {
            'start': '2026-10-25T01:00:00Z',
            'end': '2026-10-25T01:15:00Z',
            'selected': false,
            'energy_wh': 0,
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ImportEnergyFields(
                  energyText: '4.5',
                  powerW: 6000,
                  onChanged: (_) {},
                ),
                ImportPlanTimeline(
                  plans: [plan],
                  timeZone: 'Europe/Stockholm',
                  overrideActive: true,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.textContaining('3 × 15 minutes'), findsOneWidget);
      expect(find.textContaining('02:00 CEST'), findsOneWidget);
      expect(find.textContaining('02:00 CET'), findsOneWidget);
      expect(
        find.textContaining('Manual override takes priority'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('spot editor loads type target and rounded preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyScheduleDetailProvider('spot').overrideWith(
            (ref) async => const DailyScheduleDetail(
              id: 'spot',
              name: 'Cheap import',
              segments: [
                TimeSegmentModel(
                  id: 'one',
                  startTime: '00:00:00',
                  endTime: '02:00:00',
                  peakShavingW: 6000,
                  gridChargingAllowed: false,
                  sortOrder: 0,
                  controlKind: SegmentControlKind.spotImport,
                  importEnergyWh: 4500,
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: EditSchedulePage(scheduleId: 'spot')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Import at cheapest times'), findsOneWidget);
    expect(find.text('Energy to import (kWh)'), findsOneWidget);
    expect(find.textContaining('3 × 15 minutes'), findsOneWidget);
    expect(find.text('Allow grid charging'), findsNothing);
  });
  testWidgets('settings exposes all supported areas without defaulting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('price-area-local-demo-plant')),
    );
    expect(dropdown.initialValue, isNull);
    expect(find.text('Electricity price area'), findsOneWidget);
  });
}
