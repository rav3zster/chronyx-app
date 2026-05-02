import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Access to the shared Supabase client.
///
/// [main] must call [Supabase.initialize] before [runApp] when using
/// [ChronyxApp]. Do not read this provider in the bootstrap app that runs when
/// credentials are missing.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
