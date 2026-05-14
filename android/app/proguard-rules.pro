# Proguard rules for sign_in_with_apple
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep the plugin classes
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }
