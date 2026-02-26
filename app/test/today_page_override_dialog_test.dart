import 'package:app/data/plants_provider.dart';
import 'package:app/features/today/today_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plant = PlantSummary(
    id: 'plant-1',
    name: 'Site A',
    timeZone: 'Europe/Stockholm',
    defaultPeakShavingW: 2000,
    defaultGridChargingAllowed: false,
    scheduleControlEnabled: true,
    activeScheduleCollectionId: 'collection-1',
  );

  Future<void> pumpTodayPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plantsProvider.overrideWith((ref) async => [plant]),
          selectedPlantProvider.overrideWithValue(plant),
          plantRuntimeProvider(plant.id).overrideWith(
            (ref) async => const PlantRuntimeSnapshot(
              lastAppliedPeakShavingW: 1800,
              lastAppliedGridChargingAllowed: false,
            ),
          ),
          activeOverrideProvider(plant.id).overrideWith((ref) async => null),
          recentControlLogProvider(
            plant.id,
          ).overrideWith((ref) async => const []),
          plantBatterySocProvider(plant.id).overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('temporary override defaults to Start now', (tester) async {
    await pumpTodayPage(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Temporary Override'));
    await tester.pumpAndSettle();

    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('Start now'), findsOneWidget);
    expect(find.text('Start at specific time'), findsOneWidget);

    final applyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply'),
    );
    expect(applyButton.onPressed, isNotNull);
  });

  testWidgets('specific start time requires a picked start time', (
    tester,
  ) async {
    await pumpTodayPage(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Temporary Override'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start at specific time'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a start time.'), findsOneWidget);
    final applyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply'),
    );
    expect(applyButton.onPressed, isNull);
  });
}
