import 'dart:convert';

import 'package:chronyx/features/project_planner/data/repositories/blueprint_parser_impl.dart';
import 'package:chronyx/features/project_planner/domain/entities/blueprint_parse_exception.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = BlueprintParserImpl();

  /// Helper to build a minimal valid blueprint JSON string.
  String validBlueprint({
    String title = 'Test Blueprint',
    int dayCount = 1,
    int tasksPerDay = 1,
    List<String>? todos,
  }) {
    final taskTodos = todos ?? ['Step 1', 'Step 2'];
    final tasks = List.generate(
      tasksPerDay,
      (t) => {
        'title': 'Task ${t + 1}',
        'description': 'Description for task ${t + 1}',
        'estimated_minutes': 30,
        'todos': taskTodos,
      },
    );
    final days = List.generate(
      dayCount,
      (d) => {
        'day_number': d + 1,
        'title': 'Day ${d + 1} Focus',
        'estimated_minutes': 30 * tasksPerDay,
        'tasks': tasks,
      },
    );
    return jsonEncode({'title': title, 'days': days});
  }

  group('BlueprintParserImpl.parseBlueprint()', () {
    // ─────────────────────────────────────────────────────────────
    // JSON Extraction
    // ─────────────────────────────────────────────────────────────

    group('JSON extraction', () {
      test('parses plain JSON object', () {
        final result = parser.parseBlueprint(validBlueprint());
        expect(result.title, 'Test Blueprint');
        expect(result.days, hasLength(1));
      });

      test('strips ```json markdown fences', () {
        final json = validBlueprint(title: 'Fenced');
        final wrapped = '```json\n$json\n```';
        final result = parser.parseBlueprint(wrapped);
        expect(result.title, 'Fenced');
      });

      test('strips ``` markdown fences without language tag', () {
        final json = validBlueprint(title: 'Plain Fence');
        final wrapped = '```\n$json\n```';
        final result = parser.parseBlueprint(wrapped);
        expect(result.title, 'Plain Fence');
      });

      test('extracts JSON preceded by explanation text', () {
        final json = validBlueprint(title: 'After Explanation');
        final withExplanation =
            "Here's your roadmap! I've created a detailed plan:\n\n$json";
        final result = parser.parseBlueprint(withExplanation);
        expect(result.title, 'After Explanation');
      });

      test('extracts JSON with trailing text', () {
        final json = validBlueprint(title: 'With Trailing');
        final withTrailing = '$json\n\nHope this helps!';
        final result = parser.parseBlueprint(withTrailing);
        expect(result.title, 'With Trailing');
      });

      test('handles explanation + markdown fenced JSON', () {
        final json = validBlueprint(title: 'Mixed');
        final mixed =
            "Sure! Here's your blueprint:\n\n```json\n$json\n```\n\nLet me know if you need changes.";
        final result = parser.parseBlueprint(mixed);
        expect(result.title, 'Mixed');
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Malformed JSON
    // ─────────────────────────────────────────────────────────────

    group('malformed JSON', () {
      test('throws BlueprintParseException for empty string', () {
        expect(
          () => parser.parseBlueprint(''),
          throwsA(isA<BlueprintParseException>()),
        );
      });

      test('throws BlueprintParseException for whitespace-only string', () {
        expect(
          () => parser.parseBlueprint('   \n\t  '),
          throwsA(
            isA<BlueprintParseException>().having(
              (e) => e.message,
              'message',
              contains('empty'),
            ),
          ),
        );
      });

      test('throws BlueprintParseException for no JSON at all', () {
        expect(
          () => parser.parseBlueprint('This is just plain text with no JSON.'),
          throwsA(isA<BlueprintParseException>()),
        );
      });

      test('throws BlueprintParseException for invalid JSON syntax', () {
        expect(
          () => parser.parseBlueprint('{title: "broken", days: [}'),
          throwsA(
            isA<BlueprintParseException>().having(
              (e) => e.message,
              'message',
              contains('malformed JSON'),
            ),
          ),
        );
      });

      test('throws BlueprintParseException for truncated response', () {
        final truncated =
            '{"title":"Test","days":[{"day_number":1,"title":"Day';
        expect(
          () => parser.parseBlueprint(truncated),
          throwsA(isA<BlueprintParseException>()),
        );
      });

      test('throws for JSON array instead of object', () {
        expect(
          () => parser.parseBlueprint('[1, 2, 3]'),
          throwsA(
            isA<BlueprintParseException>().having(
              (e) => e.message,
              'message',
              contains('Could not find valid JSON'),
            ),
          ),
        );
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Missing Fields
    // ─────────────────────────────────────────────────────────────

    group('missing fields', () {
      test('missing title defaults to "Untitled Blueprint"', () {
        final json = jsonEncode({
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 60,
              'tasks': [
                {
                  'title': 'Task 1',
                  'description': 'Do it',
                  'estimated_minutes': 60,
                  'todos': ['Step 1'],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.title, 'Untitled Blueprint');
      });

      test('missing days array throws error', () {
        final json = jsonEncode({'title': 'No Days'});
        expect(
          () => parser.parseBlueprint(json),
          throwsA(
            isA<BlueprintParseException>().having(
              (e) => e.issues.first.field,
              'field',
              'days',
            ),
          ),
        );
      });

      test('empty days array throws error', () {
        final json = jsonEncode({'title': 'Empty Days', 'days': []});
        expect(
          () => parser.parseBlueprint(json),
          throwsA(isA<BlueprintParseException>()),
        );
      });

      test('missing task title skips that task', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 60,
              'tasks': [
                {
                  'description': 'No title here',
                  'estimated_minutes': 30,
                  'todos': ['Step'],
                },
                {
                  'title': 'Valid Task',
                  'description': 'Has title',
                  'estimated_minutes': 30,
                  'todos': ['Step'],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks, hasLength(1));
        expect(result.days.first.tasks.first.title, 'Valid Task');
      });

      test('empty tasks array skips that day', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Empty Day',
              'estimated_minutes': 60,
              'tasks': [],
            },
            {
              'day_number': 2,
              'title': 'Valid Day',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                  'todos': ['Do it'],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days, hasLength(1));
        expect(result.days.first.dayNumber, 2);
      });

      test('missing day title defaults to "Day N"', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 5,
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                  'todos': [],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.title, 'Day 5');
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Duration Clamping
    // ─────────────────────────────────────────────────────────────

    group('duration clamping', () {
      test('day_number clamped to durationDays max', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 999,
              'title': 'Way Beyond',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                  'todos': [],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json, durationDays: 30);
        expect(result.days.first.dayNumber, 30);
      });

      test('day_number clamped to minimum 1', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 0,
              'title': 'Zero Day',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                  'todos': [],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json, durationDays: 30);
        expect(result.days.first.dayNumber, 1);
      });

      test('estimated_minutes clamped to 1-480 range', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 9999,
              'tasks': [
                {
                  'title': 'Huge Task',
                  'description': 'Desc',
                  'estimated_minutes': 600,
                  'todos': [],
                },
                {
                  'title': 'Tiny Task',
                  'description': 'Desc',
                  'estimated_minutes': 0,
                  'todos': [],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks[0].estimatedMinutes, 480);
        expect(result.days.first.tasks[1].estimatedMinutes, 1);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Whitespace Normalization
    // ─────────────────────────────────────────────────────────────

    group('whitespace normalization', () {
      test('trims whitespace from title', () {
        final json = jsonEncode({
          'title': '  Spaced Title  ',
          'days': [
            {
              'day_number': 1,
              'title': '  Day One  ',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': '  Task One  ',
                  'description': '  Desc  ',
                  'estimated_minutes': 30,
                  'todos': ['  Step 1  ', '  Step 2  '],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.title, 'Spaced Title');
        expect(result.days.first.title, 'Day One');
        expect(result.days.first.tasks.first.title, 'Task One');
        expect(result.days.first.tasks.first.description, 'Desc');
        expect(result.days.first.tasks.first.todos, ['Step 1', 'Step 2']);
      });

      test('empty whitespace-only todos are filtered out', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                  'todos': ['Valid', '   ', '', 'Also Valid'],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks.first.todos, ['Valid', 'Also Valid']);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Todo Defaults
    // ─────────────────────────────────────────────────────────────

    group('todo defaults', () {
      test('missing todos defaults to empty list', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'No Todos Task',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks.first.todos, isEmpty);
      });

      test('null todos defaults to empty list', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'Null Todos',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                  'todos': null,
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks.first.todos, isEmpty);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Deduplication
    // ─────────────────────────────────────────────────────────────

    group('deduplication', () {
      test('duplicate task titles within a day are merged', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 60,
              'tasks': [
                {
                  'title': 'Setup Environment',
                  'description': 'First occurrence',
                  'estimated_minutes': 30,
                  'todos': ['Install Node', 'Install Flutter'],
                },
                {
                  'title': 'Setup Environment',
                  'description': 'Duplicate',
                  'estimated_minutes': 30,
                  'todos': ['Install Docker'],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks, hasLength(1));
        expect(result.days.first.tasks.first.title, 'Setup Environment');
        expect(result.days.first.tasks.first.description, 'First occurrence');
        expect(result.days.first.tasks.first.todos, [
          'Install Node',
          'Install Flutter',
          'Install Docker',
        ]);
      });

      test('deduplication is case-insensitive', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 60,
              'tasks': [
                {
                  'title': 'Read Documentation',
                  'description': 'First',
                  'estimated_minutes': 30,
                  'todos': ['Read API docs'],
                },
                {
                  'title': 'read documentation',
                  'description': 'Duplicate lower',
                  'estimated_minutes': 30,
                  'todos': ['Read SDK docs'],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks, hasLength(1));
        expect(result.days.first.tasks.first.title, 'Read Documentation');
        expect(result.days.first.tasks.first.todos, [
          'Read API docs',
          'Read SDK docs',
        ]);
      });

      test('tasks with different titles are not merged', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 60,
              'tasks': [
                {
                  'title': 'Task A',
                  'description': 'A',
                  'estimated_minutes': 30,
                  'todos': ['A1'],
                },
                {
                  'title': 'Task B',
                  'description': 'B',
                  'estimated_minutes': 30,
                  'todos': ['B1'],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks, hasLength(2));
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Error Handling
    // ─────────────────────────────────────────────────────────────

    group('error handling', () {
      test('BlueprintParseException has user-friendly message', () {
        try {
          parser.parseBlueprint('not json at all');
          fail('Should have thrown');
        } on BlueprintParseException catch (e) {
          expect(e.message, isNotEmpty);
          expect(e.hasErrors, isTrue);
        }
      });

      test('BlueprintParseException includes field-level issues', () {
        try {
          parser.parseBlueprint('{"title":"Test"}');
          fail('Should have thrown');
        } on BlueprintParseException catch (e) {
          expect(e.issues, isNotEmpty);
          expect(e.issues.first.field, 'days');
        }
      });

      test('exception distinguishes warnings from errors', () {
        try {
          parser.parseBlueprint('{"days":[]}');
          fail('Should have thrown');
        } on BlueprintParseException catch (e) {
          expect(e.hasErrors, isTrue);
          // Title missing is a warning, empty days is an error
          expect(e.issues.length, greaterThanOrEqualTo(2));
        }
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Blueprint to Tasks Conversion
    // ─────────────────────────────────────────────────────────────

    group('blueprintToTasks()', () {
      test('converts blueprint days and tasks to ProjectTask list', () {
        final blueprint = ParsedBlueprint(
          title: 'Test',
          days: [
            DayPlan(
              dayNumber: 1,
              title: 'Day 1',
              estimatedMinutes: 60,
              tasks: const [
                BlueprintTask(
                  title: 'Task A',
                  description: 'Do A',
                  estimatedMinutes: 30,
                  todos: ['Step 1'],
                ),
                BlueprintTask(
                  title: 'Task B',
                  description: 'Do B',
                  estimatedMinutes: 30,
                  todos: ['Step 1', 'Step 2'],
                ),
              ],
            ),
            DayPlan(
              dayNumber: 2,
              title: 'Day 2',
              estimatedMinutes: 45,
              tasks: const [
                BlueprintTask(
                  title: 'Task C',
                  description: 'Do C',
                  estimatedMinutes: 45,
                  todos: ['Step 1'],
                ),
              ],
            ),
          ],
        );

        final tasks = parser.blueprintToTasks('proj-123', blueprint);

        expect(tasks, hasLength(3));
        expect(tasks[0].projectId, 'proj-123');
        expect(tasks[0].dayNumber, 1);
        expect(tasks[0].title, 'Task A');
        expect(tasks[0].description, 'Do A');
        expect(tasks[0].sortOrder, 0);
        expect(tasks[1].sortOrder, 1);
        expect(tasks[2].sortOrder, 2);
        expect(tasks[2].dayNumber, 2);
        expect(tasks[2].title, 'Task C');
      });

      test('returns empty list for blueprint with no days', () {
        const blueprint = ParsedBlueprint(title: 'Empty', days: []);
        final tasks = parser.blueprintToTasks('proj-1', blueprint);
        expect(tasks, isEmpty);
      });

      test('all tasks have pending status', () {
        final blueprint = ParsedBlueprint(
          title: 'Test',
          days: [
            DayPlan(
              dayNumber: 1,
              title: 'Day 1',
              estimatedMinutes: 30,
              tasks: const [
                BlueprintTask(
                  title: 'Task',
                  description: 'Desc',
                  estimatedMinutes: 30,
                  todos: [],
                ),
              ],
            ),
          ],
        );

        final tasks = parser.blueprintToTasks('proj-1', blueprint);
        for (final task in tasks) {
          expect(task.status, ProjectTaskStatus.pending);
        }
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Type Coercion
    // ─────────────────────────────────────────────────────────────

    group('type coercion', () {
      test('handles estimated_minutes as string', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': '45',
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': '30',
                  'todos': [],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks.first.estimatedMinutes, 30);
      });

      test('handles day_number as string', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': '3',
              'title': 'Day 3',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                  'todos': [],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.dayNumber, 3);
      });

      test('handles estimated_minutes as double', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'day_number': 1,
              'title': 'Day 1',
              'estimated_minutes': 45.5,
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': 29.9,
                  'todos': [],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days.first.tasks.first.estimatedMinutes, 29);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // Multi-day Blueprint
    // ─────────────────────────────────────────────────────────────

    group('multi-day parsing', () {
      test('parses multiple days correctly', () {
        final result = parser.parseBlueprint(
          validBlueprint(dayCount: 5, tasksPerDay: 3),
        );
        expect(result.days, hasLength(5));
        for (final day in result.days) {
          expect(day.tasks, hasLength(3));
        }
      });

      test('missing day_number falls back to index+1', () {
        final json = jsonEncode({
          'title': 'Test',
          'days': [
            {
              'title': 'First',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                  'todos': [],
                },
              ],
            },
            {
              'title': 'Second',
              'estimated_minutes': 30,
              'tasks': [
                {
                  'title': 'Task',
                  'description': 'Desc',
                  'estimated_minutes': 30,
                  'todos': [],
                },
              ],
            },
          ],
        });
        final result = parser.parseBlueprint(json);
        expect(result.days[0].dayNumber, 1);
        expect(result.days[1].dayNumber, 2);
      });
    });
  });
}
