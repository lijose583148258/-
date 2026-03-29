# Flutter embedding
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# ML Kit and Play Services (avoid noisy warnings in release builds)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
