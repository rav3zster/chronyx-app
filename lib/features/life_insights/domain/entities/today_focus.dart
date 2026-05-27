import 'package:chronyx/features/life_insights/domain/entities/mood.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';

/// Five mutually-exclusive Hero states the Dashboard renders.
///
/// Picked by [LifeInsightsRepository.fetchTodayFocus] from real data —
/// no UI logic decides which state shows.
enum TodayFocusKind {
  /// First-run / no activity yet → guided onboarding.
  newcomer,

  /// User has active project but is behind schedule → gentle intervention.
  behind,

  /// User has active project and momentum is strong → celebration.
  flowing,

  /// User has active project, normal progress → motivating mission card.
  active,

  /// No active project at all → inspirational CTA to create one.
  noRoadmap,
}

/// What the Hero card needs to render.
///
/// Always non-null. Empty/inactive states still produce a [TodayFocus]
/// — the [kind] tells the UI which variant to render.
class TodayFocus {
  const TodayFocus({
    required this.kind,
    required this.mood,
    required this.headline,
    required this.subhead,
    required this.ctaLabel,
    required this.ctaRoute,
    this.glyph,
    this.project,
    this.dayNumber,
    this.totalDays,
    this.completionPercent,
    this.topTask,
    this.recommendedMinutes,
    this.streakDays,
  });

  /// Which variant the UI should render.
  final TodayFocusKind kind;

  /// Color mood — drives gradient, glow, accents.
  final InsightMood mood;

  /// Big emotional line. e.g. "You're in flow."
  final String headline;

  /// Supporting copy beneath the headline.
  final String subhead;

  /// CTA button label. e.g. "Start Focus Session", "Create Blueprint".
  final String ctaLabel;

  /// Route to navigate to when CTA is tapped.
  final String ctaRoute;

  /// Optional emoji/glyph for the headline.
  final String? glyph;

  /// Active project context (only present for active/behind/flowing).
  final Project? project;
  final int? dayNumber;
  final int? totalDays;
  final double? completionPercent; // 0.0–1.0

  /// The most important task for today.
  final ProjectTask? topTask;

  /// Recommended minutes for the focus session.
  final int? recommendedMinutes;

  /// Current streak in days, when relevant.
  final int? streakDays;

  bool get hasProjectContext => project != null && totalDays != null;
}
