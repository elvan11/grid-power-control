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

  testWidgets('shows battery SOC percentage on Today page', (
    WidgetTester tester,
  ) async {
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
          recentControlLogProvider(
            plant.id,
          ).overrideWith((ref) async => const []),
          plantBatterySocProvider(plant.id).overrideWith(
            (ref) async => PlantBatterySocSnapshot(
              batteryPercentage: 67,
              stationId: '1001',
              fetchedAt: DateTime.parse('2026-02-24T12:34:00.000Z'),
            ),
          ),
        ],
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Battery SOC'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.textContaining('Updated '), findsOneWidget);
  });

  testWidgets('shows SOC unavailable message when backend value is missing', (
    WidgetTester tester,
  ) async {
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
          recentControlLogProvider(
            plant.id,
          ).overrideWith((ref) async => const []),
          plantBatterySocProvider(plant.id).overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: TodayPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Battery SOC unavailable.'), findsOneWidget);
  });
}
