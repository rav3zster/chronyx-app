import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class PermissionService {
  Future<bool> requestWithExplanation(
    BuildContext context,
    Permission permission,
    String title,
    String explanation,
  ) async {
    if (await permission.isGranted) return true;

    if (context.mounted) {
      final scheme = Theme.of(context).colorScheme;
      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: scheme.surface,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(explanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Not Now',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (approved != true) return false;
    }

    final status = await permission.request();
    return status.isGranted;
  }

  Future<bool> requestNotification(BuildContext context) async {
    return await requestWithExplanation(
      context,
      Permission.notification,
      'Enable Notifications',
      'Chronyx needs notification permission to send you daily focus reminders and session completion alerts.',
    );
  }

  Future<bool> requestScheduleExactAlarm(BuildContext context) async {
    return await requestWithExplanation(
      context,
      Permission.scheduleExactAlarm,
      'Exact Alarm Permission',
      'To ensure your focus reminders trigger at the precise minute, Chronyx requires exact alarm scheduling.',
    );
  }

  Future<bool> requestStorage(BuildContext context) async {
    return await requestWithExplanation(
      context,
      Permission.storage,
      'Access Media Files',
      'To allow importing custom audio files and choosing notification sounds, Chronyx requires access to storage.',
    );
  }

  Future<bool> requestManageExternalStorage(BuildContext context) async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    return await requestWithExplanation(
      context,
      Permission.manageExternalStorage,
      'All Files Access',
      'Chronyx requires file access permissions to backup and restore databases successfully.',
    );
  }

  Future<bool> requestVibrate() async {
    return true; // Granted by default
  }

  Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  Future<bool> hasScheduleExactAlarmPermission() async {
    return await Permission.scheduleExactAlarm.isGranted;
  }

  Future<bool> requestPermissionsForFeature(
    BuildContext context, {
    required bool needsNotifications,
    required bool needsExactAlarm,
    required bool needsStorage,
  }) async {
    if (needsNotifications && !await hasNotificationPermission()) {
      final granted = await requestNotification(context);
      if (!granted) return false;
    }
    if (needsExactAlarm && !await hasScheduleExactAlarmPermission()) {
      final granted = await requestScheduleExactAlarm(context);
      if (!granted) return false;
    }
    if (needsStorage && !await Permission.storage.isGranted) {
      final granted = await requestStorage(context);
      if (!granted) return false;
    }
    return true;
  }

  Future<void> requestOnFirstLaunch(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    if (isFirstLaunch) {
      await prefs.setBool('isFirstLaunch', false);
      if (context.mounted) {
        await requestNotification(context);
      }
    }
  }
}
