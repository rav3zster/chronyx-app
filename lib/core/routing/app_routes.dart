/// Centralized route path constants for Chronyx.
///
/// Use these instead of hardcoded strings to avoid typos and enable
/// refactoring from a single location.
class AppRoutes {
  const AppRoutes._();

  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String timeTracking = '/time-tracking';
  static const String analytics = '/analytics';
  static const String wrapped = '/analytics/wrapped';
  static const String goals = '/goals';
  static const String goalsCreate = '/goals/create';
  static const String goalDetail = '/goals/:goalId';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String blueprint = '/blueprint';
  static const String projectDetail = '/project/:projectId';
  static const String lifeInsights = '/life-insights';
  static const String authDebug = '/auth-debug';
  static const String todos = '/todos';
}

