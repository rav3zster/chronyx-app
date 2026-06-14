import 'dart:async';
import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/core/providers/supabase_provider.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/todos/data/datasources/todos_remote_datasource.dart';
import 'package:chronyx/features/todos/data/datasources/todos_supabase_datasource.dart';
import 'package:chronyx/features/todos/data/repositories/todos_repository_impl.dart';
import 'package:chronyx/features/todos/domain/entities/todo.dart';
import 'package:chronyx/features/todos/domain/repositories/todos_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chronyx/core/services/notification_service.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final todosRemoteDataSourceProvider = Provider<TodosRemoteDataSource>((ref) {
  return TodosSupabaseDataSource(ref.watch(supabaseClientProvider));
});

final todosRepositoryProvider = Provider<TodosRepository>((ref) {
  return TodosRepositoryImpl(ref.watch(todosRemoteDataSourceProvider));
});

// ── To-Do items state notifier ────────────────────────────────────────────────

final todosProvider = AsyncNotifierProvider<TodosNotifier, List<Todo>>(
  TodosNotifier.new,
);

class TodosNotifier extends AsyncNotifier<List<Todo>> {
  TodosRepository get _repository => ref.read(todosRepositoryProvider);

  @override
  Future<List<Todo>> build() async {
    final authState = ref.watch(authProvider);
    if (!authState.hasValue || authState.value == null) {
      return <Todo>[];
    }
    return _repository.fetchTodos();
  }

