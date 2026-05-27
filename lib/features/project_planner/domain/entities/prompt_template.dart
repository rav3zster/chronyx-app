/// Predefined prompt templates for blueprint generation.
enum PromptTemplate {
  aiEngineerRoadmap,
  fitnessTransformation,
  startupPlan,
  learningGoal,
  custom;

  String get label => switch (this) {
    PromptTemplate.aiEngineerRoadmap => 'AI Engineer Roadmap',
    PromptTemplate.fitnessTransformation => 'Fitness Transformation',
    PromptTemplate.startupPlan => 'Startup Plan',
    PromptTemplate.learningGoal => 'Learning Goal',
    PromptTemplate.custom => 'Custom',
  };

  String get description => switch (this) {
    PromptTemplate.aiEngineerRoadmap =>
      'Structured path to becoming an AI/ML engineer',
    PromptTemplate.fitnessTransformation =>
      'Progressive fitness and health transformation plan',
    PromptTemplate.startupPlan =>
      'Step-by-step startup launch and growth roadmap',
    PromptTemplate.learningGoal =>
      'Focused learning plan for any skill or topic',
    PromptTemplate.custom => 'Build your own custom roadmap from scratch',
  };

  String get emoji => switch (this) {
    PromptTemplate.aiEngineerRoadmap => '🤖',
    PromptTemplate.fitnessTransformation => '💪',
    PromptTemplate.startupPlan => '🚀',
    PromptTemplate.learningGoal => '📚',
    PromptTemplate.custom => '✨',
  };

  String get jsonKey => switch (this) {
    PromptTemplate.aiEngineerRoadmap => 'ai_engineer_roadmap',
    PromptTemplate.fitnessTransformation => 'fitness_transformation',
    PromptTemplate.startupPlan => 'startup_plan',
    PromptTemplate.learningGoal => 'learning_goal',
    PromptTemplate.custom => 'custom',
  };

  /// Default duration in days for this template.
  int get defaultDurationDays => switch (this) {
    PromptTemplate.aiEngineerRoadmap => 90,
    PromptTemplate.fitnessTransformation => 60,
    PromptTemplate.startupPlan => 180,
    PromptTemplate.learningGoal => 30,
    PromptTemplate.custom => 30,
  };

  /// Default daily time commitment in minutes.
  int get defaultDailyTimeMinutes => switch (this) {
    PromptTemplate.aiEngineerRoadmap => 180,
    PromptTemplate.fitnessTransformation => 60,
    PromptTemplate.startupPlan => 240,
    PromptTemplate.learningGoal => 120,
    PromptTemplate.custom => 120,
  };

  static PromptTemplate fromJson(String? value) => switch (value) {
    'ai_engineer_roadmap' => PromptTemplate.aiEngineerRoadmap,
    'fitness_transformation' => PromptTemplate.fitnessTransformation,
    'startup_plan' => PromptTemplate.startupPlan,
    'learning_goal' => PromptTemplate.learningGoal,
    _ => PromptTemplate.custom,
  };
}
