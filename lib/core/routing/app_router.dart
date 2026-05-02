import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/features/auth/presentation/pages/dashboard_page.dart';
import 'package:chronyx/features/goals/presentation/pages/goals_page.dart';
import 'package:chronyx/features/goals/presentation/pages/goal_detail_page.dart';
import 'package:chronyx/features/goals/presentation/pages/create_goal_page.dart';
import 'package:chronyx/features/auth/presentation/pages/login_page.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/time_tracking/presentation/pages/time_tracking_page.dart';
import 'package:chronyx/features/analytics/presentation/pages/analytics_page.dart';
import 'package:chronyx/features/analytics/presentation/pages/wrapped_page.dart';
import 'package:chronyx/features/ai_coach/presentation/pages/ai_coach_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(authRouterRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      if (authState.isLoading) {
        debugPrint('[Router] redirect skipped — auth still loading');
        return null;
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;

      debugPrint(
        '[Router] redirect check: matched=${state.matchedLocation} '
        'uri=${state.uri} isLoggedIn=$isLoggedIn',
      );

      if (!isLoggedIn && !isLoginRoute) {
        return AppRoutes.login;
      }

      if (isLoggedIn && isLoginRoute) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(
            body: child,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _navIndexFromLocation(state.matchedLocation ?? ''),
              onTap: (index) {
                switch (index) {
                  case 0:
                    context.go(AppRoutes.dashboard);
                    break;
                  case 1:
                    context.go(AppRoutes.goals);
                    break;
                  case 2:
                    context.go(AppRoutes.analytics);
                    break;
                  case 3:
                    context.go(AppRoutes.aiCoach);
                    break;
                }
              },
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Goals'),
                BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Analytics'),
                BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI Coach'),
              ],
            ),
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.dashboard,
            name: AppRoutes.dashboardName,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.goals,
            name: 'goals',
            builder: (context, state) => const GoalsPage(),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            name: 'analytics',
            builder: (context, state) => const AnalyticsPage(),
          ),
          GoRoute(
            path: AppRoutes.aiCoach,
            name: 'aiCoach',
            builder: (context, state) => const AICoachPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.timeTracking,
        name: AppRoutes.timeTrackingName,
        builder: (context, state) => const TimeTrackingPage(),
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
          final id = state.pathParameters['id']!;
          return GoalDetailPage(goalId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.wrapped,
        name: 'wrapped',
        builder: (context, state) => const WrappedPage(),
      ),
    ],
  );
});

int _navIndexFromLocation(String location) {
  if (location.startsWith(AppRoutes.goals)) return 1;
  if (location.startsWith(AppRoutes.analytics)) return 2;
  if (location.startsWith(AppRoutes.aiCoach)) return 3;
  return 0;
}
