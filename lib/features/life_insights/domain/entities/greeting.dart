/// Time-of-day phase for greeting copy.
enum GreetingTimeOfDay {
  earlyMorning, // 4–8
  morning, // 8–12
  afternoon, // 12–17
  evening, // 17–22
  lateNight; // 22–4

  static GreetingTimeOfDay fromHour(int h) {
    if (h >= 4 && h < 8) return GreetingTimeOfDay.earlyMorning;
    if (h >= 8 && h < 12) return GreetingTimeOfDay.morning;
    if (h >= 12 && h < 17) return GreetingTimeOfDay.afternoon;
    if (h >= 17 && h < 22) return GreetingTimeOfDay.evening;
    return GreetingTimeOfDay.lateNight;
  }

  String get baseSalutation => switch (this) {
    GreetingTimeOfDay.earlyMorning => 'Early start',
    GreetingTimeOfDay.morning => 'Good morning',
    GreetingTimeOfDay.afternoon => 'Good afternoon',
    GreetingTimeOfDay.evening => 'Good evening',
    GreetingTimeOfDay.lateNight => 'Late night',
  };
}

/// A contextual greeting + intelligent subtitle for the dashboard.
class Greeting {
  const Greeting({
    required this.salutation,
    required this.name,
    required this.message,
    required this.glyph,
  });

  /// "Good evening", "Late night", etc.
  final String salutation;

  /// User's display name (first name).
  final String name;

  /// Intelligent micro-message based on real behavior.
  /// e.g. "Tonight is usually your strongest focus window."
  final String message;

  /// Optional glyph that matches the message's tone.
  final String glyph;
}
