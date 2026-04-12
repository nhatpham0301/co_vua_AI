# ── Google Mobile Ads ──────────────────────────────────────────────
# Prevent R8 from stripping ad SDK classes needed at runtime.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Keep ad-related IMA SDK classes (used by some ad formats).
-keep class com.google.ads.interactivemedia.** { *; }

# ── Play Core (referenced by Flutter deferred components, not used) ──
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ── Flutter ───────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
