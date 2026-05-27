import 'package:chronyx/features/project_planner/domain/entities/blueprint_prompt.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/domain/entities/prompt_template.dart';

/// Interface for prompt generation and blueprint parsing.
///
/// Implementation lives in the data layer. This abstraction allows
/// swapping parsing strategies (JSON, markdown, etc.) and prompt
/// generation logic without touching domain or presentation code.
abstract class BlueprintParser {
  /// Generate an optimized prompt for the AI backend.
  BlueprintPrompt generatePrompt({
    required String goalDescription,
    required PromptTemplate template,
    required int durationDays,
    required ProjectDifficulty difficulty,
    required int dailyTimeMinutes,
  });

  /// Parse the raw AI response text into a [ParsedBlueprint].
  ///
  /// [durationDays] is used to clamp `due_day` values within range.
  ///
  /// Throws [BlueprintParseException] if the response cannot be parsed
  /// (blocking errors). Returns a valid [ParsedBlueprint] even if
  /// non-blocking warnings were encountered during normalization.
  ParsedBlueprint parseBlueprint(String rawResponse, {int? durationDays});

  /// Convert a [ParsedBlueprint] into a list of [ProjectTask] entities
  /// ready for database insertion.
  ///
  /// [projectId] is attached to each generated task.
  List<ProjectTask> blueprintToTasks(
    String projectId,
    ParsedBlueprint blueprint,
  );
}
