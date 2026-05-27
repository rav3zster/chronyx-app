import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/features/analytics/presentation/pages/analytics_page.dart';
import 'package:chronyx/features/analytics/presentation/pages/wrapped_page.dart';
import 'package:chronyx/features/ai_coach/presentation/pages/ai_coach_page.dart';
import 'package:chronyx/features/auth/presentation/pages/dashboard_page.dart';
import 'package:chronyx/features/auth/presentation/pages/login_page.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/goals/presentation/pages/create_goal_page.dart';
import 'package:chronyx/features/goals/presentation/pages/goal_detail_page.dart';
import 'package:chronyx/features/goals/presentation/pages/goals_page.dart';
import 'package:chronyx/features/settings/presentation/pages/settings_page.dart';
import 'package:chronyx/features/time_tracking/presentation/pages/time_tracking_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(authRouterRefreshListenableProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isOnLogin = state.matchedLocation == AppRoutes.login;

      // Still loading — don't redirect yet.
      if (authState.isLoading && !authState.hasValue) return null;

      // Not logged in and not on login → send to login.
      if (!isLoggedIn && !isOnLogin) return AppRoutes.login;

      // Logged in but still on login → send to dashboard.
      if (isLoggedIn && isOnLogin) return AppRoutes.dashboard;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // ── Main shell with bottom navigation ──────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            _MainShell(state: state, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.timeTracking,
            name: 'timeTracking',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TimeTrackingPage()),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            name: 'analytics',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AnalyticsPage()),
          ),
          GoRoute(
            path: AppRoutes.goals,
            name: 'goals',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: GoalsPage()),
          ),
          GoRoute(
            path: AppRoutes.aiCoach,
            name: 'aiCoach',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AICoachPage()),
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ─────────────────────────────
      GoRoute(
        path: AppRoutes.wrapped,
        name: 'wrapped',
        builder: (context, state) => const WrappedPage(),
      ),
      GoRoute(
        path: AppRoutes.goalsCreate,
        name: 'goalsCreate',
        builder: (context, state) => const CreateGoalPage(),
      ),
      GoRoute(
        path: AppRoutes.goalDetail,
        name: 'goalDetail',
        builder: (context, state) {
          final goalId = state.pathParameters['goalId']!;
          return GoalDetailPage(goalId: goalId);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

// ── Main Shell with Bottom Navigation ─────────────────────────────────────────

class _MainShell extends StatelessWidget {
  const _MainShell({required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  int _currentIndex(String location) {
    if (location.startsWith(AppRoutes.timeTracking)) return 1;
    if (location.startsWith(AppRoutes.analytics)) return 2;
    if (location.startsWith(AppRoutes.goals)) return 3;
    if (location.startsWith(AppRoutes.aiCoach)) return 4;
    return 0; // dashboard
  }

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.timer_outlined),
      selectedIcon: Icon(Icons.timer_rounded),
      label: 'Track',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights_rounded),
      label: 'Analytics',
    ),
    NavigationDestination(
      icon: Icon(Icons.flag_outlined),
      selectedIcon: Icon(Icons.flag_rounded),
      label: 'Goals',
    ),
    NavigationDestination(
      icon: Icon(Icons.smart_toy_outlined),
      selectedIcon: Icon(Icons.smart_toy_rounded),
      label: 'Coach',
    ),
  ];

  void _onDestinationSelected(BuildContext context, int index) {
    final route = switch (index) {
      1 => AppRoutes.timeTracking,
      2 => AppRoutes.analytics,
      3 => AppRoutes.goals,
      4 => AppRoutes.aiCoach,
      _ => AppRoutes.dashboard,
    };
    GoRouter.of(context).go(route);
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(state.matchedLocation);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _onDestinationSelected(context, i),
        destinations: _destinations,
      ),
    );
  }
}
