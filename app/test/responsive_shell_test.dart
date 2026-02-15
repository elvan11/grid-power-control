import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('uses bottom navigation on compact width (390)', (
    WidgetTester tester,
  ) async {
    final auth = TestAuthRefreshListenable(isAuthenticated: true);
    await pumpGridPowerControlApp(tester, width: 390, authListenable: auth);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses collapsed navigation rail on medium width (768)', (
    WidgetTester tester,
  ) async {
    final auth = TestAuthRefreshListenable(isAuthenticated: true);
    await pumpGridPowerControlApp(tester, width: 768, authListenable: auth);

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('uses extended navigation rail on expanded width (1280)', (
    WidgetTester tester,
  ) async {
    final auth = TestAuthRefreshListenable(isAuthenticated: true);
    await pumpGridPowerControlApp(tester, width: 1280, authListenable: auth);

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('redirects to sign-in when unauthenticated', (
    WidgetTester tester,
  ) async {
    final auth = TestAuthRefreshListenable(isAuthenticated: false);
    await pumpGridPowerControlApp(tester, width: 390, authListenable: auth);

    expect(find.text('Sign In to Energy Manager'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
