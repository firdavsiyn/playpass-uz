# Flutter core — don't strip
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Play Core (used by Flutter for deferred components) — keep split install classes
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# MobileScanner (camera QR)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# url_launcher, share_plus, image_picker — standard plugins
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }

# Supabase (gson used internally)
-keep class io.supabase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# JSON serialization models (keep field names)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Reflection-used classes
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations

# Keep stack traces readable
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
