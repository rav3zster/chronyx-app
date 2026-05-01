import 'package:chronyx/app.dart';
import 'package:chronyx/core/constants/supabase_env.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseEnv.isConfigured) {
    await Supabase.initialize(
      url: SupabaseEnv.url,
      anonKey: SupabaseEnv.anonKey,
    );
  }

  runApp(const ProviderScope(child: ChronyxApp()));
}
