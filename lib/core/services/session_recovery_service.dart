import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the active session ID across app restarts and phone reboots.
/// On build, checks if there was an active session before the app was killed.
class SessionRecoveryService {
  static const _keySessionId = 'recovery_session_id';
  static const _keySessionTask = 'recovery_session_task';
  static const _keySessionMode = 'recovery_session_mode';
  static const _keyStartedAt = 'recovery_started_at';

  static Future<void> persist({
    required String sessionId,
    required String taskName,
    required String sessionMode,
    required DateTime startedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionId, sessionId);
    await prefs.setString(_keySessionTask, taskName);
    await prefs.setString(_keySessionMode, sessionMode);
    await prefs.setString(_keyStartedAt, startedAt.toIso8601String());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionId);
    await prefs.remove(_keySessionTask);
    await prefs.remove(_keySessionMode);
    await prefs.remove(_keyStartedAt);
  }

  static Future<String?> getActiveSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySessionId);
  }

  static Future<RecoveredSession?> getRecoveredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keySessionId);
    if (id == null) return null;
    final task = prefs.getString(_keySessionTask) ?? '';
    final mode = prefs.getString(_keySessionMode) ?? 'stopwatch';
    final startedAtStr = prefs.getString(_keyStartedAt);
    final startedAt =
        startedAtStr != null ? DateTime.tryParse(startedAtStr) : null;
    return RecoveredSession(
      sessionId: id,
      taskName: task,
      sessionMode: mode,
      startedAt: startedAt,
    );
  }
}

class RecoveredSession {
  const RecoveredSession({
    required this.sessionId,
    required this.taskName,
    required this.sessionMode,
    required this.startedAt,
  });
  final String sessionId;
  final String taskName;
  final String sessionMode;
  final DateTime? startedAt;
}

final sessionRecoveryProvider =
    FutureProvider<RecoveredSession?>((ref) async {
  return SessionRecoveryService.getRecoveredSession();
});
