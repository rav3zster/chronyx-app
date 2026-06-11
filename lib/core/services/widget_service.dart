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
          _handleWidgetLaunch(data);
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

  static void _handleWidgetLaunch(Map data) {
    final widgetId = data['widgetId'] as int?;
    final widgetType = data['widgetType'] as String?;
    debugPrint('[WidgetService] Real-time widget launch event: widgetId=$widgetId, type=$widgetType');
    // Implement navigation routing here based on type/id if needed
  }

  static Future<void> _handleToggleTask(WidgetRef ref, String taskId) async {
    try {
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
      // 1. Query Android OS for all active widget IDs
      final List<dynamic>? ids = await _channel.invokeMethod<List<dynamic>>('getActiveWidgetIds');
      final List<int> activeIds = ids?.cast<int>() ?? [];
      
      if (activeIds.isEmpty) {
        debugPrint('[WidgetService] No active widgets to sync');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      
      // Make sure auth session is synced
      await syncAuthSession();

      for (final id in activeIds) {
        // 2. Read widget config from cache (or default to today tasks)
        final configKey = 'flutter.widget_config_$id';
        final configJson = prefs.getString(configKey);
        Map<String, dynamic> config = {'type': 'today'};
        if (configJson != null) {
          try {
            config = jsonDecode(configJson) as Map<String, dynamic>;
          } catch (_) {}
        } else {
          // Save default config
          await prefs.setString(configKey, jsonEncode(config));
        }

        final type = config['type'] ?? 'today';
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
          case 'priority':
            stateObj = await _computePriorityTasks(ref);
            break;
          case 'focus':
            // Future widget - Focus Timer (shows placeholder/extensible state)
            stateObj = {
              'title': 'Focus Timer',
              'widgetType': 'focus',
              'completedCount': 0,
              'totalCount': 0,
              'progressPercentage': 0,
              'tasks': []
            };
            break;
          case 'statistics':
            // Future widget - Weekly Stats (shows placeholder/extensible state)
            stateObj = {
              'title': 'Weekly Stats',
              'widgetType': 'statistics',
              'completedCount': 0,
              'totalCount': 0,
              'progressPercentage': 0,
              'tasks': []
            };
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
      debugPrint('[WidgetService] Successfully synced ${activeIds.length} widgets');
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

  static Future<Map<String, dynamic>?> _computePriorityTasks(WidgetRef ref) async {
    try {
      final repo = ref.read(projectRepositoryProvider);
      final projects = await repo.fetchProjects();
      final activeProjects = projects.where((p) => p.status == ProjectStatus.active).toList();
      
      final List<ProjectTask> allPendingTasks = [];
      for (final project in activeProjects) {
        final tasks = await repo.fetchProjectTasks(project.id);
        allPendingTasks.addAll(tasks.where((t) => t.status != ProjectTaskStatus.completed));
      }

      // Sort by priority (larger estimated minutes represents higher priority)
      allPendingTasks.sort((a, b) {
        final minA = a.estimatedMinutes ?? 0;
        final minB = b.estimatedMinutes ?? 0;
        return minB.compareTo(minA); // Descending order (largest first)
      });

      // Limit to top 10 priority tasks
      final topPriorityTasks = allPendingTasks.take(10).toList();

      return _buildTasksState(
        title: 'Priority Tasks',
        widgetType: 'priority',
        tasks: topPriorityTasks,
      );
    } catch (_) {
      return null;
    }
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
