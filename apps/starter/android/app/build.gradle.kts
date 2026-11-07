// #if social-login-kakao|social-login-naver
import java.util.Properties

// #endif
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// #if social-login-kakao|social-login-naver
// Social sign-in values of the manifest (Kakao scheme, Naver client). They live
// in android/social.properties, which is git-ignored; see social.properties.example.
// Without the file they are empty and the app still builds.
val social = Properties().apply {
    val file = rootProject.file("social.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// #endif
android {
    namespace = "com.example.starter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.starter"
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
        // #if social-login-kakao
        manifestPlaceholders["kakaoNativeAppKey"] = social.getProperty("kakaoNativeAppKey", "")
        // #endif
        // #if social-login-naver
        manifestPlaceholders["naverClientId"] = social.getProperty("naverClientId", "")
        manifestPlaceholders["naverClientSecret"] = social.getProperty("naverClientSecret", "")
        manifestPlaceholders["naverClientName"] = social.getProperty("naverClientName", "")
        // #endif
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
