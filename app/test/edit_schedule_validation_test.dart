import 'package:app/features/schedules/edit_schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpEditSchedulePage(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: EditSchedulePage(scheduleId: 'local-schedule-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation message when schedule name is empty', (
    tester,
  ) async {
    await pumpEditSchedulePage(tester);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Save'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    saveButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Schedule name is required.'), findsOneWidget);
  });

  testWidgets('shows validation message when peak shaving is not 100-step', (
    tester,
  ) async {
    await pumpEditSchedulePage(tester);

    await tester.enterText(find.byType(TextFormField).at(1), '250');
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Save'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    saveButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(
      find.text('Segment 1 peak shaving must be non-negative in 100W steps.'),
      findsOneWidget,
    );
  });

  testWidgets('renders compact grid charging control with right-aligned switch', (
    tester,
  ) async {
    await pumpEditSchedulePage(tester);

    final firstGridChargingRow = find.byKey(const ValueKey('grid-charging-row-0'));
    expect(firstGridChargingRow, findsOneWidget);
    expect(
      find.descendant(
        of: firstGridChargingRow,
        matching: find.text('Allow grid charging'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: firstGridChargingRow,
        matching: find.byKey(const ValueKey('grid-charging-switch-0')),
      ),
      findsOneWidget,
    );
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('changing start to 23:45 clamps end to 24:00 and blocks adding', (
    tester,
  ) async {
    await pumpEditSchedulePage(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('start-1-18:00:00')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    final startDropdown = tester.widget<DropdownMenu<String>>(
      find.byKey(const ValueKey('start-1-18:00:00')),
    );
    startDropdown.onSelected!.call('23:45:00');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('end-1-24:00:00-23:45:00')),
      findsOneWidget,
    );

    final addButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Add New Segment'),
    );
    expect(addButton.onPressed, isNull);
  });
}
