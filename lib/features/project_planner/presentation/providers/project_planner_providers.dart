import 'dart:async';

import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/core/providers/supabase_provider.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/project_planner/data/datasources/project_remote_datasource.dart';
import 'package:chronyx/features/project_planner/data/datasources/project_supabase_datasource.dart';
import 'package:chronyx/features/project_planner/data/models/project_model.dart';
import 'package:chronyx/features/project_planner/data/repositories/blueprint_parser_impl.dart';
import 'package:chronyx/features/project_planner/data/repositories/project_repository_impl.dart';
import 'package:chronyx/features/project_planner/domain/entities/blueprint_parse_exception.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_progress.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/domain/entities/prompt_template.dart';
import 'package:chronyx/features/project_planner/domain/repositories/blueprint_parser.dart';
import 'package:chronyx/features/project_planner/domain/repositories/project_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Repository & Parser providers
// ---------------------------------------------------------------------------

final projectRemoteDataSourceProvider = Provider<ProjectRemoteDataSource>((
  ref,
) {
  return ProjectSupabaseDataSource(ref.watch(supabaseClientProvider));
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(
    ref.watch(projectRemoteDataSourceProvider),
    ref.watch(blueprintParserProvider),
  );
});

final blueprintParserProvider = Provider<BlueprintParser>((ref) {
  return const BlueprintParserImpl();
});

// ---------------------------------------------------------------------------
// Projects list provider
// ---------------------------------------------------------------------------

final projectsProvider = AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  ProjectRepository get _repository => ref.read(projectRepositoryProvider);

  @override
  Future<List<Project>> build() async {
    final authState = ref.watch(authProvider);
    if (!authState.hasValue || authState.value == null) {
      return <Project>[];
    }
    return _repository.fetchProjects();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchProjects);
  }
}

// ---------------------------------------------------------------------------
// Project lifecycle controller — turns the dashboard into a living system.
//
// Orchestrates: task toggle → recompute progress → auto-transition
// (draft→active on first completion, active→completed when all done) →
// persist → let the UI invalidate the detail provider so the hero/streak/
// momentum update instantly. Pure progress math lives in [ProjectProgress].
// ---------------------------------------------------------------------------

class ProjectLifecycleController {
  ProjectLifecycleController(this._repo);
  final ProjectRepository _repo;

  /// Toggle a task and reconcile project status + progress in one flow.
  /// Returns the (possibly changed) project status so the UI can react
  /// (e.g. route to the completion experience).
  Future<ProjectStatus> toggleTask({
    required Project project,
    required List<ProjectTask> tasks,
    required ProjectTask task,
  }) async {
    final markComplete = task.status != ProjectTaskStatus.completed;
    final nextStatus = markComplete
        ? ProjectTaskStatus.completed
        : ProjectTaskStatus.pending;

    // 1. Persist the task change.
    await _repo.updateTaskStatus(task.id, nextStatus);

    // 2. Recompute progress from the optimistic next task list.
    final nextTasks = tasks
        .map(
          (t) => t.id == task.id
              ? ProjectTask(
                  id: t.id,
                  projectId: t.projectId,
                  dayNumber: t.dayNumber,
                  title: t.title,
                  description: t.description,
                  sortOrder: t.sortOrder,
                  estimatedMinutes: t.estimatedMinutes,
                  status: nextStatus,
                  createdAt: t.createdAt,
                  completedAt: markComplete ? DateTime.now() : null,
                )
              : t,
        )
        .toList();
    final progress = ProjectProgress.fromTasks(nextTasks);

    // 3. Decide status transition.
    var resolvedStatus = project.status;

    // draft → active on first meaningful completion.
    if (project.status == ProjectStatus.draft && progress.completedTasks > 0) {
      resolvedStatus = ProjectStatus.active;
      await _repo.applyLifecycle(
        project.id,
        ProjectStatus.active,
        extraFields: {'started_at': DateTime.now().toUtc().toIso8601String()},
      );
    }
    // active → completed when everything is done.
    else if (progress.allComplete &&
        (project.status == ProjectStatus.active ||
            project.status == ProjectStatus.draft)) {
      resolvedStatus = ProjectStatus.completed;
      await _repo.applyLifecycle(project.id, ProjectStatus.completed);
    }
    // completed → active if a task was reopened.
    else if (project.status == ProjectStatus.completed &&
        !progress.allComplete) {
      resolvedStatus = ProjectStatus.active;
      await _repo.applyLifecycle(project.id, ProjectStatus.active);
    }

    // 4. Persist derived counters (always, so the hero stays honest).
    await _repo.saveProgress(
      project.id,
      completionPercentage: progress.completionPercentage,
      completedTasks: progress.completedTasks,
      completedDays: progress.completedDays,
      streakDays: progress.currentStreak,
    );

    return resolvedStatus;
  }