  Future<void> refreshTodos() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.fetchTodos());
  }

  Future<Todo> createTodo({
    required String title,
    String? notes,
    TodoStatus status = TodoStatus.pending,
    TodoPriority priority = TodoPriority.medium,
    String? category,
    DateTime? dueDate,
    DateTime? reminderTime,
    int estimatedMinutes = 0,
    String? projectId,
    String? goalId,
    String? habitId,
    String? recurrence,
    String? parentId,
    TodoEnergyLevel energyLevel = TodoEnergyLevel.medium,
    List<String> tags = const [],
    List<DateTime> reminderTimes = const [],
    List<String> blockedByIds = const [],
  }) async {
    final previous = state.value ?? <Todo>[];
    state = const AsyncLoading();
    try {
      final created = await _repository.createTodo(
        title: title,
        notes: notes,
        status: status,
        priority: priority,
        category: category,
        dueDate: dueDate,
        reminderTime: reminderTime,
        estimatedMinutes: estimatedMinutes,
        projectId: projectId,
        goalId: goalId,
        habitId: habitId,
        recurrence: recurrence,
        parentId: parentId,
        energyLevel: energyLevel,
        tags: tags,
        reminderTimes: reminderTimes,
        blockedByIds: blockedByIds,
      );
      if (created.reminderTime != null || created.reminderTimes.isNotEmpty) {
        ref.read(notificationServiceProvider).scheduleTodoReminder(created);
      }
      final list = await _repository.fetchTodos();
      state = AsyncData(list);
      return created;
    } catch (e, st) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Todo> updateTodo({
    required String id,
    String? title,
    String? notes,
    TodoStatus? status,
    TodoPriority? priority,
    String? category,
    DateTime? dueDate,
    DateTime? reminderTime,
    int? estimatedMinutes,
    String? projectId,
    String? goalId,
    String? habitId,
    String? recurrence,
    String? parentId,
    TodoEnergyLevel? energyLevel,
    List<String>? tags,
    List<DateTime>? reminderTimes,
    List<String>? blockedByIds,
    bool clearDueDate = false,
    bool clearReminderTime = false,
    bool clearParentId = false,
  }) async {
    final previous = state.value ?? <Todo>[];
    state = const AsyncLoading();
    try {
      final updated = await _repository.updateTodo(
        id: id,
        title: title,
        notes: notes,
        status: status,
        priority: priority,
        category: category,
        dueDate: dueDate,
        reminderTime: reminderTime,
        estimatedMinutes: estimatedMinutes,
        projectId: projectId,
        goalId: goalId,
        habitId: habitId,
        recurrence: recurrence,
        parentId: parentId,
        energyLevel: energyLevel,
        tags: tags,
        reminderTimes: reminderTimes,
        blockedByIds: blockedByIds,
        clearDueDate: clearDueDate,
        clearReminderTime: clearReminderTime,
        clearParentId: clearParentId,
      );
      if ((updated.reminderTime != null || updated.reminderTimes.isNotEmpty) && !updated.isCompleted) {
        ref.read(notificationServiceProvider).scheduleTodoReminder(updated);
      } else {
        ref.read(notificationServiceProvider).cancelTodoReminder(updated.id);
      }
      final list = await _repository.fetchTodos();
      state = AsyncData(list);
      return updated;
    } catch (e, st) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> deleteTodo({required String id}) async {
    final previous = state.value ?? <Todo>[];
    state = const AsyncLoading();
    try {
      await _repository.deleteTodo(id: id);
      ref.read(notificationServiceProvider).cancelTodoReminder(id);
      final list = await _repository.fetchTodos();
      state = AsyncData(list);
    } catch (e, st) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> toggleTodoStatus(String id) async {
    var currentList = state.value ?? <Todo>[];
    if (currentList.isEmpty || !currentList.any((t) => t.id == id)) {
      try {
        currentList = await _repository.fetchTodos();
        state = AsyncData(currentList);
      } catch (_) {
        // Fallback to whatever we had
      }
    }

    final todoIndex = currentList.indexWhere((t) => t.id == id);
    if (todoIndex == -1) {
      debugPrint('[TodosNotifier] To-Do $id not found, cannot toggle status.');
      return;
    }
    final todo = currentList[todoIndex];
    final isGoingToComplete = todo.status != TodoStatus.completed;

    if (isGoingToComplete && todo.blockedByIds.isNotEmpty) {
      final uncompletedBlockers = currentList.where((t) => todo.blockedByIds.contains(t.id) && t.status != TodoStatus.completed).toList();
      if (uncompletedBlockers.isNotEmpty) {
        final blockerNames = uncompletedBlockers.map((t) => '"${t.title}"').join(', ');
        throw ValidationException('This task is blocked by incomplete task(s): $blockerNames');
      }
    }

    final previous = currentList;
    state = const AsyncLoading();
    try {
      if (isGoingToComplete) {
        await _repository.updateTodo(
          id: id,
          status: TodoStatus.completed,
        );
        ref.read(notificationServiceProvider).cancelTodoReminder(id);

        // Handle recurrence
        if (todo.recurrence != null && todo.dueDate != null) {
          final nextDueDate = _calculateNextRecurrence(todo.dueDate!, todo.recurrence!);
          await _repository.createTodo(
            title: todo.title,
            notes: todo.notes,
            priority: todo.priority,
            category: todo.category,
            dueDate: nextDueDate,
            reminderTime: todo.reminderTime != null 
                ? _calculateNextRecurrence(todo.reminderTime!, todo.recurrence!) 
                : null,
            estimatedMinutes: todo.estimatedMinutes,
            projectId: todo.projectId,
            goalId: todo.goalId,
            habitId: todo.habitId,
            recurrence: todo.recurrence,
            parentId: todo.parentId,
          );
        }
      } else {
        await _repository.updateTodo(
          id: id,
          status: TodoStatus.pending,
        );
        if (todo.reminderTime != null) {
          ref.read(notificationServiceProvider).scheduleTodoReminder(todo.copyWith(status: TodoStatus.pending));
        }
      }

      final list = await _repository.fetchTodos();
      state = AsyncData(list);
    } catch (e, st) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(e, st);
    }
  }

  DateTime _calculateNextRecurrence(DateTime current, String pattern) {
    switch (pattern) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day, current.hour, current.minute, current.second);
      default:
        return current.add(const Duration(days: 1));
    }
  }
}

// ── Views & Query States ──────────────────────────────────────────────────────

enum TodoViewType {
  inbox,
  today,
  important,
  upcoming,
  completed,
  overdue,
  scheduled,
  noDate,
  recurring,
  all,
  calendar;

  String get label => switch (this) {
    TodoViewType.inbox => 'Inbox',
    TodoViewType.today => 'Today',
    TodoViewType.important => 'Important',
    TodoViewType.upcoming => 'Upcoming',
    TodoViewType.completed => 'Completed',
    TodoViewType.overdue => 'Overdue',
    TodoViewType.scheduled => 'Scheduled',
    TodoViewType.noDate => 'No Date',
    TodoViewType.recurring => 'Recurring',
    TodoViewType.all => 'All To-Dos',
    TodoViewType.calendar => 'Calendar',
  };

