# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Uncomment this to preserve the line number information for debugging stack traces.
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*

# If you keep the line number information, uncomment this to hide the original source file name.
#-renamesourcefileattribute SourceFile

# ======= RAZORPAY PROGUARD RULES =======
# Keep all Razorpay classes
-keep class com.razorpay.** { *; }
-keep class com.olacabs.** { *; }
-keep class com.ola.** { *; }
-dontwarn com.razorpay.**

# Fix missing ProGuard annotation classes error
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers
-dontwarn proguard.annotation.**

# Keep WebView JavaScript interfaces (used by Razorpay)
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep JavaScript interface methods
-keepclassmembers class * {
    public *;
}

# ======= GOOGLE PLAY CORE RULES (Fix missing classes) =======
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ======= GRPC AND OKHTTP RULES =======
-dontwarn com.squareup.okhttp.**
-dontwarn io.grpc.**
-keep class com.squareup.okhttp.** { *; }
-keep class io.grpc.** { *; }

# ======= GSON RULES (used by Razorpay) =======
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep generic signature of TypeAdapter, TypeAdapterFactory, JsonSerializer, JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ======= NETWORKING RULES =======
# OkHttp and Retrofit (commonly used by payment gateways)
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

# ======= FIREBASE RULES =======
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ======= FLUTTER SPECIFIC RULES =======
# Keep Flutter classes and prevent deferred components issues
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Flutter Play Store Split Application classes
-dontwarn io.flutter.app.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ======= GENERAL ANDROID RULES =======
# Keep native methods
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep View classes and their methods
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
    *** get*();
}

# Keep Activity classes
-keep public class * extends android.app.Activity
-keep public class * extends androidx.appcompat.app.AppCompatActivity

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}