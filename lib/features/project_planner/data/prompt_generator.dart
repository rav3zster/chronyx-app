import 'package:chronyx/features/project_planner/domain/entities/blueprint_prompt.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/prompt_template.dart';

/// Generates optimized prompts for the AI blueprint backend.
///
/// Each [PromptTemplate] injects domain-specific context, structure
/// expectations, and task-count guidance into the final prompt.
///
/// The generated prompt instructs the AI to return ONLY valid JSON
/// conforming to a strict schema.
class PromptGenerator {
  const PromptGenerator();

  /// Assemble a complete [BlueprintPrompt] from user inputs.
  BlueprintPrompt generate({
    required String goalDescription,
    required PromptTemplate template,
    required int durationDays,
    required ProjectDifficulty difficulty,
    required int dailyTimeMinutes,
  }) {
    final prompt = _buildPrompt(
      goalDescription: goalDescription,
      template: template,
      durationDays: durationDays,
      difficulty: difficulty,
      dailyTimeMinutes: dailyTimeMinutes,
    );

    return BlueprintPrompt(
      goalDescription: goalDescription,
      template: template,
      durationDays: durationDays,
      difficulty: difficulty,
      dailyTimeMinutes: dailyTimeMinutes,
      assembledPrompt: prompt,
    );
  }

  String _buildPrompt({
    required String goalDescription,
    required PromptTemplate template,
    required int durationDays,
    required ProjectDifficulty difficulty,
    required int dailyTimeMinutes,
  }) {
    final buffer = StringBuffer();

    // System instruction
    buffer.writeln(_systemInstruction);
    buffer.writeln();

    // User goal
    buffer.writeln('## USER GOAL');
    buffer.writeln(goalDescription);
    buffer.writeln();

    // Configuration
    buffer.writeln('## CONFIGURATION');
    buffer.writeln('- Template: ${template.label}');
    buffer.writeln('- Total duration: $durationDays days');
    buffer.writeln('- Difficulty: ${difficulty.label}');
    buffer.writeln(
      '- Daily time available: ${_formatMinutes(dailyTimeMinutes)}',
    );
    buffer.writeln();

    // Template-specific context
    buffer.writeln('## DOMAIN CONTEXT');
    buffer.writeln(_templateContext(template));
    buffer.writeln();

    // Task count expectations
    buffer.writeln('## TASK EXPECTATIONS');
    buffer.writeln(_taskExpectations(durationDays, difficulty));
    buffer.writeln();

    // JSON schema instruction
    buffer.writeln('## OUTPUT FORMAT');
    buffer.writeln(_jsonSchemaInstruction);

    return buffer.toString();
  }

  /// Template-specific domain context injected into the prompt.
  String _templateContext(PromptTemplate template) => switch (template) {
    PromptTemplate.aiEngineerRoadmap =>
      '''
Focus on a structured career/learning path for AI/ML engineering.
Include:
- Technical milestones (math foundations, ML frameworks, model training, deployment)
- Portfolio-building tasks (projects, papers, open-source contributions)
- Networking activities (communities, conferences, mentorship)
- Progressive complexity: fundamentals → intermediate → advanced → specialization
- Certifications or credentials where relevant''',
    PromptTemplate.fitnessTransformation =>
      '''
Focus on a progressive fitness and health transformation plan.
Include:
- Progressive overload principles (gradually increasing intensity)
- Mandatory rest days (at least 1-2 per week)
- Nutrition awareness tasks (meal planning, hydration tracking)
- Mix of cardio, strength, flexibility, and recovery
- Weekly check-in / measurement tasks
- Deload weeks every 4-6 weeks for longer plans''',
    PromptTemplate.startupPlan =>
      '''
Focus on a structured startup launch roadmap.
Follow the phases: Research → Validate → Build → Test → Launch → Grow.
Include:
- Market research and competitor analysis tasks
- Customer discovery and validation interviews
- MVP definition and iterative build sprints
- Testing and feedback collection loops
- Launch preparation (marketing, landing page, outreach)
- Post-launch growth and iteration tasks''',
    PromptTemplate.learningGoal =>
      '''
Focus on a structured learning plan for skill acquisition.
Include:
- Study modules broken into digestible daily sessions
- Hands-on exercises and practice tasks
- Spaced repetition and review days
- Mini-projects to apply learned concepts
- Progress checkpoints and self-assessments
- Resource gathering tasks (books, courses, documentation)''',
    PromptTemplate.custom =>
      '''
Create a generic but well-structured roadmap.
Include:
- Clear daily objectives with measurable outcomes
- A mix of research, execution, and review tasks
- Progressive difficulty throughout the plan
- Regular checkpoint and reflection days
- Flexibility for the user to adapt tasks to their specific domain''',
  };

  /// Task count expectations based on duration and difficulty.
  String _taskExpectations(int durationDays, ProjectDifficulty difficulty) {
    final tasksPerDay = switch (difficulty) {
      ProjectDifficulty.easy => '2-3',
      ProjectDifficulty.medium => '3-5',
      ProjectDifficulty.hard => '4-6',
      ProjectDifficulty.expert => '5-8',
    };

    final todosPerTask = switch (difficulty) {
      ProjectDifficulty.easy => '1-2',
      ProjectDifficulty.medium => '2-3',
      ProjectDifficulty.hard => '3-4',
      ProjectDifficulty.expert => '3-5',
    };

    return '''
- Generate exactly $durationDays days of content
- Each day should have $tasksPerDay tasks
- Each task should have $todosPerTask actionable todo items (sub-steps)
- Tasks should be completable within the daily time budget
- Earlier days should be simpler; increase complexity progressively''';
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return '$hours hour${hours > 1 ? 's' : ''}';
    return '$hours hour${hours > 1 ? 's' : ''} $remaining min';
  }

  static const _systemInstruction = '''
You are a professional roadmap planner AI. Your job is to create a detailed, 
day-by-day blueprint based on the user's goal and configuration.

RULES:
- Return ONLY valid JSON. No markdown, no explanation, no extra text.
- Never return markdown. Never explain your answer.
- If uncertain about any detail, still return valid JSON using best assumptions.
- Follow the exact schema provided below.
- Every day must have tasks with actionable todo items.
- Be specific and actionable — avoid vague tasks like "work on project".
- Respect the daily time budget when estimating task durations.''';

  static const _jsonSchemaInstruction = '''
Return ONLY a valid JSON object matching this exact schema:

```json
{
  "title": "string — short project title (max 60 chars)",
  "days": [
    {
      "day_number": 1,
      "title": "string — day theme/focus (max 80 chars)",
      "estimated_minutes": 120,
      "tasks": [
        {
          "title": "string — task title (max 100 chars)",
          "description": "string — brief description of what to do",
          "estimated_minutes": 30,
          "todos": [
            "string — actionable sub-step 1",
            "string — actionable sub-step 2"
          ]
        }
      ]
    }
  ]
}
```

IMPORTANT:
- "day_number" must be sequential starting from 1
- "estimated_minutes" at day level = sum of task estimated_minutes
- Each task MUST have at least 1 todo item
- Do NOT include any text outside the JSON object
- Do NOT wrap in markdown code fences
- If uncertain, still return valid JSON using best assumptions
- Never return markdown
- Never explain your answer''';
}
