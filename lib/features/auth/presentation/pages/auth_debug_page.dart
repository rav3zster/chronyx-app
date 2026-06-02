// ignore_for_file: avoid_print
import 'dart:io';

import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Temporary debug page — visible in ALL build modes (including release).
/// Tap the floating button on LoginPage to reach /auth-debug.
/// Shows real-time auth state and writes a snapshot to
/// /sdcard/Android/data/<app>/files/auth_debug.txt on Android.
class AuthDebugPage extends ConsumerStatefulWidget {
  const AuthDebugPage({super.key});

  @override
  ConsumerState<AuthDebugPage> createState() => _AuthDebugPageState();
}

class _AuthDebugPageState extends ConsumerState<AuthDebugPage> {
  final List<String> _events = [];
  late final _sub = Supabase.instance.client.auth.onAuthStateChange.listen((
    data,
  ) {
    final line =
        '[AUTH EVENT] ${data.event} | user=${data.session?.user.id} '
        '| accessToken=${data.session?.accessToken != null}';
    print(line);
    setState(() => _events.add('${DateTime.now().toIso8601String()} $line'));
    _writeSnapshot();
  });

  @override
  void initState() {
    super.initState();
    _writeSnapshot();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Map<String, String> _buildSnapshot() {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    final authState = ref.read(authProvider);
    final router = GoRouter.of(context);

    return {
      'buildMode': kReleaseMode
          ? 'RELEASE'
          : kProfileMode
          ? 'PROFILE'
          : 'DEBUG',
      'currentUser.id': user?.id ?? 'null',
      'currentUser.email': user?.email ?? 'null',
      'currentSession != null': (session != null).toString(),
      'accessToken != null': (session?.accessToken != null).toString(),
      'refreshToken != null': (session?.refreshToken != null).toString(),
      'session.expiresAt': session?.expiresAt?.toString() ?? 'null',
      'authProvider.isLoading': authState.isLoading.toString(),
      'authProvider.hasValue': authState.hasValue.toString(),
      'authProvider.hasError': authState.hasError.toString(),
      'authProvider.value': authState.valueOrNull?.id ?? 'null',
      'authProvider.error': authState.hasError
          ? authState.error.toString()
          : 'none',
      'currentRoute':
          router.routerDelegate.currentConfiguration.last.route.path,
      'recentEvents': _events.isEmpty ? 'none yet' : _events.join('\n  '),
    };
  }

  Future<void> _writeSnapshot() async {
    if (kIsWeb) return;
    try {
      final snap = _buildSnapshot();
      final lines = snap.entries.map((e) => '${e.key}: ${e.value}').join('\n');
      final ts = DateTime.now().toIso8601String();
      final content = '=== AUTH DEBUG SNAPSHOT $ts ===\n$lines\n\n';
      print(content);

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/auth_debug.txt');
      await file.writeAsString(content, mode: FileMode.append, flush: true);
      print('[AUTH DEBUG] Written to ${file.path}');
    } catch (e) {
      print('[AUTH DEBUG] Failed to write file: $e');
    }
  }

  Future<void> _copyToClipboard() async {
    final snap = _buildSnapshot();
    final text = snap.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-read on every rebuild so values stay live.
    final snap = _buildSnapshot();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Auth Debug',
          style: TextStyle(color: Colors.white, fontFamily: 'monospace'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white),
            tooltip: 'Copy to clipboard',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh snapshot',
            onPressed: () {
              setState(() {});
              _writeSnapshot();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: 'Supabase Client State',
              entries: {
                'buildMode': snap['buildMode']!,
                'currentUser.id': snap['currentUser.id']!,
                'currentUser.email': snap['currentUser.email']!,
                'session != null': snap['currentSession != null']!,
                'accessToken != null': snap['accessToken != null']!,
                'refreshToken != null': snap['refreshToken != null']!,
                'session.expiresAt': snap['session.expiresAt']!,
              },
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Riverpod authProvider',
              entries: {
                'isLoading': snap['authProvider.isLoading']!,
                'hasValue': snap['authProvider.hasValue']!,
                'hasError': snap['authProvider.hasError']!,
                'value (userId)': snap['authProvider.value']!,
                'error': snap['authProvider.error']!,
              },
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Router',
              entries: {'currentRoute': snap['currentRoute']!},
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'onAuthStateChange Events (live)',
              entries: {
                'events': _events.isEmpty
                    ? 'none yet — sign in to see events'
                    : _events.reversed.take(10).join('\n'),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.entries});
  final String title;
  final Map<String, String> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: const Color(0xFF2A2A2A),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFBBBBFF),
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          color: const Color(0xFF141414),
          padding: const EdgeInsets.all(10),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.entries.map((e) {
              final isNull =
                  e.value == 'null' || e.value == 'false' || e.value == 'none';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: '${e.key}: ',
                        style: const TextStyle(color: Color(0xFF888888)),
                      ),
                      TextSpan(
                        text: e.value,
                        style: TextStyle(
                          color: isNull
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF6BFF8E),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
