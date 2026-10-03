plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.afterburners.winger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time on every API level.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.afterburners.winger"
        // The ML Kit floor, and roughly 97% of the Android phones in use in India.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Debug-signed so `flutter build apk --release` installs on a demo phone.
            // A store build gets its own signing config.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // The ML Kit plugin only compiles against the non-Latin scripts; the app
    // has to ship the ones it uses. Without this, reading a Hindi note on a
    // prescription crashes on the phone — and only a release build (R8) says so.
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
}

flutter {
    source = "../.."
}
