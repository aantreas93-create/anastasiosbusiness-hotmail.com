# Stripe
-dontwarn com.stripe.android.**

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- Flutter Play Store / Deferred components ---
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
