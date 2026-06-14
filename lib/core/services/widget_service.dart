import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chronyx/core/constants/supabase_env.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/presentation/providers/todays_roadmap_provider.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/todos/domain/entities/todo.dart';
import 'package:chronyx/features/todos/presentation/providers/todos_providers.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/core/routing/app_router.dart';
import 'package:chronyx/core/routing/app_routes.dart';

class WidgetService {
  WidgetService._();

  static const _channel = MethodChannel('com.example.chronyx/widget');
  static const String _keyTasks = 'flutter.widget_tasks';
  static const String _keyProjectTitle = 'flutter.widget_project_title';
  
  static Timer? _syncDebounce;

  /// Initializes MethodChannel listeners for widget interaction
  static void initialize(WidgetRef ref) {
    _channel.setMethodCallHandler((call) async {
      debugPrint('[WidgetService] Received method call: ${call.method}');
      if (call.method == 'toggleTask') {
        final taskId = call.arguments as String?;
        if (taskId != null) {
          await _handleToggleTask(ref, taskId);
        }
      } else if (call.method == 'widgetLaunch') {
        final data = call.arguments as Map?;
        if (data != null) {
          _handleWidgetLaunch(ref, data);
        }
      } else if (call.method == 'quickAdd') {
        _handleQuickAddLaunch(ref);
      } else if (call.method == 'focusControl') {
        final action = call.arguments as String?;
        if (action != null) {
          await _handleFocusControl(ref, action);
        }
      }
    });

    // Register Riverpod listeners to automatically sync widget on changes
    ref.listen<AsyncValue<TodaysRoadmap?>>(todaysRoadmapProvider, (prev, next) {
      scheduleSync(ref);
    });

    ref.listen<AsyncValue<List<Project>>>(projectsProvider, (prev, next) {
      scheduleSync(ref);
    });

    ref.listen<AsyncValue<List<Todo>>>(todosProvider, (prev, next) {
      scheduleSync(ref);
    });

    ref.listen<AsyncValue<List<TimeEntry>>>(timeEntriesProvider, (prev, next) {
      scheduleSync(ref);
    });

    ref.listen(authProvider, (prev, next) {
      syncAuthSession().then((_) => scheduleSync(ref));
    });

    // Check launch data on start
    _checkLaunchData(ref);
    
    // Perform initial sync
    scheduleSync(ref);
  }

