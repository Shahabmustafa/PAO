import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.pao.pao"
    // Android 16 (API 36) — required by Google Play's 2026 target API level policy.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pao.pao"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications (core library desugaring).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// Works around an AGP bug: once core library desugaring is enabled but the
// project has no actual baseline-profile source, :app:l8DexDesugarLibRelease
// leaves its output directory empty instead of writing an empty
// baseline-prof.txt, yet :app:compileReleaseArtProfile still requires that
// exact file to exist as an input. An empty file is a valid "no extra
// profile rules" baseline profile, so create it ourselves if L8 didn't.
tasks.matching { it.name == "compileReleaseArtProfile" }.configureEach {
    doFirst {
        val desugarProfile = file(
            "$buildDir/intermediates/l8_art_profile/release/l8DexDesugarLibRelease/baseline-prof.txt"
        )
        if (!desugarProfile.exists()) {
            desugarProfile.parentFile.mkdirs()
            desugarProfile.writeText("")
        }
    }
}
