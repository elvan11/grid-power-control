import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase/supabase_provider.dart';
import '../core/widgets/gp_bottom_nav.dart';
import '../core/widgets/gp_responsive.dart';
import '../features/auth/accept_invite_page.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/installations/connect_service_page.dart';
import '../features/installations/installations_page.dart';
import '../features/schedules/edit_schedule_page.dart';
import '../features/schedules/schedules_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/sharing_page.dart';
import '../features/today/today_page.dart';

const _authSignInPath = '/auth/sign-in';
const _authSignUpPath = '/auth/sign-up';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/installations',
    refreshListenable: authState,
    redirect: (context, state) {
      final path = state.uri.path;
      final isAuthRoute = path.startsWith('/auth/');
      final isSignInOrSignUp =
          path == _authSignInPath || path == _authSignUpPath;

      if (!authState.isAuthenticated && !isAuthRoute) {
        return '$_authSignInPath?redirect=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (authState.isAuthenticated && isSignInOrSignUp) {
        final redirectTarget = state.uri.queryParameters['redirect'];
        if (redirectTarget != null && redirectTarget.startsWith('/')) {
          return redirectTarget;
        }
        return '/installations';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: _authSignInPath,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: _authSignUpPath,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: '/auth/accept-invite',
        builder: (context, state) =>
            AcceptInvitePage(token: state.uri.queryParameters['token']),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _MainTabShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/installations',
            builder: (context, state) => const InstallationsPage(),
          ),
          GoRoute(
            path: '/today',
            builder: (context, state) => const TodayPage(),
          ),
          GoRoute(
            path: '/schedules',
            builder: (context, state) => const SchedulesPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/installations/:plantId/connect-service',
        builder: (context, state) =>
            ConnectServicePage(plantId: state.pathParameters['plantId']!),
      ),
      GoRoute(
        path: '/schedules/:scheduleId/edit',
        builder: (context, state) =>
            EditSchedulePage(scheduleId: state.pathParameters['scheduleId']!),
      ),
      GoRoute(
        path: '/settings/sharing',
        builder: (context, state) => const SharingPage(),
      ),
    ],
  );
});

class _MainTabShell extends StatelessWidget {
  const _MainTabShell({required this.location, required this.child});

  final String location;
  final Widget child;

  int _indexFor(String path) {
    if (path.startsWith('/installations')) {
      return 0;
    }
    if (path.startsWith('/today')) return 1;
    if (path.startsWith('/schedules')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0;
  }

  String _pathFor(int index) {
    return switch (index) {
      0 => '/installations',
      1 => '/today',
      2 => '/schedules',
      _ => '/settings',
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _indexFor(location);
    final windowSize = context.gpWindowSize;

    if (windowSize == GpWindowSize.compact) {
      return Scaffold(
        body: child,
        bottomNavigationBar: GpBottomNavBar(
          currentIndex: currentIndex,
          onTap: (index) => context.go(_pathFor(index)),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                windowSize == GpWindowSize.expanded ? 12 : 8,
                8,
                8,
                8,
              ),
              child: GpRailNav(
                currentIndex: currentIndex,
                onTap: (index) => context.go(_pathFor(index)),
                extended: windowSize == GpWindowSize.expanded,
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
