import 'package:app/core/widgets/gp_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter buildRouter({required bool pushDetailsFromHome}) {
    return GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  if (pushDetailsFromHome) {
                    context.push('/details');
                  } else {
                    context.go('/details');
                  }
                },
                child: const Text('Open details'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/details',
          builder: (context, state) => const GpPageScaffold(
            title: 'Details',
            showBack: true,
            backFallbackRoute: '/home',
            body: SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  testWidgets('back button pops when a previous route exists', (tester) async {
    final router = buildRouter(pushDetailsFromHome: true);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Open details'), findsOneWidget);
  });

  testWidgets('back button uses fallback route when route stack cannot pop', (
    tester,
  ) async {
    final router = buildRouter(pushDetailsFromHome: false);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Open details'), findsOneWidget);
  });
}
