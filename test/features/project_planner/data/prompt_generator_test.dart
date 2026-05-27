import 'package:chronyx/features/project_planner/data/prompt_generator.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/prompt_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generator = PromptGenerator();

  group('PromptGenerator', () {
    group('generate()', () {
      test('returns BlueprintPrompt with all fields populated', () {
        final result = generator.generate(
          goalDescription: 'Learn Flutter in 30 days',
          template: PromptTemplate.learningGoal,
          durationDays: 30,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 120,
        );

        expect(result.goalDescription, 'Learn Flutter in 30 days');
        expect(result.template, PromptTemplate.learningGoal);
        expect(result.durationDays, 30);
        expect(result.difficulty, ProjectDifficulty.medium);
        expect(result.dailyTimeMinutes, 120);
        expect(result.assembledPrompt, isNotEmpty);
      });

      test('assembled prompt contains the user goal', () {
        final result = generator.generate(
          goalDescription: 'Build a SaaS MVP for task management',
          template: PromptTemplate.startupPlan,
          durationDays: 180,
          difficulty: ProjectDifficulty.hard,
          dailyTimeMinutes: 240,
        );

        expect(
          result.assembledPrompt,
          contains('Build a SaaS MVP for task management'),
        );
      });
    });

    group('duration injection', () {
      test('prompt contains the exact duration in days', () {
        final result = generator.generate(
          goalDescription: 'Test goal',
          template: PromptTemplate.custom,
          durationDays: 7,
          difficulty: ProjectDifficulty.easy,
          dailyTimeMinutes: 60,
        );

        expect(result.assembledPrompt, contains('7 days'));
      });

      test('prompt contains 365 days for max duration', () {
        final result = generator.generate(
          goalDescription: 'Year-long transformation',
          template: PromptTemplate.fitnessTransformation,
          durationDays: 365,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 60,
        );

        expect(result.assembledPrompt, contains('365 days'));
      });

      test('task expectations reference exact day count', () {
        final result = generator.generate(
          goalDescription: 'Test goal',
          template: PromptTemplate.custom,
          durationDays: 42,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 120,
        );

        expect(result.assembledPrompt, contains('exactly 42 days'));
      });
    });

    group('difficulty injection', () {
      test('easy difficulty injects 2-3 tasks per day', () {
        final result = generator.generate(
          goalDescription: 'Easy goal',
          template: PromptTemplate.custom,
          durationDays: 14,
          difficulty: ProjectDifficulty.easy,
          dailyTimeMinutes: 60,
        );

        expect(result.assembledPrompt, contains('2-3 tasks'));
        expect(result.assembledPrompt, contains('1-2 actionable todo'));
      });

      test('medium difficulty injects 3-5 tasks per day', () {
        final result = generator.generate(
          goalDescription: 'Medium goal',
          template: PromptTemplate.custom,
          durationDays: 30,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 120,
        );

        expect(result.assembledPrompt, contains('3-5 tasks'));
        expect(result.assembledPrompt, contains('2-3 actionable todo'));
      });

      test('hard difficulty injects 4-6 tasks per day', () {
        final result = generator.generate(
          goalDescription: 'Hard goal',
          template: PromptTemplate.custom,
          durationDays: 60,
          difficulty: ProjectDifficulty.hard,
          dailyTimeMinutes: 180,
        );

        expect(result.assembledPrompt, contains('4-6 tasks'));
        expect(result.assembledPrompt, contains('3-4 actionable todo'));
      });

      test('expert difficulty injects 5-8 tasks per day', () {
        final result = generator.generate(
          goalDescription: 'Expert goal',
          template: PromptTemplate.custom,
          durationDays: 90,
          difficulty: ProjectDifficulty.expert,
          dailyTimeMinutes: 240,
        );

        expect(result.assembledPrompt, contains('5-8 tasks'));
        expect(result.assembledPrompt, contains('3-5 actionable todo'));
      });

      test('difficulty label appears in configuration section', () {
        final result = generator.generate(
          goalDescription: 'Test',
          template: PromptTemplate.custom,
          durationDays: 30,
          difficulty: ProjectDifficulty.expert,
          dailyTimeMinutes: 120,
        );

        expect(result.assembledPrompt, contains('Difficulty: Expert'));
      });
    });

    group('template-specific context', () {
      test('AI Engineer Roadmap includes milestones and networking', () {
        final result = generator.generate(
          goalDescription: 'Become an ML engineer',
          template: PromptTemplate.aiEngineerRoadmap,
          durationDays: 90,
          difficulty: ProjectDifficulty.hard,
          dailyTimeMinutes: 180,
        );

        expect(result.assembledPrompt, contains('milestones'));
        expect(result.assembledPrompt, contains('Portfolio'));
        expect(result.assembledPrompt, contains('etworking'));
      });

      test(
        'Fitness Transformation includes progressive overload and rest days',
        () {
          final result = generator.generate(
            goalDescription: 'Get fit in 60 days',
            template: PromptTemplate.fitnessTransformation,
            durationDays: 60,
            difficulty: ProjectDifficulty.medium,
            dailyTimeMinutes: 60,
          );

          expect(result.assembledPrompt, contains('rogressive overload'));
          expect(result.assembledPrompt, contains('rest day'));
        },
      );

      test('Startup Plan includes research, build, test, launch phases', () {
        final result = generator.generate(
          goalDescription: 'Launch my SaaS',
          template: PromptTemplate.startupPlan,
          durationDays: 180,
          difficulty: ProjectDifficulty.hard,
          dailyTimeMinutes: 240,
        );

        expect(result.assembledPrompt, contains('Research'));
        expect(result.assembledPrompt, contains('Build'));
        expect(result.assembledPrompt, contains('Test'));
        expect(result.assembledPrompt, contains('Launch'));
      });

      test('Learning Goal includes study modules and exercises', () {
        final result = generator.generate(
          goalDescription: 'Learn Rust programming',
          template: PromptTemplate.learningGoal,
          durationDays: 30,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 120,
        );

        expect(result.assembledPrompt, contains('tudy module'));
        expect(result.assembledPrompt, contains('exercise'));
      });

      test('Custom template includes generic roadmap guidance', () {
        final result = generator.generate(
          goalDescription: 'Organize my life',
          template: PromptTemplate.custom,
          durationDays: 14,
          difficulty: ProjectDifficulty.easy,
          dailyTimeMinutes: 60,
        );

        expect(result.assembledPrompt, contains('generic'));
        expect(result.assembledPrompt, contains('daily objectives'));
      });

      test('template label appears in configuration section', () {
        final result = generator.generate(
          goalDescription: 'Test',
          template: PromptTemplate.startupPlan,
          durationDays: 90,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 120,
        );

        expect(result.assembledPrompt, contains('Template: Startup Plan'));
      });
    });

    group('JSON schema instruction', () {
      test('prompt instructs AI to return ONLY valid JSON', () {
        final result = generator.generate(
          goalDescription: 'Any goal',
          template: PromptTemplate.custom,
          durationDays: 30,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 120,
        );

        expect(result.assembledPrompt, contains('ONLY valid JSON'));
        expect(result.assembledPrompt, contains('day_number'));
        expect(result.assembledPrompt, contains('todos'));
        expect(result.assembledPrompt, contains('estimated_minutes'));
      });

      test('prompt includes schema with tasks and todos structure', () {
        final result = generator.generate(
          goalDescription: 'Any goal',
          template: PromptTemplate.custom,
          durationDays: 30,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 120,
        );

        expect(result.assembledPrompt, contains('"tasks"'));
        expect(result.assembledPrompt, contains('"todos"'));
        expect(result.assembledPrompt, contains('"title"'));
        expect(result.assembledPrompt, contains('"description"'));
      });
    });

    group('time formatting', () {
      test('formats minutes-only correctly', () {
        final result = generator.generate(
          goalDescription: 'Quick goal',
          template: PromptTemplate.custom,
          durationDays: 7,
          difficulty: ProjectDifficulty.easy,
          dailyTimeMinutes: 30,
        );

        expect(result.assembledPrompt, contains('30 minutes'));
      });

      test('formats exact hours correctly', () {
        final result = generator.generate(
          goalDescription: 'Test',
          template: PromptTemplate.custom,
          durationDays: 30,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 120,
        );

        expect(result.assembledPrompt, contains('2 hours'));
      });

      test('formats hours and minutes correctly', () {
        final result = generator.generate(
          goalDescription: 'Test',
          template: PromptTemplate.custom,
          durationDays: 30,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 90,
        );

        expect(result.assembledPrompt, contains('1 hour 30 min'));
      });
    });
  });
}
