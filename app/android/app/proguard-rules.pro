# Flutter proguard rules

# TensorFlow Lite - Keep GPU delegate classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.lite.gpu.**

# Google Play Core (needed for app updates, reviews, etc.)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Groq client (if using any reflection)
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**

# Keep Flutter and Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep annotations
-keepattributes *Annotation*

# Keep common Android classes
-keep class androidx.** { *; }
-dontwarn androidx.**

# Suppress all warnings for cleaner build
-ignorewarnings
