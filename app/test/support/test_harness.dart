import 'package:app/app/app.dart';
import 'package:app/core/supabase/supabase_provider.dart';
import 'package:app/core/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAuthRefreshListenable extends AuthRefreshListenable {
  TestAuthRefreshListenable({bool isAuthenticated = false})
    : _isAuthenticated = isAuthenticated,
      super(null);

  bool _isAuthenticated;

  @override
  bool get isAuthenticated => _isAuthenticated;

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    notifyListeners();
  }
}

Future<void> pumpGridPowerControlApp(
  WidgetTester tester, {
  required TestAuthRefreshListenable authListenable,
  double width = 390,
  double height = 900,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    authListenable.dispose();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRefreshListenableProvider.overrideWithValue(authListenable),
        ...overrides,
      ],
      child: const GridPowerControlApp(),
    ),
  );
  await tester.pumpAndSettle();
}
