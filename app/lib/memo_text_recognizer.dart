import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'models.dart';
import 'receipt_text_recognizer.dart';

/// 메모 사진을 기기 내에서 읽는다. iOS의 한국어 Vision이 실패하면 ML Kit로 다시 읽는다.
class MemoTextRecognizer {
  static const _channel = MethodChannel('how_much/memo_text_recognizer');

  /// 외부로 사진을 보내거나 파일을 삭제하지 않고 인식문을 반환한다.
  Future<String> processImage(String path) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final text = await _channel.invokeMethod<String>('recognize', {
          'path': path,
        });
        if (text != null && parseMemoText(text).isNotEmpty) return text;
      } on MissingPluginException {
        // 이전 설치본과 한국어 Vision을 지원하지 않는 환경도 기존 인식기를 사용한다.
      } on PlatformException {
        // Vision 오류만으로 사진을 버리지 않고 한국어 ML Kit를 한 번 더 시도한다.
      }
    }

    final recognizer = ReceiptTextRecognizer();
    try {
      return (await recognizer.processImage(
        InputImage.fromFilePath(path),
      )).text;
    } finally {
      await recognizer.close();
    }
  }
}
