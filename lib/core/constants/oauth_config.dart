import 'package:flutter/foundation.dart';

/// Redirect URL after Supabase OAuth (Google).
///
/// - Web: built from [Uri.base] so the port always matches the running dev server.
/// - Android: uses a custom scheme registered in AndroidManifest.xml so the OS
///   can route the callback back into the app.
///
/// Add all redirect URLs to Supabase → Auth → URL Configuration → Redirect URLs.
class OAuthConfig {
  const OAuthConfig._();

  /// The custom URL scheme used on Android (must match AndroidManifest intent-filter).
  static const String _androidScheme = 'io.supabase.chronyx';
  static const String _androidHost = 'login-callback';

  static String? get googleWebRedirectTo {
    if (kIsWeb) {
      final Uri b = Uri.base;
      final String hostPort = b.hasPort ? '${b.host}:${b.port}' : b.host;
      return '${b.scheme}://$hostPort/#/dashboard';
    }
    // Android / mobile: deep-link scheme caught by the intent-filter.
    return '$_androidScheme://$_androidHost';
  }
}
