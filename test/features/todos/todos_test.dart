import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronyx/features/todos/domain/entities/todo.dart';
import 'package:chronyx/features/todos/data/models/todo_model.dart';
import 'package:chronyx/features/todos/presentation/providers/todos_providers.dart';
import 'package:chronyx/features/todos/presentation/utils/todo_nli_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';

class FakeTodosNotifier extends TodosNotifier {
  FakeTodosNotifier(this.todos);
  final List<Todo> todos;

  @override
  Future<List<Todo>> build() async => todos;
}

void main() {
  group('To-Do Domain & Data Tests', () {
    test('TodoStatus.fromJson maps correct keys', () {
      expect(TodoStatus.fromJson('pending'), TodoStatus.pending);
      expect(TodoStatus.fromJson('in_progress'), TodoStatus.inProgress);
      expect(TodoStatus.fromJson('completed'), TodoStatus.completed);
      expect(TodoStatus.fromJson('archived'), TodoStatus.archived);
      expect(TodoStatus.fromJson('unknown'), TodoStatus.pending);
      expect(TodoStatus.fromJson(null), TodoStatus.pending);
    });

    test('TodoPriority.fromJson maps correct keys', () {
      expect(TodoPriority.fromJson('low'), TodoPriority.low);
      expect(TodoPriority.fromJson('medium'), TodoPriority.medium);
      expect(TodoPriority.fromJson('high'), TodoPriority.high);
      expect(TodoPriority.fromJson('critical'), TodoPriority.critical);
      expect(TodoPriority.fromJson('unknown'), TodoPriority.medium);
      expect(TodoPriority.fromJson(null), TodoPriority.medium);
    });

    test('TodoModel.fromJson and toJson match', () {
      final json = {
        'id': 'todo-1',
        'user_id': 'user-123',
        'title': 'Test Todo',
        'notes': 'Some notes',
        'status': 'in_progress',
        'priority': 'high',
        'category': 'Work',
        'due_date': '2026-06-15T10:00:00.000Z',
        'reminder_time': null,
        'estimated_minutes': 45,
        'project_id': null,
        'goal_id': null,
        'habit_id': null,
        'recurrence': 'daily',
        'parent_id': null,
        'created_at': '2026-06-14T12:00:00.000Z',
        'updated_at': null,
        'completed_at': null,
      };

      final model = TodoModel.fromJson(json);
      expect(model.id, 'todo-1');
      expect(model.userId, 'user-123');
      expect(model.title, 'Test Todo');
      expect(model.status, TodoStatus.inProgress);
      expect(model.priority, TodoPriority.high);
      expect(model.estimatedMinutes, 45);
      expect(model.recurrence, 'daily');

      final serialized = model.toJson();
      expect(serialized['id'], 'todo-1');
      expect(serialized['status'], 'in_progress');
      expect(serialized['priority'], 'high');
      expect(serialized['estimated_minutes'], 45);
    });
  });

  group('To-Do Riverpod Providers & Filter Derivations', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12, 0);
    final tomorrow = today.add(const Duration(days: 1));

    final dummyTodos = [
      Todo(
        id: '1',
        userId: 'u',
        title: 'Inbox Task',
        status: TodoStatus.pending,
        priority: TodoPriority.medium,
        createdAt: today,
      ),
      Todo(
        id: '2',
        userId: 'u',
        title: 'Today Task',
        status: TodoStatus.pending,
        priority: TodoPriority.high,
        dueDate: today,
        createdAt: today,
      ),
      Todo(
        id: '3',
        userId: 'u',
        title: 'Important Tomorrow Task',
        status: TodoStatus.pending,
        priority: TodoPriority.critical,
        dueDate: tomorrow,
        createdAt: today,
      ),
      Todo(
        id: '4',
        userId: 'u',
        title: 'Completed Task',
        status: TodoStatus.completed,
        priority: TodoPriority.low,
        createdAt: today,
      ),
      Todo(
        id: '5',
        userId: 'u',
        title: 'Parent Task',
        status: TodoStatus.pending,
        priority: TodoPriority.medium,
        createdAt: today,
      ),
      Todo(
        id: '6',
        userId: 'u',
        title: 'Subtask of Parent',
        status: TodoStatus.pending,
        priority: TodoPriority.low,
        parentId: '5',
        createdAt: today,
      ),
    ];

    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          todosProvider.overrideWith(() => FakeTodosNotifier(dummyTodos)),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      await container.read(todosProvider.future);
    });

    tearDown(() {
      container.dispose();
    });

    test('Inbox view returns non-subtask non-completed/non-archived items', () {
      container.read(todoSelectedViewProvider.notifier).state = TodoViewType.inbox;
      final filtered = container.read(filteredTodosProvider);
      
      // Should include tasks with no parent, not completed, not archived:
      // 'Inbox Task' (id: 1), 'Today Task' (id: 2), 'Important Tomorrow Task' (id: 3), 'Parent Task' (id: 5)
      expect(filtered.map((e) => e.id), containsAll(['1', '2', '3', '5']));
      expect(filtered.map((e) => e.id), isNot(contains('4'))); // Completed
      expect(filtered.map((e) => e.id), isNot(contains('6'))); // Subtask
    });

    test('Today view returns items due today', () {
      container.read(todoSelectedViewProvider.notifier).state = TodoViewType.today;
      final filtered = container.read(filteredTodosProvider);
      
      // Should include 'Today Task' (id: 2) only
      expect(filtered.map((e) => e.id), contains('2'));
      expect(filtered.map((e) => e.id), isNot(contains('3'))); // Tomorrow
    });

    test('Important view returns high/critical priority pending items', () {
      container.read(todoSelectedViewProvider.notifier).state = TodoViewType.important;
      final filtered = container.read(filteredTodosProvider);
      
      // Should include High (id: 2) and Critical (id: 3)
      expect(filtered.map((e) => e.id), containsAll(['2', '3']));
      expect(filtered.map((e) => e.id), isNot(contains('1'))); // Medium
    });

    test('Upcoming view returns items due after today start', () {
      container.read(todoSelectedViewProvider.notifier).state = TodoViewType.upcoming;
      final filtered = container.read(filteredTodosProvider);
      
      // Tomorrow (id: 3) is upcoming.
      expect(filtered.map((e) => e.id), contains('3'));
    });

    test('Completed view returns completed items', () {
      container.read(todoSelectedViewProvider.notifier).state = TodoViewType.completed;
      final filtered = container.read(filteredTodosProvider);
      
      expect(filtered.map((e) => e.id), contains('4'));
      expect(filtered.map((e) => e.id), isNot(contains('1')));
    });

    test('Search filter matches title, priority, status and category', () {
      container.read(todoSelectedViewProvider.notifier).state = TodoViewType.all;
      
      // Search 'Tomorrow'
      container.read(todoSearchQueryProvider.notifier).state = 'Tomorrow';
      var filtered = container.read(filteredTodosProvider);
      expect(filtered.length, 1);
      expect(filtered.first.id, '3');

      // Search 'critical' (priority)
      container.read(todoSearchQueryProvider.notifier).state = 'critical';
      filtered = container.read(filteredTodosProvider);
      expect(filtered.length, 1);
      expect(filtered.first.id, '3');
    });

    test('todoTreeProvider builds recursive subtask hierarchy correctly', () {
      container.read(todoSelectedViewProvider.notifier).state = TodoViewType.all;
      final allList = container.read(filteredTodosProvider);
      final tree = container.read(todoTreeProvider(allList));

      // Find parent item (id: 5)
      final parent = tree.firstWhere((t) => t.id == '5');
      expect(parent.subtasks, hasLength(1));
      expect(parent.subtasks.first.id, '6');
      expect(parent.subtasks.first.parentId, '5');
    });
  });

  group('To-Do Natural Language Input (NLI) Parser Tests', () {
    test('parses relative tomorrow date and time', () {
      final parsed = TodoNliParser.parse('Study DSA tomorrow at 7 PM !!!');
      expect(parsed.title, 'Study DSA');
      expect(parsed.dueDate, isNotNull);
      expect(parsed.dueDate!.hour, 19);
      expect(parsed.dueDate!.minute, 0);
      expect(parsed.priority, TodoPriority.critical);
      expect(parsed.recurrence, isNull);
    });

    test('parses weekly recurrence', () {
      final parsed = TodoNliParser.parse('Gym every Monday !!');
      expect(parsed.title, 'Gym');
      expect(parsed.recurrence, 'weekly');
      expect(parsed.priority, TodoPriority.high);
    });

    test('parses specific date', () {
      final parsed = TodoNliParser.parse('Pay fees on June 25');
      expect(parsed.title, 'Pay fees');
      expect(parsed.dueDate, isNotNull);
      expect(parsed.dueDate!.month, DateTime.june);
      expect(parsed.dueDate!.day, 25);
      expect(parsed.recurrence, isNull);
    });
  });
}

