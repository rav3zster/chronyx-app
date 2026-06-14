import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/utils/responsive.dart';
import 'package:chronyx/features/analytics/presentation/pages/analytics_page.dart';
import 'package:chronyx/features/analytics/presentation/pages/wrapped_page.dart';
import 'package:chronyx/features/profile/presentation/pages/profile_page.dart';
import 'package:chronyx/features/auth/presentation/pages/auth_debug_page.dart';
import 'package:chronyx/features/auth/presentation/pages/dashboard_page.dart';
import 'package:chronyx/features/auth/presentation/pages/login_page.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/goals/presentation/pages/create_goal_page.dart';
import 'package:chronyx/features/goals/presentation/pages/goal_detail_page.dart';
import 'package:chronyx/features/goals/presentation/pages/goals_page.dart';
import 'package:chronyx/features/life_insights/presentation/pages/life_insights_page.dart';
import 'package:chronyx/features/project_planner/presentation/pages/blueprint_wizard_page.dart';
import 'package:chronyx/features/project_planner/presentation/pages/project_detail_page.dart';
import 'package:chronyx/features/settings/presentation/pages/settings_page.dart';
import 'package:chronyx/features/time_tracking/presentation/pages/focus_page.dart';
import 'package:chronyx/features/time_tracking/presentation/pages/time_tracking_page.dart';
import 'package:chronyx/features/todos/presentation/pages/todos_page.dart';
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
      // Auth debug page is always accessible — skip redirect logic for it.
      final isOnDebug = state.matchedLocation == AppRoutes.authDebug;
      if (isOnDebug) return null;

      debugPrint('[ROUTER] redirect() called');
      debugPrint('[ROUTER]   location   = ${state.matchedLocation}');
      debugPrint('[ROUTER]   isLoading  = ${authState.isLoading}');
      debugPrint('[ROUTER]   hasValue   = ${authState.hasValue}');
      debugPrint('[ROUTER]   isLoggedIn = $isLoggedIn');
      debugPrint('[ROUTER]   isOnLogin  = $isOnLogin');
      debugPrint('[ROUTER]   userId     = ${authState.valueOrNull?.id}');

      // Still loading — don't redirect yet.
      if (authState.isLoading && !authState.hasValue) {
        debugPrint('[ROUTER]   → null (still loading)');
        return null;
      }

      // Not logged in and not on login → send to login.
      if (!isLoggedIn && !isOnLogin) {
        debugPrint('[ROUTER]   → /login (not logged in)');
        return AppRoutes.login;
      }

      // Logged in but still on login → send to dashboard.
      if (isLoggedIn && isOnLogin) {
        debugPrint('[ROUTER]   → /dashboard (logged in)');
        return AppRoutes.dashboard;
      }

      debugPrint('[ROUTER]   → null (no redirect needed)');
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
            path: AppRoutes.focus,
            name: 'focus',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FocusPage()),
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
            path: AppRoutes.profile,
            name: 'profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
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
      GoRoute(
        path: AppRoutes.blueprint,
        name: 'blueprint',
        builder: (context, state) => const BlueprintWizardPage(),
      ),
      GoRoute(
        path: AppRoutes.projectDetail,
        name: 'projectDetail',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          return ProjectDetailPage(projectId: projectId);
        },
      ),
      GoRoute(
        path: AppRoutes.lifeInsights,
        name: 'lifeInsights',
        builder: (context, state) => const LifeInsightsPage(),
      ),
      GoRoute(
        path: AppRoutes.authDebug,
        name: 'authDebug',
        builder: (context, state) => const AuthDebugPage(),
      ),
      GoRoute(
        path: AppRoutes.todos,
        name: 'todos',
        builder: (context, state) => const TodosPage(),
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
    if (location.startsWith(AppRoutes.focus)) return 2;
    if (location.startsWith(AppRoutes.timeTracking)) return 1;
    if (location.startsWith(AppRoutes.analytics)) return 3;
    if (location.startsWith(AppRoutes.goals)) return 4;
    if (location.startsWith(AppRoutes.profile)) return 5;
    return 0; // dashboard
  }

  static const _items = <_NavItem>[
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.timer_outlined, Icons.timer_rounded, 'Sessions'),
    _NavItem(Icons.self_improvement_outlined, Icons.self_improvement_rounded, 'Focus'),
    _NavItem(Icons.insights_outlined, Icons.insights_rounded, 'Insights'),
    _NavItem(Icons.flag_outlined, Icons.flag_rounded, 'Goals'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  void _onSelect(BuildContext context, int index) {
    final route = switch (index) {
      1 => AppRoutes.timeTracking,
      2 => AppRoutes.focus,
      3 => AppRoutes.analytics,
      4 => AppRoutes.goals,
      5 => AppRoutes.profile,
      _ => AppRoutes.dashboard,
    };
    GoRouter.of(context).go(route);
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(state.matchedLocation);
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ResponsiveCenter(
            maxWidth: Breakpoints.maxNav,
            heightFactor: 1,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? scheme.surface.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.8),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_items.length, (i) {
                  final isActive = i == index;
                  return Expanded(
                    child: _NavPill(
                      item: _items[i],
                      isActive: isActive,
                      onTap: () => _onSelect(context, i),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: scheme.primary.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? scheme.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  key: ValueKey(isActive),
                  size: 22,
                  color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
