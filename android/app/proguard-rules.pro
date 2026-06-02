# ── app_links (used by supabase_flutter for deep-link OAuth callbacks) ──────
# R8 strips these in release builds, breaking Android OAuth deep-link handling.
-keep class com.llfbandit.app_links.** { *; }

# ── Flutter plugin registry ──────────────────────────────────────────────────
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── Supabase / Realtime / Postgrest ─────────────────────────────────────────
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**

# ── Flutter Play Core (optional deferred components — not used in this app) ──
# These classes are referenced by Flutter's engine but not present unless you
# use Play Feature Delivery. Safe to ignore.
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**
