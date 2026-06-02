class SupabaseEnv {
  const SupabaseEnv._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://evrafznbrlhovoffsbvr.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV2cmFmem5icmxob3ZvZmZzYnZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5MzcyNDgsImV4cCI6MjA5MjUxMzI0OH0.t1XUsIe5TaDI_R4-bI5w-HsS7rGBgPSCkKafm38dxS8',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
