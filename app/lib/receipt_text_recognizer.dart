import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // [OCR 추가]
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// [OCR 추가] 빌드마다 한 엔진만 사용한다. 대체 엔진 오류 시 ML Kit로 보완하지 않는다.
class ReceiptTextRecognizer {
  ReceiptTextRecognizer({String? engine})
    : engine = engine ?? selectedEngine; // [OCR 수정]

  static const _configuredEngine = String.fromEnvironment(
    'OCR_ENGINE',
  ); // [OCR 수정]
  // [OCR 추가] Android를 Paddle로 바꾸고 네이티브 연결이 없는 iOS는 기존 ML Kit를 유지한다.
  static String get selectedEngine {
    if (_configuredEngine.isNotEmpty) return _configuredEngine;
    if (defaultTargetPlatform == TargetPlatform.android) return 'paddle';
    return 'mlkit';
  }

  static const channel = MethodChannel('howmuch/receipt_ocr'); // [OCR 수정]
  static const comparisonChannel = MethodChannel(
    'howmuch/ocr_comparison',
  ); // [OCR 추가]
  MethodChannel get _nativeChannel =>
      engine == 'tesseract' ? comparisonChannel : channel; // [OCR 추가]
  static int _nextId = 0;
  final String engine;
  final String _id = 'receipt-reader-${_nextId++}';
  TextRecognizer? _mlkit;
  bool _closed = false;

  /// [OCR 추가] 사진 경로를 선택된 기기 내 인식기로 전달하고 원문·좌표를 반환한다.
  Future<RecognizedText> processImage(InputImage image, {int psm = 3}) async {
    if (_closed) throw StateError('종료된 OCR 인식기입니다.');
    if (engine == 'mlkit') {
      final recognizer = _mlkit ??= TextRecognizer(
        script: TextRecognitionScript.korean,
      );
      return recognizer.processImage(image);
    }
    if (engine != 'paddle' && engine != 'tesseract') {
      throw ArgumentError.value(engine, 'OCR_ENGINE', '지원하지 않는 엔진');
    }
    final path = image.filePath;
    if (path == null) {
      throw ArgumentError('Paddle·Tesseract에는 사진 경로가 필요합니다.'); // [OCR 수정]
    }
    final response = await _nativeChannel.invokeMapMethod<String, dynamic>(
      'recognize',
      {'id': _id, 'engine': engine, 'path': path, 'psm': psm},
    );
    if (response == null) throw StateError('OCR 응답이 없습니다.');
    return receiptRecognizedTextFromNative(response);
  }

  /// [OCR 추가] 세션 종료 시 선택된 엔진의 자원만 해제한다.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (engine == 'mlkit') {
      await _mlkit?.close();
    } else if (engine == 'paddle' || engine == 'tesseract') {
      await _nativeChannel.invokeMethod<void>('close', {'id': _id}); // [OCR 수정]
    }
  }
}

/// [OCR 추가] 엔진이 반환한 글줄·단어 상자를 보존하며 임의의 단어 분할은 하지 않는다.
RecognizedText receiptRecognizedTextFromNative(Map<String, dynamic> response) {
  final blocks = <TextBlock>[];
  for (final value in response['lines'] as List<dynamic>) {
    final line = Map<String, dynamic>.from(value as Map);
    final bounds = _nativeBounds(line);
    final points = _nativePoints(line);
    final elements = <TextElement>[];
    for (final rawElement in line['elements'] as List<dynamic>) {
      final element = Map<String, dynamic>.from(rawElement as Map);
      elements.add(
        TextElement(
          text: element['text'] as String,
          symbols: const [],
          boundingBox: _nativeBounds(element),
          recognizedLanguages: const [],
          cornerPoints: _nativePoints(element),
          confidence: (element['confidence'] as num?)?.toDouble(),
          angle: (element['angle'] as num?)?.toDouble(),
        ),
      );
    }
    final text = line['text'] as String;
    blocks.add(
      TextBlock(
        text: text,
        lines: [
          TextLine(
            text: text,
            elements: elements,
            boundingBox: bounds,
            recognizedLanguages: const [],
            cornerPoints: points,
            confidence: (line['confidence'] as num?)?.toDouble(),
            angle: (line['angle'] as num?)?.toDouble(),
          ),
        ],
        boundingBox: bounds,
        recognizedLanguages: const [],
        cornerPoints: points,
      ),
    );
  }
  return RecognizedText(text: response['text'] as String, blocks: blocks);
}

Rect _nativeBounds(Map<String, dynamic> value) {
  final bounds = (value['bounds'] as List).cast<num>();
  if (bounds.length != 4 || bounds.any((number) => !number.isFinite)) {
    throw const FormatException('OCR 상자 좌표가 유효하지 않습니다.');
  }
  final rect = Rect.fromLTRB(
    bounds[0].toDouble(),
    bounds[1].toDouble(),
    bounds[2].toDouble(),
    bounds[3].toDouble(),
  );
  if (rect.isEmpty) throw const FormatException('OCR 상자가 비어 있습니다.');
  return rect;
}

List<Point<int>> _nativePoints(Map<String, dynamic> value) => [
  for (final point in value['points'] as List<dynamic>)
    Point((point[0] as num).round(), (point[1] as num).round()),
];
