plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.File
import java.io.FileInputStream
import java.util.Properties

android {
    namespace = "com.skypiecode.pharmacy_saas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.skypiecode.nonota"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing (PLANS/08, SUPPORT_AND_ROLLBACK.md §3): reads
    // android/key.properties when it exists AND the keystore file it
    // points at exists. key.properties and the keystore are gitignored
    // and never committed; without a COMPLETE ceremony the release
    // buildType falls back to debug signing so CI, local dev, and the
    // emulator device-pass workflow stay unblocked — a half-done
    // ceremony (key.properties present but the keystore not yet
    // generated) must not break validation builds. Only the
    // checklist-gated pilot build path requires the real keystore
    // (SUPPORT_AND_ROLLBACK.md §6).
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    var keystoreStoreFile: File? = null
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        val storePath = keystoreProperties["storeFile"] as? String
        if (storePath != null) {
            val candidate = file(storePath)
            if (candidate.exists()) keystoreStoreFile = candidate
        }
    }

    signingConfigs {
        create("release") {
            if (keystoreStoreFile != null) {
                storeFile = keystoreStoreFile
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