  IconData get icon => switch (this) {
    TodoViewType.inbox => Icons.inbox_rounded,
    TodoViewType.today => Icons.today_rounded,
    TodoViewType.important => Icons.star_rounded,
    TodoViewType.upcoming => Icons.calendar_month_rounded,
    TodoViewType.completed => Icons.check_circle_rounded,
    TodoViewType.overdue => Icons.error_outline_rounded,
    TodoViewType.scheduled => Icons.schedule_rounded,
    TodoViewType.noDate => Icons.explore_off_rounded,
    TodoViewType.recurring => Icons.replay_rounded,
    TodoViewType.all => Icons.list_alt_rounded,
    TodoViewType.calendar => Icons.date_range_rounded,
  };
}

final todoSearchQueryProvider = StateProvider<String>((ref) => "");

final todoSelectedViewProvider = StateProvider<TodoViewType>((ref) => TodoViewType.inbox);

final todoSelectionModeProvider = StateProvider<bool>((ref) => false);
final todoSelectedIdsProvider = StateProvider<Set<String>>((ref) => const {});
final todoGroupBySectionProvider = StateProvider<bool>((ref) => false);

final todoOrderProvider = StateNotifierProvider<TodoOrderNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TodoOrderNotifier(prefs);
});

class TodoOrderNotifier extends StateNotifier<List<String>> {
  TodoOrderNotifier(this._prefs) : super([]) {
    _loadOrder();
  }

  final SharedPreferences _prefs;
  static const _key = 'todo_order_global';

  void _loadOrder() {
    state = _prefs.getStringList(_key) ?? [];
  }

  Future<void> updateOrder(List<String> newOrder) async {
    state = newOrder;
    await _prefs.setStringList(_key, newOrder);
  }
}

class TodoFilters {
  const TodoFilters({
    this.category,
    this.priority,
    this.status,
  });

  final String? category;
  final TodoPriority? priority;
  final TodoStatus? status;

