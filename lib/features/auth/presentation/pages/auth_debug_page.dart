// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:chronyx/core/constants/supabase_env.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthDebugPage extends ConsumerStatefulWidget {
  const AuthDebugPage({super.key});

  @override
  ConsumerState<AuthDebugPage> createState() => _AuthDebugPageState();
}

class _AuthDebugPageState extends ConsumerState<AuthDebugPage> {
  final List<String> _events = [];
  String _connectivityResult = 'Not tested yet';
  bool _testingConnectivity = false;
  late final StreamSubscription<AuthState> _sub;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final line =
          '[EVENT] ${data.event} | user=${data.session?.user.id} '
          '| token=${data.session?.accessToken != null}';
      print(line);
      if (mounted) setState(() => _events.add('${_ts()} $line'));
      _writeSnapshot();
    });
    _writeSnapshot();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  String _ts() => DateTime.now().toIso8601String().substring(11, 23);

  Future<void> _testConnectivity() async {
    setState(() {
      _testingConnectivity = true;
      _connectivityResult = 'Testing...';
    });

    final host = Uri.parse(SupabaseEnv.url).host;
    final lines = <String>[];

    // Step 1: raw DNS lookup — isolates hostname resolution from Supabase client
    try {
      final addresses = await InternetAddress.lookup(host);
      final ips = addresses.map((a) => a.address).join(', ');
      lines.add('DNS OK: $host → $ips');
      print('[CONNECTIVITY] DNS OK: $host → $ips');
    } on SocketException catch (e) {
      lines.add('DNS FAILED: $e');
      print('[CONNECTIVITY] DNS FAILED: $e');
      setState(() => _connectivityResult = lines.join('\n'));
      if (mounted) setState(() => _testingConnectivity = false);
      _writeSnapshot();
      return; // no point proceeding if DNS is broken
    } catch (e) {
      lines.add('DNS ERROR: $e');
      print('[CONNECTIVITY] DNS ERROR: $e');
    }

    // Step 2: Supabase client query
    try {
      final result = await Supabase.instance.client
          .from('users')
          .select()
          .limit(1);
      final preview = result.toString();
      lines.add(
        'SUPABASE OK: ${preview.substring(0, preview.length.clamp(0, 200))}',
      );
      print('[CONNECTIVITY] SUPABASE OK');
    } catch (e) {
      lines.add('SUPABASE FAILED: $e');
      print('[CONNECTIVITY] SUPABASE FAILED: $e');
    }

    final msg = lines.join('\n');
    setState(() => _connectivityResult = msg);
    if (mounted) setState(() => _testingConnectivity = false);
    _writeSnapshot();
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
      'supabaseUrl': SupabaseEnv.url,
      'urlLength': SupabaseEnv.url.length.toString(),
      'anonKeyLength': SupabaseEnv.anonKey.length.toString(),
      'session != null': (session != null).toString(),
      'accessToken != null': (session?.accessToken != null).toString(),
      'refreshToken != null': (session?.refreshToken != null).toString(),
      'user.id': user?.id ?? 'null',
      'user.email': user?.email ?? 'null',
      'authProvider.value': authState.valueOrNull?.id ?? 'null',
      'authProvider.isLoading': authState.isLoading.toString(),
      'authProvider.hasError': authState.hasError.toString(),
      'authProvider.error': authState.hasError
          ? authState.error.toString()
          : 'none',
      'currentRoute':
          router.routerDelegate.currentConfiguration.last.route.path,
      'connectivity': _connectivityResult,
    };
  }

  Future<void> _writeSnapshot() async {
    if (kIsWeb) return;
    try {
      final snap = _buildSnapshot();
      final lines = snap.entries.map((e) => '${e.key}: ${e.value}').join('\n');
      final ts = DateTime.now().toIso8601String();
      final evts = _events.isEmpty ? 'none' : _events.join('\n  ');
      final content =
          '=== AUTH DEBUG $ts ===\n$lines\nrecentEvents:\n  $evts\n\n';
      print(content);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/auth_debug.txt');
      await file.writeAsString(content, mode: FileMode.append, flush: true);
      print('[DEBUG FILE] ${file.path}');
    } catch (e) {
      print('[DEBUG FILE] write failed: $e');
    }
  }

  Future<void> _copy() async {
    final snap = _buildSnapshot();
    final text = snap.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _copy,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
              title: 'Build & Config',
              entries: {
                'buildMode': snap['buildMode']!,
                'supabaseUrl': snap['supabaseUrl']!,
                'urlLength': snap['urlLength']!,
                'anonKeyLength': snap['anonKeyLength']!,
              },
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Session',
              entries: {
                'session != null': snap['session != null']!,
                'accessToken != null': snap['accessToken != null']!,
                'refreshToken != null': snap['refreshToken != null']!,
                'user.id': snap['user.id']!,
                'user.email': snap['user.email']!,
              },
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Riverpod',
              entries: {
                'authProvider.value': snap['authProvider.value']!,
                'isLoading': snap['authProvider.isLoading']!,
                'hasError': snap['authProvider.hasError']!,
                'error': snap['authProvider.error']!,
              },
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Router',
              entries: {'currentRoute': snap['currentRoute']!},
            ),
            const SizedBox(height: 12),
            // ── Connectivity test ─────────────────────────────────────
            Container(
              color: const Color(0xFF2A2A2A),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supabase Connectivity Test',
                    style: TextStyle(
                      color: Color(0xFFBBBBFF),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4444AA),
                    ),
                    onPressed: _testingConnectivity ? null : _testConnectivity,
                    child: Text(
                      _testingConnectivity
                          ? 'Testing...'
                          : 'Test Supabase Connectivity',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _connectivityResult,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: _connectivityResult.startsWith('SUCCESS')
                          ? const Color(0xFF6BFF8E)
                          : _connectivityResult.startsWith('FAILED')
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFFAAAAAA),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'onAuthStateChange Events',
              entries: {
                'events': _events.isEmpty
                    ? 'none yet'
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: const Color(0xFF2A2A2A),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFBBBBFF),
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 12,
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
              final isNeg =
                  e.value == 'null' ||
                  e.value == 'false' ||
                  e.value == 'none' ||
                  e.value.startsWith('FAILED');
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
                          color: isNeg
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