  Future<void> pause(String projectId) =>
      _repo.applyLifecycle(projectId, ProjectStatus.paused);

  Future<void> resume(String projectId) =>
      _repo.applyLifecycle(projectId, ProjectStatus.active);

  Future<void> archive(String projectId) =>
      _repo.applyLifecycle(projectId, ProjectStatus.archived);

  Future<void> restore(String projectId) =>
      _repo.applyLifecycle(projectId, ProjectStatus.active);

  /// Mark draft → active when a focus session starts against the project.
  Future<void> markStartedIfDraft(Project project) async {
    if (project.status != ProjectStatus.draft) return;
    await _repo.applyLifecycle(
      project.id,
      ProjectStatus.active,
      extraFields: {'started_at': DateTime.now().toUtc().toIso8601String()},
    );
  }
}

final projectLifecycleControllerProvider = Provider<ProjectLifecycleController>(
  (ref) {
    return ProjectLifecycleController(ref.watch(projectRepositoryProvider));
  },
);

// ---------------------------------------------------------------------------
// Blueprint Wizard State
// ---------------------------------------------------------------------------

final blueprintWizardProvider =
    NotifierProvider<BlueprintWizardNotifier, BlueprintWizardState>(
      BlueprintWizardNotifier.new,
    );

class BlueprintWizardState {
  const BlueprintWizardState({
    this.currentStep = 0,
    this.goalDescription = '',
    this.selectedTemplate = PromptTemplate.custom,
    this.durationDays = 30,
    this.difficulty = ProjectDifficulty.medium,
    this.dailyTimeMinutes = 120,
    this.generatedPrompt,
    this.rawBlueprintResponse,
    this.parsedBlueprint,
    this.isGenerating = false,
    this.errorMessage,
    this.parseWarnings = const [],
  });

  final int currentStep;
  final String goalDescription;
  final PromptTemplate selectedTemplate;
  final int durationDays;
  final ProjectDifficulty difficulty;
  final int dailyTimeMinutes;
  final String? generatedPrompt;
  final String? rawBlueprintResponse;
  final ParsedBlueprint? parsedBlueprint;
  final bool isGenerating;
  final String? errorMessage;
  final List<ParseIssue> parseWarnings;

  /// Total wizard steps.
  static const int totalSteps = 4;

  bool get canGoNext => currentStep < totalSteps - 1;
  bool get canGoBack => currentStep > 0;
  bool get isGoalValid => goalDescription.trim().length >= 10;

  BlueprintWizardState copyWith({
    int? currentStep,
    String? goalDescription,
    PromptTemplate? selectedTemplate,
    int? durationDays,
    ProjectDifficulty? difficulty,
    int? dailyTimeMinutes,
    String? generatedPrompt,
    String? rawBlueprintResponse,
    ParsedBlueprint? parsedBlueprint,
    bool? isGenerating,
    String? errorMessage,
    List<ParseIssue>? parseWarnings,
  }) {
    return BlueprintWizardState(
      currentStep: currentStep ?? this.currentStep,
      goalDescription: goalDescription ?? this.goalDescription,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      durationDays: durationDays ?? this.durationDays,
      difficulty: difficulty ?? this.difficulty,
      dailyTimeMinutes: dailyTimeMinutes ?? this.dailyTimeMinutes,
      generatedPrompt: generatedPrompt ?? this.generatedPrompt,
      rawBlueprintResponse: rawBlueprintResponse ?? this.rawBlueprintResponse,
      parsedBlueprint: parsedBlueprint ?? this.parsedBlueprint,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage ?? this.errorMessage,
      parseWarnings: parseWarnings ?? this.parseWarnings,
    );
  }

  /// Creates a copy with nullable fields explicitly cleared.
  BlueprintWizardState clearError() {
    return BlueprintWizardState(
      currentStep: currentStep,
      goalDescription: goalDescription,
      selectedTemplate: selectedTemplate,
      durationDays: durationDays,
      difficulty: difficulty,
      dailyTimeMinutes: dailyTimeMinutes,
      generatedPrompt: generatedPrompt,
      rawBlueprintResponse: rawBlueprintResponse,
      parsedBlueprint: parsedBlueprint,
      isGenerating: isGenerating,
      parseWarnings: parseWarnings,
    );
  }
}

class BlueprintWizardNotifier extends Notifier<BlueprintWizardState> {
  @override
  BlueprintWizardState build() => const BlueprintWizardState();

  BlueprintParser get _parser => ref.read(blueprintParserProvider);

  // ── Navigation ──────────────────────────────────────────────────────────

