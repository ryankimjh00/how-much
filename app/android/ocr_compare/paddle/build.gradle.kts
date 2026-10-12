// [OCR 수정] 검증한 공식 Paddle SDK를 비교·기본 Android 인식에서 함께 사용한다.
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.paddle.ocr"
    compileSdk = 36
    // [OCR 수정] ORT는 API24, OpenCV는 API21부터 지원한다. 앱의 Android7 기준을 유지한다.
    // 예제의 API26 선언을 조정했으므로 API24 실제 실행 검증을 별도로 기록한다.
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.21.1")
    // [OCR 수정] 구 배포본의 x86_64 로딩 오류(__lttf2)를 피하는 공식 Android 배포본이다.
    implementation("org.opencv:opencv:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
