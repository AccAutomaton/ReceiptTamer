# Keep Kotlin Parcelize annotations
-keep class kotlinx.parcelize.** { *; }
-dontwarn kotlinx.parcelize.Parcelize

# Keep OCR library classes
-keep class com.benjaminwan.ocrlibrary.** { *; }

# Keep MNN JNI classes
-keep class com.acautomaton.receipt.tamer.** { *; }