  void goToStep(int step) {
    if (step >= 0 && step < BlueprintWizardState.totalSteps) {
      state = state.copyWith(currentStep: step);
    }
  }

  void nextStep() {
    if (state.canGoNext) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.canGoBack) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  // ── Step 1: Goal Input ──────────────────────────────────────────────────

  void setGoalDescription(String value) {
    state = state.copyWith(goalDescription: value);
  }

  void setTemplate(PromptTemplate template) {
    state = state.copyWith(
      selectedTemplate: template,
      durationDays: template.defaultDurationDays,
      dailyTimeMinutes: template.defaultDailyTimeMinutes,
    );
  }

  void setDuration(int days) {
    state = state.copyWith(durationDays: days.clamp(7, 365));
  }

  void setDifficulty(ProjectDifficulty difficulty) {
    state = state.copyWith(difficulty: difficulty);
  }

  void setDailyTime(int minutes) {
    state = state.copyWith(dailyTimeMinutes: minutes.clamp(30, 480));
  }

  // ── Step 2: Prompt Generation ───────────────────────────────────────────

  void generatePrompt() {
    final prompt = _parser.generatePrompt(
      goalDescription: state.goalDescription,
      template: state.selectedTemplate,
      durationDays: state.durationDays,
      difficulty: state.difficulty,
      dailyTimeMinutes: state.dailyTimeMinutes,
    );
    state = state.copyWith(generatedPrompt: prompt.assembledPrompt);
  }

  void regeneratePrompt() => generatePrompt();

  // ── Step 3: Parse AI Response ───────────────────────────────────────────

  void setRawResponse(String response) {
    state = BlueprintWizardState(
      currentStep: state.currentStep,
      goalDescription: state.goalDescription,
      selectedTemplate: state.selectedTemplate,
      durationDays: state.durationDays,
      difficulty: state.difficulty,
      dailyTimeMinutes: state.dailyTimeMinutes,
      generatedPrompt: state.generatedPrompt,
      rawBlueprintResponse: response,
      isGenerating: false,
    );
  }

  /// Attempt to parse the raw response. Returns true on success.
  bool parseResponse() {
    final raw = state.rawBlueprintResponse;
    if (raw == null || raw.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please paste the AI response first.',
      );
      return false;
    }

