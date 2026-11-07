# ML Kit text recognition ships the Latin model; the Chinese, Devanagari,
# Japanese and Korean recognizers are optional dependencies that the plugin
# references but the app doesn't include. Without these rules R8 fails the
# release build on the missing classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
