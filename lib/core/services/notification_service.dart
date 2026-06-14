import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';
import 'package:chronyx/core/routing/app_router.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/todos/domain/entities/todo.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

class NotificationService {
  final Ref _ref;
  late final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _dailyReminderId = 1001;
  static const _sessionCompleteId = 1002;
  static const _goalDeadlineId = 1003;
  static const _weeklySummaryId = 1004;
  static const _runningSessionId = 1006;

  NotificationService(this._ref);

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    _plugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final router = _ref.read(appRouterProvider);
        if (payload == 'session_complete' || payload == 'time_tracking') {
          router.go(AppRoutes.timeTracking);
        } else if (payload == 'goal_deadline' || payload == 'goals') {
          router.go(AppRoutes.goals);
        } else if (payload == 'weekly_summary' || payload == 'analytics') {
          router.go(AppRoutes.analytics);
        }
      } catch (e) {
        debugPrint('[NOTIFICATION] Failed to navigate: $e');
      }
    }
  }

  Future<void> _ensureChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final settings = _ref.read(settingsProvider);
    final sound = settings.notificationSoundUri.isNotEmpty
        ? UriAndroidNotificationSound(settings.notificationSoundUri)
        : null;

    final channel = AndroidNotificationChannel(
      'chronyx_notifications',
      'Chronyx Notifications',
      description: 'Chronyx notification channel',
      importance: Importance.high,
      playSound: true,
      sound: sound,
    );

    final runningChannel = AndroidNotificationChannel(
      'chronyx_running_session',
      'Active Focus Session',
      description: 'Displays the status of your current focus session',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await android.createNotificationChannel(channel);
    await android.createNotificationChannel(runningChannel);
  }

  Future<void> updateNotificationChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.deleteNotificationChannel('chronyx_notifications');
    await _ensureChannel();
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _ensureChannel();

    final settings = _ref.read(settingsProvider);
    final sound = settings.notificationSoundUri.isNotEmpty
        ? UriAndroidNotificationSound(settings.notificationSoundUri)
        : null;

    final androidDetails = AndroidNotificationDetails(
      'chronyx_notifications',
      'Chronyx Notifications',
      channelDescription: 'Chronyx notification channel',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: sound,
    );

    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.dailyReminder) return;

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final utcScheduledDate = scheduledDate.toUtc();
    final location = tz.getLocation('UTC');
    final tzScheduledDate = tz.TZDateTime.from(utcScheduledDate, location);

    final sound = settings.notificationSoundUri.isNotEmpty
        ? UriAndroidNotificationSound(settings.notificationSoundUri)
        : null;

    final androidDetails = AndroidNotificationDetails(
      'chronyx_notifications',
      'Chronyx Notifications',
      channelDescription: 'Chronyx notification channel',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: sound,
    );

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Daily Reminder',
      "Time to work on your goals! Let's make today count.",
      tzScheduledDate,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  Future<void> showSessionComplete({
    required String sessionName,
    required Duration duration,
  }) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.sessionCompleteNotify) return;

    final minutes = duration.inMinutes;
    await showNotification(
      id: _sessionCompleteId,
      title: 'Session Complete',
      body: 'Great focus! "$sessionName" completed — $minutes minutes of deep work.',
      payload: 'session_complete',
    );
  }

  Future<void> showGoalDeadlineReminder({
    required String goalTitle,
    required DateTime deadline,
    required int daysRemaining,
  }) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.goalDeadlineNotify) return;

    await showNotification(
      id: _goalDeadlineId,
      title: 'Goal Deadline Approaching',
      body: '"$goalTitle" is due in $daysRemaining day${daysRemaining == 1 ? '' : 's'}. Keep pushing!',
      payload: 'goal_deadline',
    );
  }

  Future<void> scheduleGoalDeadlineReminder({
    required String goalId,
    required String goalTitle,
    required DateTime deadline,
  }) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.goalDeadlineNotify) return;

    final reminderDate = deadline.subtract(const Duration(days: 1));
    final now = DateTime.now();
    var scheduledDate = DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 9, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = DateTime(deadline.year, deadline.month, deadline.day, 9, 0);
    }
    if (scheduledDate.isBefore(now)) return;

    final utcScheduledDate = scheduledDate.toUtc();
    final location = tz.getLocation('UTC');
    final tzScheduledDate = tz.TZDateTime.from(utcScheduledDate, location);

    final notificationId = goalId.hashCode;

    final sound = settings.notificationSoundUri.isNotEmpty
        ? UriAndroidNotificationSound(settings.notificationSoundUri)
        : null;

    final androidDetails = AndroidNotificationDetails(
      'chronyx_notifications',
      'Chronyx Notifications',
      channelDescription: 'Chronyx notification channel',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: sound,
    );

    await _plugin.zonedSchedule(
      notificationId,
      'Goal Deadline Approaching',
      'Your goal "$goalTitle" is due tomorrow. Keep pushing to complete it!',
      tzScheduledDate,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelGoalDeadlineReminder(String goalId) async {
    await _plugin.cancel(goalId.hashCode);
  }

  Future<void> scheduleWeeklySummary() async {
    final settings = _ref.read(settingsProvider);
    if (!settings.weeklySummaryNotify) return;

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 18, 0);
    final daysUntilSunday = (DateTime.sunday - now.weekday + 7) % 7;
    scheduledDate = scheduledDate.add(Duration(days: daysUntilSunday));
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    final utcScheduledDate = scheduledDate.toUtc();
    final location = tz.getLocation('UTC');
    final tzScheduledDate = tz.TZDateTime.from(utcScheduledDate, location);

    final sound = settings.notificationSoundUri.isNotEmpty
        ? UriAndroidNotificationSound(settings.notificationSoundUri)
        : null;

    final androidDetails = AndroidNotificationDetails(
      'chronyx_notifications',
      'Chronyx Notifications',
      channelDescription: 'Chronyx notification channel',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: sound,
    );

    await _plugin.zonedSchedule(
      _weeklySummaryId,
      'Weekly Summary',
      'Your weekly progress summary is ready. See how you performed this week!',
      tzScheduledDate,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelWeeklySummary() async {
    await _plugin.cancel(_weeklySummaryId);
  }

  Future<void> showActiveSessionNotification({
    required String taskName,
    required SessionStatus status,
    required Duration duration,
    Duration? remaining,
    double? progressPercent,
  }) async {
    await _ensureChannel();
    final isPaused = status == SessionStatus.paused;
    final stateText = isPaused ? '⏸ Paused' : '🎯 Active';
    final name = taskName.isEmpty ? 'Focus Session' : taskName;

    final elapsedText = _formatDuration(duration);
    final timeText = remaining != null && remaining > Duration.zero
        ? '${_formatDuration(remaining)} remaining · $elapsedText elapsed'
        : 'Elapsed: $elapsedText';

    // Android action buttons
    const pauseAction = AndroidNotificationAction(
      'pause_session',
      'Pause',
      icon: DrawableResourceAndroidBitmap('@drawable/ic_pause'),
      showsUserInterface: false,
    );
    const resumeAction = AndroidNotificationAction(
      'resume_session',
      'Resume',
      icon: DrawableResourceAndroidBitmap('@drawable/ic_play'),
      showsUserInterface: false,
    );
    const stopAction = AndroidNotificationAction(
      'stop_session',
      'Stop',
      icon: DrawableResourceAndroidBitmap('@drawable/ic_stop'),
      showsUserInterface: false,
      cancelNotification: true,
    );

    final androidDetails = AndroidNotificationDetails(
      'chronyx_running_session',
      'Active Focus Session',
      channelDescription: 'Displays the status of your current focus session',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      ongoing: !isPaused,
      onlyAlertOnce: true,
      showWhen: false,
      subText: stateText,
      actions: isPaused
          ? [resumeAction, stopAction]
          : [pauseAction, stopAction],
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: false,
      presentAlert: true,
    );

    await _plugin.show(
      _runningSessionId,
      name,
      timeText,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: 'time_tracking',
    );
  }

  Future<void> cancelActiveSessionNotification() async {
    await _plugin.cancel(_runningSessionId);
  }

  Future<void> showBreakReminder() async {
    await showNotification(
      id: 1005,
      title: 'Time for a break!',
      body: 'Take a short break to rest and recharge.',
      payload: 'time_tracking',
    );
  }

  Future<void> showAutoStopNotification({required String sessionName}) async {
    await showNotification(
      id: 1007,
      title: 'Timer Completed',
      body: '"$sessionName" has completed and automatically stopped.',
      payload: 'time_tracking',
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> rescheduleAll() async {
    await cancelDailyReminder();
    await cancelWeeklySummary();

    final settings = _ref.read(settingsProvider);
    if (settings.dailyReminder) {
      final prefs = await SharedPreferences.getInstance();
      final hour = prefs.getInt('dailyReminderHour') ?? 9;
      final minute = prefs.getInt('dailyReminderMinute') ?? 0;
      await scheduleDailyReminder(TimeOfDay(hour: hour, minute: minute));
    }
    if (settings.weeklySummaryNotify) {
      await scheduleWeeklySummary();
    }
  }

  Future<void> scheduleTodoReminder(Todo todo) async {
    // 1. Cancel existing reminders
    await cancelTodoReminder(todo.id);

    final settings = _ref.read(settingsProvider);
    if (!settings.dailyReminder) return; // respect settings toggle for reminders

    final now = DateTime.now();

    // 2. Schedule main reminder
    if (todo.reminderTime != null && todo.reminderTime!.isAfter(now)) {
      final utcScheduledDate = todo.reminderTime!.toUtc();
      final location = tz.getLocation('UTC');
      final tzScheduledDate = tz.TZDateTime.from(utcScheduledDate, location);

      final sound = settings.notificationSoundUri.isNotEmpty
          ? UriAndroidNotificationSound(settings.notificationSoundUri)
          : null;

      final androidDetails = AndroidNotificationDetails(
        'chronyx_todo_reminders',
        'To-Do Reminders',
        channelDescription: 'Reminders for your scheduled tasks',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: sound,
      );

      await _plugin.zonedSchedule(
        todo.id.hashCode,
        'Task Reminder: ${todo.title}',
        todo.notes != null && todo.notes!.isNotEmpty ? todo.notes! : 'This task is due now.',
        tzScheduledDate,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'todo:${todo.id}',
      );
    }

    // 3. Schedule multiple reminders
    for (var i = 0; i < todo.reminderTimes.length; i++) {
      final rTime = todo.reminderTimes[i];
      if (rTime.isBefore(now)) continue;

      final utcScheduledDate = rTime.toUtc();
      final location = tz.getLocation('UTC');
      final tzScheduledDate = tz.TZDateTime.from(utcScheduledDate, location);
      final notificationId = ('${todo.id}_$i').hashCode;

      final sound = settings.notificationSoundUri.isNotEmpty
          ? UriAndroidNotificationSound(settings.notificationSoundUri)
          : null;

      final androidDetails = AndroidNotificationDetails(
        'chronyx_todo_reminders',
        'To-Do Reminders',
        channelDescription: 'Reminders for your scheduled tasks',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: sound,
      );

      await _plugin.zonedSchedule(
        notificationId,
        'Task Reminder: ${todo.title}',
        todo.notes != null && todo.notes!.isNotEmpty ? todo.notes! : 'Task reminder.',
        tzScheduledDate,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'todo:${todo.id}',
      );
    }
  }

  Future<void> cancelTodoReminder(String todoId) async {
    await _plugin.cancel(todoId.hashCode);
    await _plugin.cancel(('${todoId}_snooze').hashCode);
    for (var i = 0; i < 15; i++) {
      await _plugin.cancel(('${todoId}_$i').hashCode);
    }
  }

  Future<void> scheduleTodoSnooze(Todo todo, String snoozeOption) async {
    final now = DateTime.now();
    DateTime? snoozeTime;
    switch (snoozeOption) {
      case '10m':
        snoozeTime = now.add(const Duration(minutes: 10));
        break;
      case '30m':
        snoozeTime = now.add(const Duration(minutes: 30));
        break;
      case '1h':
        snoozeTime = now.add(const Duration(hours: 1));
        break;
      case 'tomorrow':
        snoozeTime = DateTime(now.year, now.month, now.day + 1, 9, 0);
        break;
      case 'endOfDay':
        snoozeTime = DateTime(now.year, now.month, now.day, 18, 0);
        if (snoozeTime.isBefore(now)) {
          snoozeTime = now.add(const Duration(hours: 2));
        }
        break;
    }
    if (snoozeTime == null) return;

    final settings = _ref.read(settingsProvider);
    final utcScheduledDate = snoozeTime.toUtc();
    final location = tz.getLocation('UTC');
    final tzScheduledDate = tz.TZDateTime.from(utcScheduledDate, location);

    final notificationId = ('${todo.id}_snooze').hashCode;

    final sound = settings.notificationSoundUri.isNotEmpty
        ? UriAndroidNotificationSound(settings.notificationSoundUri)
        : null;

    final androidDetails = AndroidNotificationDetails(
      'chronyx_todo_reminders',
      'To-Do Reminders',
      channelDescription: 'Reminders for your scheduled tasks',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: sound,
    );

    await _plugin.zonedSchedule(
      notificationId,
      'Snoozed Task: ${todo.title}',
      todo.notes != null && todo.notes!.isNotEmpty ? todo.notes! : 'Snoozed reminder.',
      tzScheduledDate,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'todo:${todo.id}',
    );
  }
}
