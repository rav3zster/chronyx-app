import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/prompt_template.dart';

/// The fully assembled prompt ready to be sent to the AI backend.
///
/// Built from user inputs (goal, template, configuration) and can be
/// regenerated in-place from the Prompt Preview page.
class BlueprintPrompt {
  const BlueprintPrompt({
    required this.goalDescription,
    required this.template,
    required this.durationDays,
    required this.difficulty,
    required this.dailyTimeMinutes,
    required this.assembledPrompt,
  });

  final String goalDescription;
  final PromptTemplate template;
  final int durationDays;
  final ProjectDifficulty difficulty;
  final int dailyTimeMinutes;

  /// The final prompt string sent to the AI model.
  final String assembledPrompt;
}
