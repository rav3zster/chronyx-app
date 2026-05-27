import 'package:flutter/material.dart';

/// Emotional tone of the report — drives ambient color across the screen.
enum InsightMood {
  /// Strong upward momentum. Mint/cyan ambience.
  rising,

  /// Stable, steady rhythm. Indigo/blue ambience.
  steady,

  /// Slowing momentum. Amber ambience.
  cooling,

  /// At-risk: low consistency or stalled. Subtle red ambience.
  fading,

  /// Empty / new user. Soft neutral ambience.
  newcomer;

  /// Ambient backdrop colors for the screen-level radial glow.
  ({Color start, Color mid, Color end}) get ambient => switch (this) {
    InsightMood.rising => (
      start: const Color(0xFF22D3A6),
      mid: const Color(0xFF06B6D4),
      end: Colors.transparent,
    ),
    InsightMood.steady => (
      start: const Color(0xFF5B6EF5),
      mid: const Color(0xFF8B5CF6),
      end: Colors.transparent,
    ),
    InsightMood.cooling => (
      start: const Color(0xFFF59E0B),
      mid: const Color(0xFFFF6B6B),
      end: Colors.transparent,
    ),
    InsightMood.fading => (
      start: const Color(0xFFFF5370),
      mid: const Color(0xFF8B5CF6),
      end: Colors.transparent,
    ),
    InsightMood.newcomer => (
      start: const Color(0xFF818CF8),
      mid: const Color(0xFF06B6D4),
      end: Colors.transparent,
    ),
  };

  /// Primary accent color for hero CTAs and emphasis.
  Color get accent => switch (this) {
    InsightMood.rising => const Color(0xFF22D3A6),
    InsightMood.steady => const Color(0xFF5B6EF5),
    InsightMood.cooling => const Color(0xFFF59E0B),
    InsightMood.fading => const Color(0xFFFF5370),
    InsightMood.newcomer => const Color(0xFF818CF8),
  };

  /// Hero gradient — used behind the main hero card.
  LinearGradient get heroGradient {
    final colors = switch (this) {
      InsightMood.rising => const [
        Color(0xFF22D3A6),
        Color(0xFF06B6D4),
        Color(0xFF5B6EF5),
      ],
      InsightMood.steady => const [
        Color(0xFF5B6EF5),
        Color(0xFF8B5CF6),
        Color(0xFF06B6D4),
      ],
      InsightMood.cooling => const [
        Color(0xFFF59E0B),
        Color(0xFFFF6B6B),
        Color(0xFF8B5CF6),
      ],
      InsightMood.fading => const [
        Color(0xFFFF5370),
        Color(0xFF8B5CF6),
        Color(0xFF5B6EF5),
      ],
      InsightMood.newcomer => const [
        Color(0xFF818CF8),
        Color(0xFF06B6D4),
        Color(0xFF22D3A6),
      ],
    };
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.0, 0.55, 1.0],
    );
  }

  /// Single-character icon hint for the hero card.
  String get glyph => switch (this) {
    InsightMood.rising => '🔥',
    InsightMood.steady => '✨',
    InsightMood.cooling => '⚡',
    InsightMood.fading => '🌒',
    InsightMood.newcomer => '🌅',
  };
}
