import 'package:chronyx/features/life_insights/domain/entities/focus_pattern.dart';
import 'package:chronyx/features/life_insights/domain/entities/time_allocation.dart';

/// A neglected area: project, goal, or category that's been ignored.
class NeglectedArea {
  const NeglectedArea({
    required this.label,
    required this.daysSinceActivity,
    required this.kind,
  });

  final String label;
  final int daysSinceActivity;
  final NeglectedKind kind;
}

enum NeglectedKind { project, goal, category }

/// The single most-worked focus area for the window.
class DominantFocus {
  const DominantFocus({
    required this.label,
    required this.minutes,
    required this.percentage,
    required this.kind,
  });

  final String label;
  final int minutes;
  final double percentage; // 0.0–1.0
  final DominantKind kind;
}

enum DominantKind { project, category, task }

/// Top-level snapshot for the dashboard mini insight panel.
///
/// Aggregates everything needed to render the Life Insights card:
/// allocation chart, dominant area, neglected area, focus pattern.
class LifeSnapshot {
  const LifeSnapshot({
    required this.allocation,
    required this.focusPattern,
    required this.dominant,
    required this.neglected,
    required this.smartHeadline,
  });

  final TimeAllocation allocation;
  final FocusPattern focusPattern;
  final DominantFocus? dominant;
  final NeglectedArea? neglected;

  /// Single-sentence headline summarizing the user's life this week.
  /// e.g. "Learning dominated 48% of your time."
  final String smartHeadline;

  /// Whether the user has enough data for meaningful insights.
  bool get hasEnoughData => allocation.totalMinutes > 0;
}
