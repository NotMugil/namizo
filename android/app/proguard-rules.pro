# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep annotations
-keepattributes *Annotation*

# Hive
-keep class * extends com.google.flatbuffers.Table { *; }

# WorkManager
-keep class androidx.work.** { *; }

# better_player_plus / ExoPlayer
-keep class com.google.android.exoplayer2.** { *; }