  static void scheduleSync(WidgetRef ref) {
    if (_syncDebounce?.isActive ?? false) _syncDebounce!.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 300), () {
      syncAllWidgets(ref);
    });
  }

  static Future<void> _checkLaunchData(WidgetRef ref) async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('getLaunchData');
      if (data != null) {
        final taskId = data['taskId'] as String?;
        if (taskId != null) {
          await _handleToggleTask(ref, taskId);
        }
        final action = data['action'] as String?;
        if (action == 'quick_add') {
          _handleQuickAddLaunch(ref);
        }
        final focusAction = data['focusAction'] as String?;
        if (focusAction != null) {
          await _handleFocusControl(ref, focusAction);
        }
        final widgetId = data['widgetId'] as int?;
        final widgetType = data['widgetType'] as String?;
        if (widgetId != null) {
          debugPrint('[WidgetService] App launched from widget $widgetId of type $widgetType');
        }
      }
    } catch (e) {
      debugPrint('[WidgetService] Error checking launch data: $e');
    }
  }

  static void _handleWidgetLaunch(WidgetRef ref, Map data) {
    final widgetId = data['widgetId'] as int?;
    final widgetType = data['widgetType'] as String?;
    final action = data['action'] as String?;
    debugPrint('[WidgetService] Real-time widget launch event: widgetId=$widgetId, type=$widgetType, action=$action');
    if (action == 'quick_add') {
      _handleQuickAddLaunch(ref);
    }
  }

  static void _handleQuickAddLaunch(WidgetRef ref) {
    try {
      final router = ref.read(appRouterProvider);
      router.push('${AppRoutes.todos}?quickAdd=true');
      debugPrint('[WidgetService] Successfully navigated to Quick Add');
    } catch (e) {
      debugPrint('[WidgetService] Error navigating to Quick Add: $e');
    }
  }

  static Future<void> _handleFocusControl(WidgetRef ref, String action) async {
    try {
      final entries = ref.read(timeEntriesProvider).valueOrNull ?? [];
      final activeSession = entries.where((e) => e.isOngoing).firstOrNull;
      if (activeSession == null) {
        debugPrint('[WidgetService] No active focus session found to control');
        return;
      }

      final notifier = ref.read(timeEntriesProvider.notifier);
      if (action == 'pause') {
        await notifier.pauseSession(sessionId: activeSession.id);
        debugPrint('[WidgetService] Successfully paused focus session');
      } else if (action == 'resume') {
        await notifier.resumeSession(sessionId: activeSession.id);
        debugPrint('[WidgetService] Successfully resumed focus session');
      } else if (action == 'stop') {
        await notifier.stopSession(sessionId: activeSession.id);
        debugPrint('[WidgetService] Successfully stopped focus session');
      }
    } catch (e) {
      debugPrint('[WidgetService] Error handling focus control action: $e');
    }
  }

  static Future<void> _handleToggleTask(WidgetRef ref, String taskId) async {
    try {
      // 1. Try toggling as To-Do first
      final repoTodo = ref.read(todosRepositoryProvider);
      final todos = await repoTodo.fetchTodos();
      final hasTodo = todos.any((t) => t.id == taskId);
      if (hasTodo) {
        await ref.read(todosProvider.notifier).toggleTodoStatus(taskId);
        debugPrint('[WidgetService] Successfully handled toggle todo: $taskId');
        return;
      }

      // 2. Try toggling as ProjectTask (fallback)
      final repo = ref.read(projectRepositoryProvider);
      final projects = await repo.fetchProjects();
      final activeProjects = projects
          .where((p) => p.status == ProjectStatus.active || p.status == ProjectStatus.draft)
          .toList();
      if (activeProjects.isEmpty) return;

      for (final project in activeProjects) {
        final tasks = await repo.fetchProjectTasks(project.id);
        final task = tasks.where((t) => t.id == taskId).firstOrNull;
        if (task != null) {
          await ref.read(projectLifecycleControllerProvider).toggleTask(
            project: project,
            tasks: tasks,
            task: task,
          );
          // Refresh providers
          ref.read(projectsProvider.notifier).refresh();
          ref.invalidate(todaysRoadmapProvider);
          debugPrint('[WidgetService] Successfully handled toggle task: $taskId');
          break;
        }
      }
    } catch (e) {
      debugPrint('[WidgetService] Error handling toggle task from widget: $e');
    }
  }

  /// Sync access token and URLs to SharedPreferences for background API calls
  static Future<void> syncAuthSession() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final prefs = await SharedPreferences.getInstance();
      
      if (session != null) {
        await prefs.setString('flutter.widget_access_token', session.accessToken);
        await prefs.setString('flutter.widget_supabase_url', SupabaseEnv.url);
        await prefs.setString('flutter.widget_supabase_anon_key', SupabaseEnv.anonKey);
        debugPrint('[WidgetService] Auth session credentials successfully synced to cache');
      } else {
        await prefs.remove('flutter.widget_access_token');
        debugPrint('[WidgetService] Auth session credentials cleared from cache');
      }
    } catch (e) {
      debugPrint('[WidgetService] Error syncing auth session: $e');
    }
  }

  /// Legacy helper kept for compatibility
  static Future<void> syncTodayTasks(TodaysRoadmap? roadmap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (roadmap == null || roadmap.tasks.isEmpty) {
        await prefs.remove(_keyTasks);
        await prefs.remove(_keyProjectTitle);
      } else {
        final tasksJson = roadmap.tasks.map((task) => {
          'id': task.id,
          'title': task.title,
          'estimatedMinutes': task.estimatedMinutes,
          'status': task.status.jsonKey,
        }).toList();

        await prefs.setString(_keyTasks, jsonEncode(tasksJson));
        await prefs.setString(_keyProjectTitle, roadmap.projectTitle);
      }
      
      // Notify Android of the update
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint('[WidgetService] Error syncing today tasks: $e');
    }
  }

  /// Rebuild configurations and states for all active pinned widgets
  static Future<void> syncAllWidgets(WidgetRef ref) async {
    try {
      // 1. Query Android OS for all active widget IDs and their types
      final List<dynamic>? widgetsList = await _channel.invokeMethod<List<dynamic>>('getActiveWidgetIds');
      if (widgetsList == null || widgetsList.isEmpty) {
        debugPrint('[WidgetService] No active widgets to sync');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      
      // Make sure auth session is synced
      await syncAuthSession();

      for (final widgetItem in widgetsList) {
        final widgetMap = Map<String, dynamic>.from(widgetItem as Map);
        final id = widgetMap['id'] as int;
        final nativeType = widgetMap['type'] as String;

        // 2. Read widget config from cache (or default to nativeType)
        final configKey = 'flutter.widget_config_$id';
        final configJson = prefs.getString(configKey);
        Map<String, dynamic> config = {'type': nativeType};
        if (configJson != null) {
          try {
            config = jsonDecode(configJson) as Map<String, dynamic>;
          } catch (_) {}
        } else {
          // Save default config
          await prefs.setString(configKey, jsonEncode(config));
        }

        final type = config['type'] ?? nativeType;
        final projectId = config['projectId'] as String?;

        // 3. Compute State based on type
        Map<String, dynamic>? stateObj;

        switch (type) {
          case 'today':
            stateObj = await _computeTodayTasks(ref);
            break;
          case 'project':
            stateObj = await _computeProjectTasks(ref, projectId);
            break;
          case 'todo':
            stateObj = await _computeTodoTasks(ref, 'all');
            break;
          case 'todo_today':
            stateObj = await _computeTodoTasks(ref, 'today');
            break;
          case 'todo_important':
            stateObj = await _computeTodoTasks(ref, 'important');
            break;
          case 'todo_inbox':
            stateObj = await _computeTodoTasks(ref, 'inbox');
            break;
          case 'stats':
            stateObj = await _computeStatsState(ref);
            break;
          case 'focus':
            stateObj = await _computeFocusState(ref);
            break;
          default:
            stateObj = await _computeTodayTasks(ref);
        }

        // 4. Save state back to SharedPreferences
        if (stateObj != null) {
          final stateKey = 'flutter.widget_state_$id';
          await prefs.setString(stateKey, jsonEncode(stateObj));
        }
      }

      // 5. Notify native side to reload all layouts
      await _channel.invokeMethod('updateWidget');
      debugPrint('[WidgetService] Successfully synced ${widgetsList.length} widgets');
    } catch (e) {
      debugPrint('[WidgetService] Error in syncAllWidgets: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // State Computation Helpers
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> _computeTodayTasks(WidgetRef ref) async {
    try {
      final roadmap = ref.read(todaysRoadmapProvider).valueOrNull;
      if (roadmap == null) return null;

      return _buildTasksState(
        title: roadmap.projectTitle.isNotEmpty ? roadmap.projectTitle : 'Today\'s Roadmap',
        widgetType: 'today',
        tasks: roadmap.tasks,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _computeProjectTasks(WidgetRef ref, String? projectId) async {
    if (projectId == null) return null;
    try {
      final repo = ref.read(projectRepositoryProvider);
      final project = await repo.fetchProject(projectId);
      final tasks = await repo.fetchProjectTasks(projectId);

      // Get today's day number for the project to match Microsoft To Do timeline focus
      final createdMidnight = DateTime(project.createdAt.year, project.createdAt.month, project.createdAt.day);
      final nowMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final daysElapsed = nowMidnight.difference(createdMidnight).inDays + 1;
      final todayDayNumber = daysElapsed.clamp(1, project.durationDays);

      // Filter tasks for the active roadmap day
      final todayTasks = tasks.where((t) => t.dayNumber == todayDayNumber).toList();

      return _buildTasksState(
        title: project.title,
        widgetType: 'project',
        tasks: todayTasks,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _computeTodoTasks(WidgetRef ref, String subType) async {
    try {
      final allTodos = ref.read(todosProvider).valueOrNull;
      if (allTodos == null) return null;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      List<Todo> filtered;
      String title;

      switch (subType) {
        case 'today':
          title = 'Today\'s To-Dos';
          filtered = allTodos.where((todo) {
            if (todo.dueDate == null) return false;
            return todo.dueDate!.isBefore(todayEnd) && todo.status != TodoStatus.archived;
          }).toList();
          break;
        case 'important':
          title = 'Important To-Dos';
          filtered = allTodos.where((todo) {
            return (todo.priority == TodoPriority.high || todo.priority == TodoPriority.critical) &&
                todo.status != TodoStatus.archived;
          }).toList();
          break;
        case 'inbox':
          title = 'Inbox To-Dos';
          filtered = allTodos.where((todo) {
            return todo.parentId == null && todo.status != TodoStatus.archived;
          }).toList();
          break;
        case 'all':
        default:
          title = 'All To-Dos';
          filtered = allTodos.where((todo) => todo.status != TodoStatus.archived).toList();
      }

      // Sort pending first, then completed. Also sort by priority/dueDate.
      filtered.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        // Then by priority descending
        final priorityCompare = b.priority.index.compareTo(a.priority.index);
        if (priorityCompare != 0) return priorityCompare;
        // Then by due date
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        if (a.dueDate != null) return -1;
        if (b.dueDate != null) return 1;
        return a.title.compareTo(b.title);
      });

      return _buildTodosWidgetState(
        title: title,
        widgetType: 'todo_$subType',
        todos: filtered,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _computeStatsState(WidgetRef ref) async {
    try {
      final stats = ref.read(timeTrackingStatsProvider);
      final allTodos = ref.read(todosProvider).valueOrNull ?? [];
      final completedTodosCount = allTodos.where((t) => t.isCompleted).length;

      return {
        'title': 'My Analytics',
        'widgetType': 'stats',
        'deepWorkHours': stats.deepWorkHours,
        'weeklyStreak': stats.weeklyStreak,
        'tasksCompleted': completedTodosCount,
      };
    } catch (e) {
      debugPrint('[WidgetService] Error computing stats state: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _computeFocusState(WidgetRef ref) async {
    try {
      final entries = ref.read(timeEntriesProvider).valueOrNull ?? [];
      final activeSession = entries.where((e) => e.isOngoing).firstOrNull;

      if (activeSession == null) {
        return {
          'title': 'Focus Session',
          'widgetType': 'focus',
          'status': 'idle',
        };
      }

      return {
        'title': 'Focus Session',
        'widgetType': 'focus',
        'sessionId': activeSession.id,
        'taskName': activeSession.taskName.isNotEmpty ? activeSession.taskName : 'Focus Session',
        'sessionMode': activeSession.sessionMode.name,
        'status': activeSession.status.name, // active / paused
        'elapsedSeconds': activeSession.duration.inSeconds,
        'remainingSeconds': activeSession.remainingTime.inSeconds,
        'targetMinutes': activeSession.targetDurationMinutes,
      };
    } catch (e) {
      debugPrint('[WidgetService] Error computing focus state: $e');
      return null;
    }
  }

  static Map<String, dynamic> _buildTodosWidgetState({
    required String title,
    required String widgetType,
    required List<Todo> todos,
  }) {
    final completedCount = todos.where((t) => t.status == TodoStatus.completed).length;
    final totalCount = todos.length;
    final pct = totalCount == 0 ? 0 : ((completedCount / totalCount) * 100).round();

    final tasksJson = todos.map((todo) {
      return {
        'id': todo.id,
        'title': todo.title,
        'estimatedMinutes': todo.estimatedMinutes > 0 ? todo.estimatedMinutes : null,
        'status': todo.status.jsonKey,
        'priority': todo.priority.jsonKey,
      };
    }).toList();

    return {
      'title': title,
      'widgetType': widgetType,
      'completedCount': completedCount,
      'totalCount': totalCount,
      'progressPercentage': pct,
      'tasks': tasksJson,
    };
  }

  static Map<String, dynamic> _buildTasksState({
    required String title,
    required String widgetType,
    required List<ProjectTask> tasks,
  }) {
    final completedCount = tasks.where((t) => t.status == ProjectTaskStatus.completed).length;
    final totalCount = tasks.length;
    final pct = totalCount == 0 ? 0 : ((completedCount / totalCount) * 100).round();

    final tasksJson = tasks.map((task) {
      // Priority assignment logic: High >= 60m, Medium >= 30m, Low < 30m
      final mins = task.estimatedMinutes ?? 0;
      final priority = mins >= 60 ? 'high' : (mins >= 30 ? 'medium' : 'low');

      return {
        'id': task.id,
        'title': task.title,
        'estimatedMinutes': task.estimatedMinutes,
        'status': task.status.jsonKey,
        'priority': priority,
      };
    }).toList();

    return {
      'title': title,
      'widgetType': widgetType,
      'completedCount': completedCount,
      'totalCount': totalCount,
      'progressPercentage': pct,
      'tasks': tasksJson
    };
  }
}
