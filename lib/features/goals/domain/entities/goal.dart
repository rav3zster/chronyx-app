class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.dailyTargetMinutes,
    required this.isChallenge,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyTargetMinutes;
  final bool isChallenge;
}
