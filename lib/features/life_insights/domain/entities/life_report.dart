import 'package:chronyx/features/life_insights/domain/entities/focus_pattern.dart';
import 'package:chronyx/features/life_insights/domain/entities/insight_window.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_balance.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_snapshot.dart';
import 'package:chronyx/features/life_insights/domain/entities/mood.dart';
import 'package:chronyx/features/life_insights/domain/entities/time_allocation.dart';
import 'package:chronyx/features/life_insights/domain/entities/weekly_win.dart';

/// Trend direction for a metric across the window.
enum TrendDirection {
  up,
  down,
  flat;

  String get arrow => switch (this) {
    TrendDirection.up => '↑',
    TrendDirection.down => '↓',
    TrendDirection.flat => '→',
  };
}

class TrendPoint {
  const TrendPoint({required this.label, required this.value});
  final String label;
  final double value;
}

/// Top item by minutes (project, task, goal, or category).
class TopItem {
  const TopItem({
    required this.label,
    required this.minutes,
    required this.kind,
    this.subtitle,
  });

  final String label;
  final int minutes;
  final TopItemKind kind;
  final String? subtitle;

  double get hours => minutes / 60.0;
}

enum TopItemKind { project, task, goal, category }

/// A single behavioral pattern insight.
class BehaviorInsight {
  const BehaviorInsight({
    required this.id,
    required this.title,
    required this.detail,
    required this.tone,
  });

  final String id;
  final String title;
  final String detail;
  final InsightTone tone;
}

enum InsightTone { positive, neutral, warning }

/// Spotify-Wrapped-style summary numbers for the period.
class WeeklyReflection {
  const WeeklyReflection({
    required this.focusedMinutes,
    required this.topActivityLabel,
    required this.peakHour,
    required this.consistencyPercent,
    required this.momentum,
    required this.dailyMinutes,
  });

  final int focusedMinutes;
  final String topActivityLabel;
  final int peakHour;
  final double consistencyPercent;
  final TrendDirection momentum;

  /// Per-day minutes, ordered oldest → newest. Length = window days.
  final List<TrendPoint> dailyMinutes;

  String get focusedFormatted {
    final h = focusedMinutes ~/ 60;
    final m = focusedMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

/// A predictive insight based on current pace.
class Prediction {
  const Prediction({required this.id, required this.text, required this.tone});

  final String id;
  final String text;
  final InsightTone tone;
}

/// The full report rendered on the Life Insights screen.
class LifeReport {
  const LifeReport({
    required this.window,
    required this.snapshot,
    required this.topItems,
    required this.behaviors,
    required this.reflection,
    required this.predictions,
    required this.heroSubtitle,
    required this.heroEmotion,
    required this.mood,
    required this.balance,
    required this.wins,
  });

  final InsightWindow window;
  final LifeSnapshot snapshot;
  final List<TopItem> topItems;
  final List<BehaviorInsight> behaviors;
  final WeeklyReflection reflection;
  final List<Prediction> predictions;

  /// Headline for the hero card. e.g. "You're strongest in the evening."
  final String heroSubtitle;

  /// Emotional headline for the hero — e.g. "Your momentum is rising 🔥"
  final String heroEmotion;

  /// Drives the screen's color mood.
  final InsightMood mood;

  /// Life balance radar data.
  final LifeBalance balance;

  /// Weekly wins (achievements) to celebrate.
  final List<WeeklyWin> wins;

  TimeAllocation get allocation => snapshot.allocation;
  FocusPattern get focusPattern => snapshot.focusPattern;
  bool get hasEnoughData => snapshot.hasEnoughData;
}
