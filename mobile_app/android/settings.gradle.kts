pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Version floors are set by Flutter, which fails the build (not warns) once a
// version drops below its minimum. Flutter 3.47.0 requires AGP >= 8.11.1 and
// Kotlin >= 2.2.20. Keep these in step whenever the pinned Flutter in
// .github/workflows/ is bumped — the two move together.
// AGP 8.11.x requires Gradle >= 8.13; we pin 8.14.3 in gradle-wrapper.properties.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
