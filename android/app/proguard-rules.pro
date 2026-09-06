# Flutter Core Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Isar Database JNI & Model Protection
-keep class dev.isar.** { *; }
-dontwarn dev.isar.**

# Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Play Core and deferred components dontwarn
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

