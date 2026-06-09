import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dataServiceProvider = Provider<DataService>((ref) {
  return DataService();
});

class DataService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> _collectAllData() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    final goals = await _client.from('goals').select().eq('user_id', userId);
    final projects = await _client.from('projects').select().eq('user_id', userId);
    final sessions = await _client.from('time_logs').select().eq('user_id', userId);

    return {
      'goals': goals,
      'projects': projects,
      'sessions': sessions,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<String> exportToJson() async {
    final data = await _collectAllData();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String> exportToCsv() async {
    final data = await _collectAllData();
    final buffer = StringBuffer();

    for (final key in data.keys) {
      if (data[key] is List) {
        buffer.writeln('=== $key ===');
        final items = data[key] as List;
        if (items.isEmpty) {
          buffer.writeln('(empty)');
          continue;
        }
        final headers = (items.first as Map<String, dynamic>).keys.join(',');
        buffer.writeln(headers);
        for (final item in items) {
          final row = (item as Map<String, dynamic>)
              .values
              .map((v) => '"${v.toString().replaceAll('"', '""')}"')
              .join(',');
          buffer.writeln(row);
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  Future<File> saveToFile(String content, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    return file;
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> exportAndShare({required bool asCsv}) async {
    final content = asCsv ? await exportToCsv() : await exportToJson();
    final ext = asCsv ? 'csv' : 'json';
    final filename = 'chronyx_export_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final file = await saveToFile(content, filename);
    await shareFile(file);
  }

  Future<void> backupToFile() async {
    final content = await exportToJson();
    final filename = 'chronyx_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = await saveToFile(content, filename);
    await shareFile(file);
  }

  Future<void> restoreFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in');

    final goals = data['goals'] as List? ?? [];
    final projects = data['projects'] as List? ?? [];
    final sessions = data['sessions'] as List? ?? [];

    for (final g in goals) {
      await _client.from('goals').upsert(g);
    }
    for (final p in projects) {
      await _client.from('projects').upsert(p);
    }
    for (final s in sessions) {
      await _client.from('time_logs').upsert(s);
    }
  }

  Future<void> restoreFromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    await restoreFromJson(content);
  }

  Future<void> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    if (await tempDir.exists()) {
      final entities = tempDir.listSync();
      for (final entity in entities) {
        if (entity is Directory) {
          await entity.delete(recursive: true);
        } else if (entity is File) {
          await entity.delete();
        }
      }
    }
  }
}
