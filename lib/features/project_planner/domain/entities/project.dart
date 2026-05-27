/// Difficulty levels for a blueprint project.
enum ProjectDifficulty {
  easy,
  medium,
  hard,
  expert;

  String get label => switch (this) {
    ProjectDifficulty.easy => 'Easy',
    ProjectDifficulty.medium => 'Medium',
    ProjectDifficulty.hard => 'Hard',
    ProjectDifficulty.expert => 'Expert',
  };

  String get jsonKey => switch (this) {
    ProjectDifficulty.easy => 'easy',
    ProjectDifficulty.medium => 'medium',
    ProjectDifficulty.hard => 'hard',
    ProjectDifficulty.expert => 'expert',
  };

  static ProjectDifficulty fromJson(String? value) => switch (value) {
    'easy' => ProjectDifficulty.easy,
    'hard' => ProjectDifficulty.hard,
    'expert' => ProjectDifficulty.expert,
    _ => ProjectDifficulty.medium,
  };
}

/// Status of a blueprint project.
enum ProjectStatus {
  active,
  completed,
  archived;

  String get jsonKey => switch (this) {
    ProjectStatus.active => 'active',
    ProjectStatus.completed => 'completed',
    ProjectStatus.archived => 'archived',
  };

  static ProjectStatus fromJson(String? value) => switch (value) {
    'completed' => ProjectStatus.completed,
    'archived' => ProjectStatus.archived,
    _ => ProjectStatus.active,
  };
}

/// A user-created blueprint project with AI-generated roadmap.
class Project {
  const Project({
    required this.id,
    required this.userId,
    required this.title,
    required this.goalDescription,
    required this.template,
    required this.durationDays,
    required this.difficulty,
    required this.dailyTimeMinutes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.generatedPrompt,
    this.rawBlueprintResponse,
    this.parsedBlueprint,
  }) : assert(
         durationDays >= 7 && durationDays <= 365,
         'Duration must be between 7 and 365 days',
       );

  final String id;
  final String userId;
  final String title;
  final String goalDescription;
  final String template;
  final int durationDays;
  final ProjectDifficulty difficulty;
  final int dailyTimeMinutes;
  final String? generatedPrompt;
  final String? rawBlueprintResponse;
  final ParsedBlueprint? parsedBlueprint;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Structured representation of the AI-generated blueprint.
///
/// Stored as JSONB in the database. Parsing logic lives in the data layer.
class ParsedBlueprint {
  const ParsedBlueprint({required this.title, required this.days});

  final String title;
  final List<DayPlan> days;
}

/// A single day within a parsed blueprint.
class DayPlan {
  const DayPlan({
    required this.dayNumber,
    required this.title,
    required this.tasks,
    required this.estimatedMinutes,
  });

  final int dayNumber;
  final String title;
  final List<BlueprintTask> tasks;
  final int estimatedMinutes;
}

/// A single task within a day plan, as parsed from the AI response.
class BlueprintTask {
  const BlueprintTask({
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.todos,
  });

  final String title;
  final String description;
  final int estimatedMinutes;
  final List<String> todos;
}
