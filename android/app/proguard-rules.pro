# --- Flutter / Dart ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# --- TensorFlow Lite (CPU + GPU delegates) ---
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# --- Firebase / Google Play services ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- Gson (souvent utilisé par Firebase) ---
-keep class com.google.gson.** { *; }
-keep class sun.misc.Unsafe { *; }
-dontwarn com.google.gson.**
