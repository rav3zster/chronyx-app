/// Route paths and [GoRoute.name] identifiers used across the app.
class AppRoutes {
  const AppRoutes._();

  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String timeTracking = '/time-tracking';
  static const String analytics = '/analytics';
  static const String wrapped = '/wrapped';
  static const String aiCoach = '/ai-coach';

  /// Matches [GoRoute.name] for login (must equal `'login'`).
  static const String loginName = 'login';

  /// Matches [GoRoute.name] for dashboard (must equal `'dashboard'`).
  static const String dashboardName = 'dashboard';

  /// Matches [GoRoute.name] for time tracking.
  static const String timeTrackingName = 'timeTracking';
}
