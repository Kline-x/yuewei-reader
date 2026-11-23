# Flutter & Dart 平台保护
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SQLite / Drift 原生绑定保护
-keep class androidx.sqlite.** { *; }
-keep class eu.simonbinder.sqlite3_flutter_libs.** { *; }
-keep class com.sun.jna.** { *; }
-dontwarn com.sun.jna.**

# 阅微原生宿主桥接保护
-keep class com.kline.yuewei_reader.** { *; }

# Flutter PlayStoreDeferredComponentManager 对可选 Play Core 库的引用抑制
-dontwarn com.google.android.play.core.**
