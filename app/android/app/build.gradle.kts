import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// [OCR 추가] 비교 앱은 운영 앱과 다른 패키지로 설치하여 구매 기록을 보존한다.
val ocrComparison = providers.gradleProperty("dart-defines").orNull
    ?.split(",")?.any {
        String(Base64.getDecoder().decode(it)) == "OCR_COMPARE=true"
    } == true

android {
    namespace = "com.todayone.todo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.todayone.todo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24 // [OCR 수정] 기존 Android 7.0 지원을 유지하며 Paddle 호환성을 먼저 검증한다.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        if (ocrComparison) {
            applicationIdSuffix = ".ocrcompare2"
        }
    }

    if (ocrComparison) {
        sourceSets.getByName("main") {
            java.srcDir("../ocr_compare/bridge")
            assets.srcDir("../ocr_compare/assets")
        }
    } else {
        // [OCR 추가] 일반 앱에는 검출·한국어 모델만 포함하고 시험 사진·Tesseract는 제외한다.
        sourceSets.getByName("main").assets.srcDir("../ocr_models")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Dart에서 한국어 인식을 요청하므로 기본 라틴어 모델 외에 한국어 모델도 포함한다.
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    // [OCR 수정] Android 기본 엔진에 Paddle SDK와 실행 자원을 연결한다.
    implementation(project(":ocr-compare-paddle"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    // [OCR 수정] Tesseract는 기존 독립 비교 빌드에서만 포함한다.
    if (ocrComparison) {
        implementation(files("../ocr_compare/libs/tesseract4android-4.9.0.aar"))
    }
}
