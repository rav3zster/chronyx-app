import 'package:chronyx/app.dart';
import 'package:chronyx/core/constants/supabase_env.dart';
import 'package:chronyx/core/services/inactivity_lock.dart';
import 'package:chronyx/core/services/notification_service.dart';
import 'package:chronyx/core/services/widget_service.dart';
import 'package:chronyx/core/widgets/biometric_gate.dart';
import 'package:chronyx/core/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:chronyx/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  debugPrint('[INIT] Supabase initialized — authFlowType: PKCE');

  final session = Supabase.instance.client.auth.currentSession;
  final user = Supabase.instance.client.auth.currentUser;
  debugPrint('[AUTH] Session: ${session != null}');
  debugPrint('[AUTH] User: ${user?.id}');
  debugPrint('[AUTH] Email: ${user?.email}');

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    debugPrint('[AUTH EVENT] ${data.event}');
    debugPrint('[AUTH USER] ${data.session?.user.id}');
    debugPrint('[AUTH ACCESS TOKEN] ${data.session?.accessToken != null}');
  });

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const _AppWithServices(),
    ),
  );
}

/// Wraps ChronyxApp with service initialization.
class _AppWithServices extends ConsumerStatefulWidget {
  const _AppWithServices();

  @override
  ConsumerState<_AppWithServices> createState() => _AppWithServicesState();
}

class _AppWithServicesState extends ConsumerState<_AppWithServices> {
  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      ref.read(soundServiceProvider);
      await ref.read(notificationServiceProvider).initialize();
      
      // Initialize native home screen widget service
      WidgetService.initialize(ref);

      final settings = ref.read(settingsProvider);
      if (settings.dailyReminder) {
        ref.read(notificationServiceProvider).scheduleDailyReminder(
          TimeOfDay(hour: settings.dailyReminderHour, minute: settings.dailyReminderMinute),
        );
      }
      if (settings.weeklySummaryNotify) {
        ref.read(notificationServiceProvider).scheduleWeeklySummary();
      }

      if (settings.requireBiometrics) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(biometricGateNotifierProvider.notifier).authenticate();
          }
        });
      }
    } catch (e) {
      debugPrint('[INIT] Service initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read inactivity lock to keep it alive
    ref.watch(inactivityLockProvider);
    // Read biometric gate to keep it alive
    ref.watch(biometricGateNotifierProvider);

    return const ChronyxApp();
  }
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
