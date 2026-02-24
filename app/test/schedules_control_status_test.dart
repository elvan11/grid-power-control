import 'package:app/data/plants_provider.dart';
import 'package:app/data/schedules_provider.dart';
import 'package:app/features/schedules/schedules_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows disabled status and still allows schedule editing actions',
    (WidgetTester tester) async {
      const collectionId = 'local-default-collection';
      const schedules = <DailyScheduleSummary>[
        DailyScheduleSummary(
          id: 'local-schedule-1',
          name: 'Weekday',
          segmentCount: 2,
        ),
      ];
      const weekBundle = WeekScheduleBundle(
        weekScheduleId: 'local-week',
        assignmentsByDay: {1: 'local-schedule-1'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedPlantProvider.overrideWithValue(
              const PlantSummary(
                id: 'local-demo-plant',
                name: 'Demo',
                timeZone: 'Europe/Stockholm',
                defaultPeakShavingW: 2000,
                defaultGridChargingAllowed: false,
                scheduleControlEnabled: false,
                activeScheduleCollectionId: collectionId,
              ),
            ),
            dailySchedulesProvider(
              collectionId,
            ).overrideWith((ref) async => schedules),
            weekScheduleBundleProvider(
              collectionId,
            ).overrideWith((ref) async => weekBundle),
          ],
          child: const MaterialApp(home: SchedulesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schedule control'), findsOneWidget);
      expect(
        find.textContaining('automatic schedule control is paused'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      final scheduleControlSwitch = tester.widget<Switch>(
        find.byType(Switch).first,
      );
      expect(scheduleControlSwitch.value, isFalse);

      await tester.ensureVisible(find.byType(FilterChip).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilterChip).first);
      await tester.pumpAndSettle();
      expect(
        find.text('You have unsaved day assignment changes.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('asks for confirmation before disabling schedule control', (
    WidgetTester tester,
  ) async {
    const collectionId = 'local-default-collection';
    const schedules = <DailyScheduleSummary>[
      DailyScheduleSummary(
        id: 'local-schedule-1',
        name: 'Weekday',
        segmentCount: 2,
      ),
    ];
    const weekBundle = WeekScheduleBundle(
      weekScheduleId: 'local-week',
      assignmentsByDay: {1: 'local-schedule-1'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedPlantProvider.overrideWithValue(
            const PlantSummary(
              id: 'local-demo-plant',
              name: 'Demo',
              timeZone: 'Europe/Stockholm',
              defaultPeakShavingW: 2000,
              defaultGridChargingAllowed: false,
              scheduleControlEnabled: true,
              activeScheduleCollectionId: collectionId,
            ),
          ),
          dailySchedulesProvider(
            collectionId,
          ).overrideWith((ref) async => schedules),
          weekScheduleBundleProvider(
            collectionId,
          ).overrideWith((ref) async => weekBundle),
        ],
        child: const MaterialApp(home: SchedulesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.text('Disable schedule control?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Disable'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Disable schedule control?'), findsNothing);
    final scheduleControlSwitch = tester.widget<Switch>(
      find.byType(Switch).first,
    );
    expect(scheduleControlSwitch.value, isTrue);
  });
}
