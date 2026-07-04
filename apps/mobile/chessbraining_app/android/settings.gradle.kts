pluginManagement {
    val flutterSdkPath =
        run {
            val localPropertiesFile = file("local.properties")
            var flutterSdkPath: String? = null
            if (localPropertiesFile.exists()) {
                val properties = java.util.Properties()
                localPropertiesFile.inputStream().use { properties.load(it) }
                flutterSdkPath = properties.getProperty("flutter.sdk")
            }
            if (flutterSdkPath == null) {
                flutterSdkPath = System.getenv("FLUTTER_ROOT")
            }
            if (flutterSdkPath == null) {
                throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file or with a FLUTTER_ROOT environment variable.")
            }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
