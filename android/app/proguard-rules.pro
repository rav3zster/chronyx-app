# ── app_links (used by supabase_flutter for deep-link OAuth callbacks) ──────
# R8 strips these in release builds, breaking Android OAuth deep-link handling.
-keep class com.llfbandit.app_links.** { *; }

# ── Flutter plugin registry ──────────────────────────────────────────────────
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── Supabase / Realtime / Postgrest ─────────────────────────────────────────
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**

# ── Conscrypt / TLS / SSL (Dart VM AOT uses these for HTTPS in release) ─────
# R8 with proguard-android-optimize.txt can strip Conscrypt and the Java SSL
# provider chain, causing DNS resolution failures in release APKs even though
# INTERNET permission is declared. Keep the full SSL/network stack.
-keep class org.conscrypt.** { *; }
-dontwarn org.conscrypt.**
-keep class com.android.org.conscrypt.** { *; }
-dontwarn com.android.org.conscrypt.**
-keep class sun.security.** { *; }
-dontwarn sun.security.**
-keep class javax.net.ssl.** { *; }
-keep class java.net.** { *; }
-keep class javax.net.** { *; }
-dontwarn javax.net.**

# ── OkHttp (used by some Flutter plugins transitively) ───────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── Flutter Play Core (optional deferred components — not used in this app) ──
# These classes are referenced by Flutter's engine but not present unless you
# use Play Feature Delivery. Safe to ignore.
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**
