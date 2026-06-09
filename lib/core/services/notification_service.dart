import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

    await android.createNotificationChannel(channel);
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
}
