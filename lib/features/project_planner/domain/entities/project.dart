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

/// Lifecycle status of a blueprint project.
enum ProjectStatus {
  /// Blueprint created but not started yet.
  draft,

  /// Currently being worked on.
  active,

  /// Temporarily stopped.
  paused,

  /// All tasks finished.
  completed,

  /// Read-only historical project.
  archived,

  /// Soft-deleted (kept for the retention window).
  deleted;

  String get jsonKey => switch (this) {
    ProjectStatus.draft => 'draft',
    ProjectStatus.active => 'active',
    ProjectStatus.paused => 'paused',
    ProjectStatus.completed => 'completed',
    ProjectStatus.archived => 'archived',
    ProjectStatus.deleted => 'deleted',
  };

  String get label => switch (this) {
    ProjectStatus.draft => 'Draft',
    ProjectStatus.active => 'Active',
    ProjectStatus.paused => 'Paused',
    ProjectStatus.completed => 'Completed',
    ProjectStatus.archived => 'Archived',
    ProjectStatus.deleted => 'Deleted',
  };

  static ProjectStatus fromJson(String? value) => switch (value) {
    'draft' => ProjectStatus.draft,
    'paused' => ProjectStatus.paused,
    'completed' => ProjectStatus.completed,
    'archived' => ProjectStatus.archived,
    'deleted' => ProjectStatus.deleted,
    'active' => ProjectStatus.active,
    // Unknown / legacy → active (backward-compatible fallback).
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
    this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.archivedAt,
    this.deletedAt,
    this.lastActiveAt,
    this.completionPercentage = 0,
    this.completedDays = 0,
    this.completedTasks = 0,
    this.estimatedTotalMinutes = 0,
    this.actualMinutesSpent = 0,
    this.streakDays = 0,
    this.isDeleted = false,
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

  // ── Lifecycle timestamps ──────────────────────────────────────────────────
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? pausedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime? lastActiveAt;

  // ── Progress counters ─────────────────────────────────────────────────────
  final int completionPercentage;
  final int completedDays;
  final int completedTasks;
  final int estimatedTotalMinutes;
  final int actualMinutesSpent;
  final int streakDays;
  final bool isDeleted;

  /// Whether a stored blueprint exists to recover tasks from.
  bool get hasBlueprint => parsedBlueprint != null;

  /// The date the roadmap clock starts from — falls back to creation date
  /// for legacy projects that were never explicitly "started".
  DateTime get effectiveStartDate => startedAt ?? createdAt;

  /// Current roadmap day, 1-based, clamped to the project duration.
  int get currentDayNumber {
    final elapsed = DateTime.now().difference(effectiveStartDate).inDays + 1;
    return elapsed.clamp(1, durationDays);
  }

  /// Days left in the roadmap (never negative).
  int get remainingDays =>
      (durationDays - currentDayNumber).clamp(0, durationDays);

  Project copyWith({
    ProjectStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? pausedAt,
    DateTime? archivedAt,
    DateTime? deletedAt,
    DateTime? lastActiveAt,
    int? completionPercentage,
    int? completedDays,
    int? completedTasks,
    int? estimatedTotalMinutes,
    int? actualMinutesSpent,
    int? streakDays,
    bool? isDeleted,
    ParsedBlueprint? parsedBlueprint,
  }) {
    return Project(
      id: id,
      userId: userId,
      title: title,
      goalDescription: goalDescription,
      template: template,
      durationDays: durationDays,
      difficulty: difficulty,
      dailyTimeMinutes: dailyTimeMinutes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      generatedPrompt: generatedPrompt,
      rawBlueprintResponse: rawBlueprintResponse,
      parsedBlueprint: parsedBlueprint ?? this.parsedBlueprint,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      completedDays: completedDays ?? this.completedDays,
      completedTasks: completedTasks ?? this.completedTasks,
      estimatedTotalMinutes:
          estimatedTotalMinutes ?? this.estimatedTotalMinutes,
      actualMinutesSpent: actualMinutesSpent ?? this.actualMinutesSpent,
      streakDays: streakDays ?? this.streakDays,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
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
