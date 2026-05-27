import 'package:flutter/material.dart';

/// Higher-level life dimensions, mapped from raw categories + tasks.
///
/// Distinct from `TaskCategory` — those are session tags. These are
/// *life areas* the user invests in. The mapping happens in the data layer.
enum LifeArea {
  learning,
  career,
  health,
  focus,
  social,
  rest;

  String get label => switch (this) {
    LifeArea.learning => 'Learning',
    LifeArea.career => 'Career',
    LifeArea.health => 'Health',
    LifeArea.focus => 'Focus',
    LifeArea.social => 'Social',
    LifeArea.rest => 'Rest',
  };

  Color get color => switch (this) {
    LifeArea.learning => const Color(0xFF818CF8),
    LifeArea.career => const Color(0xFF5B6EF5),
    LifeArea.health => const Color(0xFF22D3A6),
    LifeArea.focus => const Color(0xFFF59E0B),
    LifeArea.social => const Color(0xFFFF6B9C),
    LifeArea.rest => const Color(0xFF38BDF8),
  };
}

/// One axis of the life balance radar.
class BalanceAxis {
  const BalanceAxis({
    required this.area,
    required this.minutes,
    required this.score, // 0.0–1.0 normalized
  });

  final LifeArea area;
  final int minutes;

  /// Normalized 0.0–1.0 — how much this area is invested in,
  /// relative to the user's max area for the window.
  final double score;
}

/// Full life balance snapshot for the radar chart.
class LifeBalance {
  const LifeBalance({required this.axes});

  final List<BalanceAxis> axes;

  /// The least-invested area (excluding zero scores).
  BalanceAxis? get neglectedAxis {
    final nonZero = axes.where((a) => a.minutes > 0).toList()
      ..sort((a, b) => a.score.compareTo(b.score));
    return nonZero.isEmpty ? null : nonZero.first;
  }

  /// The most-invested area.
  BalanceAxis? get dominantAxis {
    final sorted = [...axes]..sort((a, b) => b.score.compareTo(a.score));
    if (sorted.isEmpty || sorted.first.minutes == 0) return null;
    return sorted.first;
  }

  /// Whether there is any data.
  bool get hasData => axes.any((a) => a.minutes > 0);
}