  TodoFilters copyWith({
    String? category,
    TodoPriority? priority,
    TodoStatus? status,
    bool clearCategory = false,
    bool clearPriority = false,
    bool clearStatus = false,
  }) {
    return TodoFilters(
      category: clearCategory ? null : (category ?? this.category),
      priority: clearPriority ? null : (priority ?? this.priority),
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}

final todoFiltersProvider = StateProvider<TodoFilters>((ref) => const TodoFilters());

// ── Filtered Flat list of To-Dos ──────────────────────────────────────────────

final filteredTodosProvider = Provider<List<Todo>>((ref) {
  final todosAsync = ref.watch(todosProvider);
  final allTodos = todosAsync.value ?? <Todo>[];
  final view = ref.watch(todoSelectedViewProvider);
  final search = ref.watch(todoSearchQueryProvider).trim().toLowerCase();
  final filters = ref.watch(todoFiltersProvider);
  final orderList = ref.watch(todoOrderProvider);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  // 1. Filter by view type
  List<Todo> viewFiltered = allTodos.where((todo) {
    switch (view) {
      case TodoViewType.inbox:
        // Root items that are not completed/archived and optionally don't belong to goal/habit/project
        return todo.parentId == null && todo.status != TodoStatus.completed && todo.status != TodoStatus.archived;
      case TodoViewType.today:
        if (todo.dueDate == null) return false;
        return todo.dueDate!.isBefore(todayEnd) && todo.status != TodoStatus.completed && todo.status != TodoStatus.archived;
      case TodoViewType.important:
        return (todo.priority == TodoPriority.high || todo.priority == TodoPriority.critical) &&
            todo.status != TodoStatus.completed && todo.status != TodoStatus.archived;
      case TodoViewType.upcoming:
        if (todo.dueDate == null) return false;
        return todo.dueDate!.isAfter(todayStart) && todo.status != TodoStatus.completed && todo.status != TodoStatus.archived;
      case TodoViewType.completed:
        return todo.status == TodoStatus.completed;
      case TodoViewType.overdue:
        if (todo.dueDate == null) return false;
        return todo.dueDate!.isBefore(todayStart) && todo.status != TodoStatus.completed && todo.status != TodoStatus.archived;
      case TodoViewType.scheduled:
        return todo.dueDate != null && todo.status != TodoStatus.completed && todo.status != TodoStatus.archived;
      case TodoViewType.noDate:
        return todo.dueDate == null && todo.status != TodoStatus.completed && todo.status != TodoStatus.archived;
      case TodoViewType.recurring:
        return todo.recurrence != null && todo.status != TodoStatus.completed && todo.status != TodoStatus.archived;
      case TodoViewType.all:
      case TodoViewType.calendar:
        return true;
    }
  }).toList();

  // 2. Filter by search query (including tags via '#' in title/notes)
  if (search.isNotEmpty) {
    viewFiltered = viewFiltered.where((todo) {
      final titleMatch = todo.title.toLowerCase().contains(search);
      final notesMatch = (todo.notes ?? '').toLowerCase().contains(search);
      final categoryMatch = (todo.category ?? '').toLowerCase().contains(search);
      final priorityMatch = todo.priority.label.toLowerCase().contains(search);
      final statusMatch = todo.status.label.toLowerCase().contains(search);
      final energyMatch = todo.energyLevel.label.toLowerCase().contains(search);
      
      // Date match
      bool dateMatch = false;
      if (todo.dueDate != null) {
        final formattedDate = '${todo.dueDate!.day}/${todo.dueDate!.month}/${todo.dueDate!.year}';
        dateMatch = formattedDate.contains(search) || todo.dueDate!.toIso8601String().contains(search);
      }

      // Tags match (both array tags and inline hashtags)
      final searchClean = search.startsWith('#') ? search.substring(1) : search;
      final tagsMatch = todo.tags.any((tag) => tag.toLowerCase().contains(searchClean));
      final hasHashTag = search.startsWith('#');
      final inlineTagMatch = hasHashTag && (todo.title.toLowerCase().contains(search) || (todo.notes ?? '').toLowerCase().contains(search));

      return titleMatch || notesMatch || categoryMatch || priorityMatch || statusMatch || energyMatch || dateMatch || tagsMatch || inlineTagMatch;
    }).toList();
  }

  // 3. Filter by Category
  if (filters.category != null) {
    viewFiltered = viewFiltered.where((todo) => todo.category == filters.category).toList();
  }

  // 4. Filter by Priority
  if (filters.priority != null) {
    viewFiltered = viewFiltered.where((todo) => todo.priority == filters.priority).toList();
  }

  // 5. Filter by Status
  if (filters.status != null) {
    viewFiltered = viewFiltered.where((todo) => todo.status == filters.status).toList();
  }

  // 6. Sort by drag-and-drop index from todoOrderProvider
  viewFiltered.sort((a, b) {
    final idxA = orderList.indexOf(a.id);
    final idxB = orderList.indexOf(b.id);
    if (idxA != -1 && idxB != -1) {
      return idxA.compareTo(idxB);
    }
    if (idxA != -1) return -1;
    if (idxB != -1) return 1;
    final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return timeB.compareTo(timeA); // Newest first fallback
  });

  return viewFiltered;
});

// ── To-Do Tree builder (Nested Subtask support) ────────────────────────────────

final todoTreeProvider = Provider.family<List<Todo>, List<Todo>>((ref, flatList) {
  final Map<String, List<Todo>> parentToChildren = {};
  final List<Todo> roots = [];
  final orderList = ref.watch(todoOrderProvider);

  for (final todo in flatList) {
    if (todo.parentId == null) {
      roots.add(todo);
    } else {
      parentToChildren.putIfAbsent(todo.parentId!, () => []).add(todo);
    }
  }

  List<Todo> buildTree(List<Todo> list) {
    return list.map((item) {
      final children = parentToChildren[item.id] ?? [];
      if (children.isEmpty) return item;
      
      // Sort subtasks by drag-and-drop orderList index
      children.sort((a, b) {
        final idxA = orderList.indexOf(a.id);
        final idxB = orderList.indexOf(b.id);
        if (idxA != -1 && idxB != -1) {
          return idxA.compareTo(idxB);
        }
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now());
      });

      final nestedChildren = buildTree(children);
      return item.copyWith(subtasks: nestedChildren);
    }).toList();
  }

  return buildTree(roots);
});

// ── Calendar View Providers ───────────────────────────────────────────────────

enum CalendarViewType { day, week, month, agenda }

final calendarSelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final calendarViewTypeProvider = StateProvider<CalendarViewType>((ref) => CalendarViewType.week);
