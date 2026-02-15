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

    expect(find.text('My Installations'), findsOneWidget);
  });
}
