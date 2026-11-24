plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.omnix_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.omnix_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Release signing from Gradle properties (injected by CI via
            // -Pandroid.injected.signing.*). No passwords or absolute paths
            // are hardcoded here. If any property is missing, this config
            // stays empty and the release build falls back to debug signing.
            val storeFilePath = project.findProperty("android.injected.signing.store.file") as String?
            val storePass = project.findProperty("android.injected.signing.store.password") as String?
            val keyAliasValue = project.findProperty("android.injected.signing.key.alias") as String?
            val keyPass = project.findProperty("android.injected.signing.key.password") as String?
            if (storeFilePath != null && storePass != null && keyAliasValue != null && keyPass != null) {
                storeFile = file(storeFilePath)
                storePassword = storePass
                keyAlias = keyAliasValue
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        release {
            // Use release signing when all injected properties are present
            // (CI); otherwise fall back to debug signing so local builds
            // keep working without any properties configured.
            signingConfig = if (
                project.hasProperty("android.injected.signing.store.file") &&
                project.hasProperty("android.injected.signing.store.password") &&
                project.hasProperty("android.injected.signing.key.alias") &&
                project.hasProperty("android.injected.signing.key.password")
            ) {
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

dependencies {
    // Media3 (pengganti audio_service untuk media session + notifikasi,
    // 24 Nov 2026). media3-session: MediaSessionService + MediaSession
    // yang memposting notifikasi media otomatis. media3-common:
    // SimpleBasePlayer yang dipakai DartMirroringPlayer.
    val media3Version = "1.11.1"
    implementation("androidx.media3:media3-session:$media3Version")
    implementation("androidx.media3:media3-common:$media3Version")
}
