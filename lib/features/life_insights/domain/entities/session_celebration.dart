import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

/// Celebration data shown after a focus session completes.
///
/// Composed at the moment a session is stopped, using the just-finished
/// session plus aggregate context.
class SessionCelebration {
  const SessionCelebration({
    required this.session,
    required this.headline,
    required this.glyph,
    required this.streakDays,
    required this.todayMinutes,
    required this.weekMinutes,
    required this.momentumDeltaPercent,
    required this.isPersonalBest,
  });

  final TimeEntry session;
  final String headline;
  final String glyph;

  /// Days in a row including today with at least one tracked session.
  final int streakDays;

  /// Total tracked minutes today (including the just-finished session).
  final int todayMinutes;

  /// Total tracked minutes in the last 7 days (including today).
  final int weekMinutes;

  /// Percentage change vs the previous 7 days. Null if insufficient data.
  final double? momentumDeltaPercent;

  /// Whether this session is the user's longest ever.
  final bool isPersonalBest;

  Duration get duration => session.duration;
  String get categoryLabel => session.category.label;
}
