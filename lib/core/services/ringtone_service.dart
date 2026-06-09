import 'package:flutter/services.dart';

class RingtoneInfo {
  final String title;
  final String uri;
  final bool isAlarm;

  RingtoneInfo({
    required this.title,
    required this.uri,
    this.isAlarm = false,
  });
}

class RingtoneService {
  static const _channel = MethodChannel('chronyx/ringtones');

  Future<List<RingtoneInfo>> getRingtones() async {
    try {
      final result = await _channel.invokeMethod('getRingtones');
      if (result == null) return [];
      return (result as List).map((r) => RingtoneInfo(
        title: r['title'] as String,
        uri: r['uri'] as String,
        isAlarm: r['isAlarm'] as bool? ?? false,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<RingtoneInfo>> getNotificationTones() async {
    try {
      final result = await _channel.invokeMethod('getNotificationTones');
      if (result == null) return [];
      return (result as List).map((r) => RingtoneInfo(
        title: r['title'] as String,
        uri: r['uri'] as String,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<RingtoneInfo>> getAlarmSounds() async {
    try {
      final result = await _channel.invokeMethod('getAlarmSounds');
      if (result == null) return [];
      return (result as List).map((r) => RingtoneInfo(
        title: r['title'] as String,
        uri: r['uri'] as String,
        isAlarm: true,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> pickRingtone() async {
    try {
      final result = await _channel.invokeMethod('pickRingtone');
      return result as String?;
    } catch (_) {
      return null;
    }
  }
}
