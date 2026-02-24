import 'package:app/data/plants_provider.dart';
import 'package:app/data/schedules_provider.dart';
import 'package:app/features/schedules/schedules_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows non-blocking save/cancel actions after day assignment changes',
    (WidgetTester tester) async {
      const collectionId = 'local-default-collection';
      const schedules = <DailyScheduleSummary>[
        DailyScheduleSummary(
          id: 'local-schedule-1',
          name: 'Weekday',
          segmentCount: 2,
        ),
        DailyScheduleSummary(
          id: 'local-schedule-2',
          name: 'Weekend',
          segmentCount: 2,
        ),
      ];
      const weekBundle = WeekScheduleBundle(
        weekScheduleId: 'local-week',
        assignmentsByDay: {
          1: 'local-schedule-1',
          2: 'local-schedule-1',
          3: 'local-schedule-1',
          4: 'local-schedule-1',
          5: 'local-schedule-1',
          6: 'local-schedule-2',
          7: 'local-schedule-2',
        },
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

      expect(find.text('Save Day Assignments'), findsNothing);
      expect(find.text('Save day assignment changes?'), findsNothing);
      expect(
        find.text('You have unsaved day assignment changes.'),
        findsNothing,
      );

      final weekendCard = find.ancestor(
        of: find.text('Weekend'),
        matching: find.byType(Card),
      );
      final weekendMondayChip = find
          .descendant(of: weekendCard, matching: find.byType(FilterChip))
          .first;

      await tester.ensureVisible(weekendMondayChip);
      await tester.pumpAndSettle();
      await tester.tap(weekendMondayChip);
      await tester.pumpAndSettle();

      expect(find.text('Save day assignment changes?'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('You have unsaved day assignment changes.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('You have unsaved day assignment changes.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      final weekendTuesdayChip = find
          .descendant(of: weekendCard, matching: find.byType(FilterChip))
          .at(1);
      await tester.ensureVisible(weekendTuesdayChip);
      await tester.pumpAndSettle();
      await tester.tap(weekendTuesdayChip);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('You have unsaved day assignment changes.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('You have unsaved day assignment changes.'),
        findsOneWidget,
      );
      final weekendTuesdayChipWidget = tester.widget<FilterChip>(
        weekendTuesdayChip,
      );
      expect(weekendTuesdayChipWidget.selected, isTrue);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Save day assignment changes?'), findsNothing);
      expect(
        find.text('You have unsaved day assignment changes.'),
        findsNothing,
      );

      final weekendMondayChipWidget = tester.widget<FilterChip>(
        weekendMondayChip,
      );
      expect(weekendMondayChipWidget.selected, isFalse);
    },
  );
}
