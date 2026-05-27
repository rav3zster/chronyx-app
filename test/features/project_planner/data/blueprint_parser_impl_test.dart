import 'package:chronyx/features/project_planner/data/repositories/blueprint_parser_impl.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/prompt_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = BlueprintParserImpl();

  group('BlueprintParserImpl', () {
    group('generatePrompt()', () {
      test(
        'delegates to PromptGenerator and returns valid BlueprintPrompt',
        () {
          final result = parser.generatePrompt(
            goalDescription: 'Master Kubernetes',
            template: PromptTemplate.aiEngineerRoadmap,
            durationDays: 90,
            difficulty: ProjectDifficulty.hard,
            dailyTimeMinutes: 180,
          );

          expect(result.goalDescription, 'Master Kubernetes');
          expect(result.template, PromptTemplate.aiEngineerRoadmap);
          expect(result.durationDays, 90);
          expect(result.difficulty, ProjectDifficulty.hard);
          expect(result.dailyTimeMinutes, 180);
          expect(result.assembledPrompt, isNotEmpty);
          expect(result.assembledPrompt, contains('Master Kubernetes'));
          expect(result.assembledPrompt, contains('90 days'));
        },
      );

      test('works with all templates without error', () {
        for (final template in PromptTemplate.values) {
          final result = parser.generatePrompt(
            goalDescription: 'Test goal for ${template.label}',
            template: template,
            durationDays: template.defaultDurationDays,
            difficulty: ProjectDifficulty.medium,
            dailyTimeMinutes: template.defaultDailyTimeMinutes,
          );

          expect(
            result.assembledPrompt,
            isNotEmpty,
            reason: '${template.label} should produce a non-empty prompt',
          );
          expect(
            result.assembledPrompt,
            contains(template.label),
            reason: '${template.label} should appear in prompt',
          );
        }
      });

      test('minimum duration (7 days) generates valid prompt', () {
        final result = parser.generatePrompt(
          goalDescription: 'Sprint challenge',
          template: PromptTemplate.custom,
          durationDays: 7,
          difficulty: ProjectDifficulty.easy,
          dailyTimeMinutes: 30,
        );

        expect(result.assembledPrompt, contains('7 days'));
        expect(result.durationDays, 7);
      });

      test('maximum duration (365 days) generates valid prompt', () {
        final result = parser.generatePrompt(
          goalDescription: 'Year-long journey',
          template: PromptTemplate.fitnessTransformation,
          durationDays: 365,
          difficulty: ProjectDifficulty.expert,
          dailyTimeMinutes: 60,
        );

        expect(result.assembledPrompt, contains('365 days'));
        expect(result.durationDays, 365);
      });
    });

    group('parseBlueprint()', () {
      test('parses valid JSON response', () {
        const response =
            '{"title":"Test","days":[{"day_number":1,"title":"Day 1","estimated_minutes":60,"tasks":[{"title":"Task 1","description":"Do it","estimated_minutes":60,"todos":["Step 1"]}]}]}';
        final result = parser.parseBlueprint(response);
        expect(result.title, 'Test');
        expect(result.days, hasLength(1));
      });
    });

    group('blueprintToTasks()', () {
      test('throws UnimplementedError (Phase 3)', () {
        expect(
          () => parser.blueprintToTasks(
            'project-1',
            const ParsedBlueprint(title: 'Test', days: []),
          ),
          returnsNormally,
        );
      });
    });
  });
}
