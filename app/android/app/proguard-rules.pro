# ML Kit Text Recognition ships one artifact per script. The Flutter plugin
# references all five; this app bundles Latin and Devanagari only (Devanagari
# is declared in build.gradle.kts), so R8 finds the other three missing and
# fails the release build without these lines.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
