package com.todayone.todo

import io.flutter.embedding.android.FlutterActivity

// [OCR 수정] Flutter 화면을 실행하는 기본 진입점이다.
// ML Kit의 기기 코드 연결은 Flutter 플러그인이 등록하므로 별도 OCR 채널을 만들지 않는다.
// 인식기 생성·재사용·해제 요청은 Dart의 ReceiptTextRecognizer에서 관리한다.
class MainActivity : FlutterActivity()