    try {
      final blueprint = _parser.parseBlueprint(
        raw,
        durationDays: state.durationDays,
      );
      state = state.copyWith(
        parsedBlueprint: blueprint,
        parseWarnings: const [],
      );
      state = state.clearError();
      return true;
    } on BlueprintParseException catch (e) {
      // Debug log — helps diagnose AI response issues during development.
      debugPrint('[BlueprintParser] reason: ${e.message}');
      for (final issue in e.issues) {
        debugPrint(
          '[BlueprintParser]   field: ${issue.field} | '
          '${issue.severity.name}: ${issue.message}',
        );
      }
      state = state.copyWith(errorMessage: e.message, parseWarnings: e.issues);
      return false;
    }
  }

  /// Strips markdown fences, explanatory text, and extracts the first
  /// valid JSON object from the raw response. Mirrors the parser's own
  /// extraction logic so the user can see the cleaned result before
  /// validating.
  ///
  /// Returns the cleaned text, or the original if nothing was extracted.
  String cleanResponse(String raw) {
    var text = raw.trim();

    // Remove markdown code fences
    final fencePattern = RegExp(
      r'```(?:json)?\s*\n?([\s\S]*?)\n?\s*```',
      multiLine: true,
    );
    final fenceMatch = fencePattern.firstMatch(text);
    if (fenceMatch != null) {
      text = fenceMatch.group(1)!.trim();
    }

    // Extract first { → last }
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      text = text.substring(firstBrace, lastBrace + 1);
    }

    return text;
  }

  // ── Step 4: Blueprint Review (editing) ──────────────────────────────────

  void updateTaskTitle(int dayIndex, int taskIndex, String newTitle) {
    final blueprint = state.parsedBlueprint;
    if (blueprint == null) return;
    if (dayIndex < 0 || dayIndex >= blueprint.days.length) return;

    final days = List<DayPlan>.from(blueprint.days);
    final day = days[dayIndex];
    if (taskIndex < 0 || taskIndex >= day.tasks.length) return;

    final tasks = List<BlueprintTask>.from(day.tasks);
    final task = tasks[taskIndex];
    tasks[taskIndex] = BlueprintTask(
      title: newTitle.trim().isEmpty ? task.title : newTitle,
      description: task.description,
      estimatedMinutes: task.estimatedMinutes,
      todos: task.todos,
    );
    days[dayIndex] = DayPlan(
      dayNumber: day.dayNumber,
      title: day.title,
      tasks: tasks,
      estimatedMinutes: day.estimatedMinutes,
    );
    state = state.copyWith(
      parsedBlueprint: ParsedBlueprint(title: blueprint.title, days: days),
    );
  }

  void removeTask(int dayIndex, int taskIndex) {
    final blueprint = state.parsedBlueprint;
    if (blueprint == null) return;
    if (dayIndex < 0 || dayIndex >= blueprint.days.length) return;

    final days = List<DayPlan>.from(blueprint.days);
    final day = days[dayIndex];
    if (taskIndex < 0 || taskIndex >= day.tasks.length) return;

    final tasks = List<BlueprintTask>.from(day.tasks)..removeAt(taskIndex);

    if (tasks.isEmpty) {
      days.removeAt(dayIndex);
    } else {
      days[dayIndex] = DayPlan(
        dayNumber: day.dayNumber,
        title: day.title,
        tasks: tasks,
        estimatedMinutes: day.estimatedMinutes,
      );
    }
    state = state.copyWith(
      parsedBlueprint: ParsedBlueprint(title: blueprint.title, days: days),
    );
  }

  void updateTodo(int dayIndex, int taskIndex, int todoIndex, String newTodo) {
    final blueprint = state.parsedBlueprint;
    if (blueprint == null) return;
    if (dayIndex < 0 || dayIndex >= blueprint.days.length) return;

    final days = List<DayPlan>.from(blueprint.days);
    final day = days[dayIndex];
    if (taskIndex < 0 || taskIndex >= day.tasks.length) return;

    final tasks = List<BlueprintTask>.from(day.tasks);
    final task = tasks[taskIndex];
    if (todoIndex < 0 || todoIndex >= task.todos.length) return;

    final todos = List<String>.from(task.todos);
    todos[todoIndex] = newTodo;
    tasks[taskIndex] = BlueprintTask(
      title: task.title,
      description: task.description,
      estimatedMinutes: task.estimatedMinutes,
      todos: todos,
    );
    days[dayIndex] = DayPlan(
      dayNumber: day.dayNumber,
      title: day.title,
      tasks: tasks,
      estimatedMinutes: day.estimatedMinutes,
    );
    state = state.copyWith(
      parsedBlueprint: ParsedBlueprint(title: blueprint.title, days: days),
    );
  }

  // ── Reset ───────────────────────────────────────────────────────────────

  void reset() => state = const BlueprintWizardState();

  // ── Save Blueprint ──────────────────────────────────────────────────────

  /// Persist the blueprint to Supabase. Returns the created project ID
  /// or null on failure. Rolls back project creation if task insertion fails.
  Future<String?> saveBlueprint() async {
    // Guard: prevent double-save
    if (state.isGenerating) return null;

    final blueprint = state.parsedBlueprint;
    if (blueprint == null) {
      state = state.copyWith(errorMessage: 'No blueprint to save.');
      return null;
    }

    if (blueprint.days.isEmpty) {
      state = state.copyWith(errorMessage: 'Blueprint has no days to save.');
      return null;
    }

    state = state.copyWith(isGenerating: true);

    String? projectId;
    try {
      final repository = ref.read(projectRepositoryProvider);
      final parser = ref.read(blueprintParserProvider);

      // Create project
      final project = await repository.createProject(
        title: blueprint.title,
        goalDescription: state.goalDescription,
        template: state.selectedTemplate.jsonKey,
        durationDays: state.durationDays,
        difficulty: state.difficulty,
        dailyTimeMinutes: state.dailyTimeMinutes,
        generatedPrompt: state.generatedPrompt,
        rawBlueprintResponse: state.rawBlueprintResponse,
        parsedBlueprint: ProjectModel.blueprintToJson(blueprint),
      );
      projectId = project.id;

      // Convert blueprint to tasks and insert
      final tasks = parser.blueprintToTasks(project.id, blueprint);
      if (tasks.isNotEmpty) {
        await repository.insertProjectTasks(project.id, tasks);
      }

      state = state.copyWith(isGenerating: false);
      return project.id;
    } on Exception catch (e) {
      // Rollback: delete the project if it was created but tasks failed
      if (projectId != null) {
        try {
          final repository = ref.read(projectRepositoryProvider);
          await repository.deleteProject(projectId);
        } catch (_) {
          // Best-effort rollback — don't mask original error
        }
      }
      // Surface the real error message — never show "Instance of '...'"
      final message = e is AppException
          ? e.message
          : e.toString().replaceAll("Instance of '", '').replaceAll("'", '');
      debugPrint('[Blueprint][saveBlueprint] error: $e');
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Save failed: $message',
      );
      return null;
    }
  }
}
