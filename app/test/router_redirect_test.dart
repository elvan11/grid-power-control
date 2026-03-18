import 'package:app/data/plants_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('authenticated user is redirected away from sign-in route', (
    tester,
  ) async {
    final auth = TestAuthRefreshListenable(isAuthenticated: false);
    await pumpGridPowerControlApp(tester, authListenable: auth);

    expect(find.text('Sign In to Energy Manager'), findsOneWidget);

    auth.setAuthenticated(true);
    await tester.pumpAndSettle();

    expect(find.text("Today's Status"), findsOneWidget);
  });

  testWidgets(
    'authenticated user lands on Today when only one installation exists',
    (tester) async {
      final auth = TestAuthRefreshListenable(isAuthenticated: true);
      await pumpGridPowerControlApp(
        tester,
        authListenable: auth,
        overrides: [
          plantsProvider.overrideWith(
            (ref) async => const [
              PlantSummary(
                id: 'plant-1',
                name: 'Home',
                timeZone: 'Europe/Stockholm',
                defaultPeakShavingW: 2000,
                defaultGridChargingAllowed: false,
                scheduleControlEnabled: true,
                activeScheduleCollectionId: 'collection-1',
              ),
            ],
          ),
        ],
      );

      expect(find.text("Today's Status"), findsOneWidget);
    },
  );

  testWidgets(
    'authenticated user lands on Installations when multiple installations exist',
    (tester) async {
      final auth = TestAuthRefreshListenable(isAuthenticated: true);
      await pumpGridPowerControlApp(
        tester,
        authListenable: auth,
        overrides: [
          plantsProvider.overrideWith(
            (ref) async => const [
              PlantSummary(
                id: 'plant-1',
                name: 'Home',
                timeZone: 'Europe/Stockholm',
                defaultPeakShavingW: 2000,
                defaultGridChargingAllowed: false,
                scheduleControlEnabled: true,
                activeScheduleCollectionId: 'collection-1',
              ),
              PlantSummary(
                id: 'plant-2',
                name: 'Cabin',
                timeZone: 'Europe/Stockholm',
                defaultPeakShavingW: 1800,
                defaultGridChargingAllowed: true,
                scheduleControlEnabled: true,
                activeScheduleCollectionId: 'collection-2',
              ),
            ],
          ),
        ],
      );

      expect(find.text('My Installations'), findsOneWidget);
    },
  );
}
