import 'package:app/app/app.dart';
import 'package:app/core/supabase/supabase_provider.dart';
import 'package:app/core/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpAppAtWidth(WidgetTester tester, double width) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authListenable = AuthRefreshListenable(null);

    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      authListenable.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRefreshListenableProvider.overrideWithValue(authListenable),
        ],
        child: const GridPowerControlApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses bottom navigation on compact width (390)', (
    WidgetTester tester,
  ) async {
    await pumpAppAtWidth(tester, 390);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses collapsed navigation rail on medium width (768)', (
    WidgetTester tester,
  ) async {
    await pumpAppAtWidth(tester, 768);

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('uses extended navigation rail on expanded width (1280)', (
    WidgetTester tester,
  ) async {
    await pumpAppAtWidth(tester, 1280);

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });
}
