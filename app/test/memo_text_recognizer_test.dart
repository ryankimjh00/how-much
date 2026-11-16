import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/memo_text_recognizer.dart';
import 'package:how_much/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const vision = MethodChannel('how_much/memo_text_recognizer');
  const mlkit = MethodChannel('google_mlkit_text_recognizer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(mlkit, (call) async {
      calls.add(call.method);
      if (call.method == 'vision#closeTextRecognizer') return null;
      expect(call.arguments['script'], 4);
      return {'text': '우유 2개', 'blocks': []};
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(vision, null);
    messenger.setMockMethodCallHandler(mlkit, null);
  });

  test('iOS 메모는 Vision 결과를 검토 초안으로 전달하고 임의로 선택하지 않는다', () async {
    messenger.setMockMethodCallHandler(vision, (call) async {
      expect(call.method, 'recognize');
      expect(call.arguments, {'path': '/memo.jpg'});
      return '- 두부 2개\n- 대파';
    });

    final lines = await OcrService().recognizeMemoPath('/memo.jpg');

    expect(lines.map((line) => line.title), ['두부', '대파']);
    expect(lines.first.quantity, 2);
    expect(lines.every((line) => !line.selected), isTrue);
    expect(calls, isEmpty);
  });

  for (final response in ['', '7}971', null]) {
    test('Vision 결과 $response 에 상품이 없으면 한국어 ML Kit로 다시 읽는다', () async {
      messenger.setMockMethodCallHandler(vision, (_) async => response);

      expect(await MemoTextRecognizer().processImage('/memo.jpg'), '우유 2개');
      expect(calls, [
        'vision#startTextRecognizer',
        'vision#closeTextRecognizer',
      ]);
    });
  }

  test('Vision 오류와 미등록 환경은 기존 인식기로 복구한다', () async {
    messenger.setMockMethodCallHandler(vision, (_) async {
      throw PlatformException(code: 'vision_failed');
    });
    expect(await MemoTextRecognizer().processImage('/memo.jpg'), '우유 2개');

    messenger.setMockMethodCallHandler(vision, null);
    expect(await MemoTextRecognizer().processImage('/memo.jpg'), '우유 2개');
    expect(
      calls.where((method) => method == 'vision#closeTextRecognizer'),
      hasLength(2),
    );
  });

  test('Android는 Vision을 호출하지 않고 기존 한국어 인식기를 사용한다', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(vision, (_) async {
      fail('Android에서 iOS 채널을 호출했습니다.');
    });

    expect(await MemoTextRecognizer().processImage('/memo.jpg'), '우유 2개');
    expect(calls, ['vision#startTextRecognizer', 'vision#closeTextRecognizer']);
  });

  test('두 인식기가 모두 실패하면 최종 오류를 전달하고 ML Kit를 해제한다', () async {
    messenger.setMockMethodCallHandler(vision, (_) async {
      throw PlatformException(code: 'vision_failed');
    });
    messenger.setMockMethodCallHandler(mlkit, (call) async {
      calls.add(call.method);
      if (call.method == 'vision#closeTextRecognizer') return null;
      throw PlatformException(code: 'image_unavailable');
    });

    await expectLater(
      MemoTextRecognizer().processImage('/missing.jpg'),
      throwsA(isA<PlatformException>()),
    );
    expect(calls.last, 'vision#closeTextRecognizer');
  });
}
