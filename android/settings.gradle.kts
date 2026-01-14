// android/settings.gradle.kts

pluginManagement {
    val flutterSdkPath = run {
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
        // Mirrors + Flutter Maven
        maven(url = "https://repo1.maven.org/maven2")
        maven(url = "https://maven-central.storage-download.googleapis.com/maven2/")
        maven(url = "https://storage.googleapis.com/download.flutter.io")
    }
}

dependencyResolutionManagement {
    // Use settings repos, not project-declared ones
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // Mirrors + Flutter Maven
        maven(url = "https://repo1.maven.org/maven2")
        maven(url = "https://maven-central.storage-download.googleapis.com/maven2/")
        maven(url = "https://storage.googleapis.com/download.flutter.io")
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    // Bump to latest Google services plugin
    id("com.google.gms.google-services") version "4.4.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")