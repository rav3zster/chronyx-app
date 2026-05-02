import 'package:flutter/foundation.dart';

/// Redirect URL after Supabase OAuth (Google) on web.
///
/// Built from [Uri.base] so the port always matches the running Flutter web
/// server (e.g. `http://localhost:13628/#/dashboard`).
/// Add this origin (and path if needed) to Supabase Auth redirect URLs.
class OAuthConfig {
  const OAuthConfig._();

  /// Full URL including hash route for go_router on web.
  static String? get googleWebRedirectTo {
    if (!kIsWeb) {
      return null;
    }
    final Uri b = Uri.base;
    final String hostPort =
        b.hasPort ? '${b.host}:${b.port}' : b.host;
    return '${b.scheme}://$hostPort/#/dashboard';
  }
}
