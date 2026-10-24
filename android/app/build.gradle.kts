import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// The versionCode/versionName are parsed straight from pubspec.yaml instead of relying on
// `flutter.versionCode` / `flutter.versionName`.
val pubspecVersion = rootProject.file("../pubspec.yaml")
    .readLines()
    .firstOrNull { it.trimStart().startsWith("version:") }
    ?.substringAfter("version:")
    ?.trim()
    .orEmpty()

val appVersionName = pubspecVersion.substringBefore("+")
val appVersionCode = pubspecVersion.substringAfter("+", "")
    .takeIf { it.isNotEmpty() }
    ?.toIntOrNull()

require(appVersionCode != null) {
    "pubspec.yaml has `version: $pubspecVersion`, which has no build number. " +
        "Flutter then silently builds with versionCode 1. " +
        "Use `version: ${appVersionName.ifEmpty { "1.0.0" }}+<buildNumber>` " +
        "(e.g. `version: ${appVersionName.ifEmpty { "1.0.0" }}+100`) and make the build number " +
        "higher than every versionCode already published on Play Console."
}

android {
    namespace = "com.pugazh.kipt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.pugazh.kipt"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = appVersionCode
        versionName = appVersionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storePassword = keystoreProperties["storePassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}