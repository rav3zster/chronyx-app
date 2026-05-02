import 'package:chronyx/app.dart';
import 'package:chronyx/core/constants/supabase_env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseEnv.isConfigured) {
    debugPrint(
      '[INIT] Supabase skipped: set SUPABASE_URL and SUPABASE_ANON_KEY '
      'via --dart-define when running the app.',
    );
    runApp(_bootstrapMaterialAppWithoutSupabase());
    return;
  }

  await Supabase.initialize(
    url: SupabaseEnv.url,
    anonKey: SupabaseEnv.anonKey,
  );

  // ignore: avoid_print
  print('[INIT] Supabase initialized');

  runApp(const ProviderScope(child: ChronyxApp()));
}

/// Same route surface as production (`/login`) so URLs and navigation match.
MaterialApp _bootstrapMaterialAppWithoutSupabase() {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const _SupabaseMissingPage(),
      ),
    ],
  );

  return MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    routerConfig: router,
  );
}

/// Shown at `/login` when compile-time Supabase credentials are missing.
class _SupabaseMissingPage extends StatelessWidget {
  const _SupabaseMissingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Supabase is not configured.\n\n'
              'Run with:\n'
              'flutter run -d chrome '
              '--dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co '
              '--dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
