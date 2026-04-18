# Flutter wrapper - mantener todas las clases de Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Mantener todas las clases de Dart compiladas
-keep class com.afesdev.aprendecsharp.** { *; }

# Keep Google Fonts
-keep class com.google.gson.** { *; }
-keep class androidx.** { *; }
-dontwarn androidx.**

# Keep HTTP classes - crítico para las llamadas API
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Mantener clases de HTTP de Dart
-keep class dart.io.** { *; }
-keep class dart.convert.** { *; }

# Keep SharedPreferences - crítico para almacenamiento local
-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$Editor { *; }
-keep class android.content.SharedPreferencesImpl { *; }
-keep class android.content.SharedPreferencesImpl$EditorImpl { *; }

# Keep URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep Markdown
-keep class dev.fluttercommunity.plus.markdown.** { *; }

# Mantener clases de Google Fonts
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Ignorar clases opcionales de Play Core usadas por Flutter para deferred components
# (no usamos deferred components ni Play Store splits en esta app)
-dontwarn com.google.android.play.core.**

# Mantener clases de Material Design
-keep class com.google.android.material.** { *; }
-dontwarn com.google.android.material.**

# Mantener clases de AndroidX
-keep class androidx.lifecycle.** { *; }
-keep class androidx.annotation.** { *; }

# Mantener todas las clases que usan reflexión o JSON
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Mantener clases serializables
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Mantener métodos nativos de Flutter
-keepclasseswithmembernames class * {
    native <methods>;
}

# Remove logging in release (solo después de asegurar que todo funciona)
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}
