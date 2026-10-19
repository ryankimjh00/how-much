import 'dart:io'; // [OCR 추가]
import 'package:flutter/services.dart'; // [OCR 추가]
import 'package:how_much/ocr_service.dart'; // [OCR 추가]
import 'receipt_tilt_test.dart' show response; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_perspective.dart'; // [OCR 추가]
import 'package:how_much/receipt_perspective_screen.dart'; // [OCR 추가]

void main() {
  testWidgets('OCR은 원본 경로 대신 보정 바이트를 읽고 표시 사진·좌표를 함께 반환한다', (tester) async {
    // [OCR 추가]
    final path = await regionPhoto(
      tester,
      width: 900,
      height: 1800,
    ); // [OCR 추가]
    const channel = MethodChannel('google_mlkit_text_recognizer'); // [OCR 추가]
    final messenger = TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger; // [OCR 추가]
    final inputs = <Uint8List>[]; // [OCR 추가]
    messenger.setMockMethodCallHandler(channel, (call) async {
      // [OCR 추가]
      if (call.method == 'vision#closeTextRecognizer') return null; // [OCR 추가]
      inputs.add(
        await File(
          (call.arguments as Map)['imageData']['path'] as String,
        ).readAsBytes(),
      ); // [OCR 추가]
      return response(
        corrected: true,
      ); // [OCR 추가] 좌표 연결 검증용 응답이며 실제 사진 인식 결과가 아니다.
    }); // [OCR 추가]
    addTearDown(
      () => messenger.setMockMethodCallHandler(channel, null),
    ); // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      final bytes = await File(path).readAsBytes(); // [OCR 추가]
      final draft = await OcrService(engine: 'mlkit').recognizePath(
        '/does-not-exist-original.jpg',
        photoBytes: bytes,
      ); // [OCR 추가]
      expect(inputs, hasLength(1)); // [OCR 추가]
      expect(inputs.single, bytes); // [OCR 추가]
      expect(draft.ocrResult!.photoBytes, bytes); // [OCR 추가]
      expect(
        draft.ocrResult!.products.first.bounds,
        const Rect.fromLTRB(40, 50, 160, 80),
      ); // [OCR 추가]
    }); // [OCR 추가]
  }); // [OCR 추가]

  // [OCR 추가]
  test('사다리꼴 종이 자동 탐지는 네 모서리를 찾고 어두운 사진은 실패한다', () {
    // [OCR 추가]
    const width = 100; // [OCR 추가]
    const height = 150; // [OCR 추가]
    final pixels = Uint8List(width * height * 4); // [OCR 추가]
    for (var y = 0; y < height; y++) {
      // [OCR 추가]
      for (var x = 0; x < width; x++) {
        // [OCR 추가]
        final left = 20 - (y - 10) / 13; // [OCR 추가]
        final right = 80 + (y - 10) / 13; // [OCR 추가]
        final paper =
            y >= 10 && y <= 140 && x >= left && x <= right; // [OCR 추가]
        final offset = (y * width + x) * 4; // [OCR 추가]
        for (var channel = 0; channel < 3; channel++) {
          // [OCR 추가]
          pixels[offset + channel] = paper ? 230 : 30; // [OCR 추가]
        } // [OCR 추가]
        pixels[offset + 3] = 255; // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    final corners = detectReceiptCorners(pixels, width, height)!; // [OCR 추가]
    expect(
      (corners[0] - const Offset(20, 10)).distance,
      lessThan(2),
    ); // [OCR 추가]
    expect(
      (corners[2] - const Offset(90, 140)).distance,
      lessThan(2),
    ); // [OCR 추가]
    expect(
      detectReceiptCorners(Uint8List(pixels.length), width, height),
      isNull,
    ); // [OCR 추가]
  }); // [OCR 추가]
  test('교차·사진 밖·극소 영역은 보정하지 않는다', () {
    // [OCR 추가]
    const corners = [
      Offset(0, 0),
      Offset(99, 0),
      Offset(99, 149),
      Offset(0, 149),
    ]; // [OCR 추가]
    expect(
      validReceiptCorners(corners, const Size(100, 150)),
      isTrue,
    ); // [OCR 추가]
    expect(
      validReceiptCorners([
        corners[0],
        corners[2],
        corners[1],
        corners[3],
      ], const Size(100, 150)),
      isFalse,
    ); // [OCR 추가]
    expect(
      validReceiptCorners([
        const Offset(-1, 0),
        ...corners.skip(1),
      ], const Size(100, 150)),
      isFalse,
    ); // [OCR 추가]
  }); // [OCR 추가]
  test('역변환은 출력 모서리를 지정한 원본 모서리에 맞추며 색상을 보존한다', () {
    // [OCR 추가]
    final pixels = Uint8List(100 * 150 * 4); // [OCR 추가]
    for (var y = 0; y < 150; y++) {
      // [OCR 추가]
      for (var x = 0; x < 100; x++) {
        // [OCR 추가]
        final offset = (y * 100 + x) * 4; // [OCR 추가]
        pixels[offset] = x;
        pixels[offset + 1] = y;
        pixels[offset + 3] = 255; // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    const corners = [
      Offset(20, 10),
      Offset(80, 10),
      Offset(90, 140),
      Offset(10, 140),
    ]; // [OCR 추가]
    final output = warpReceiptPixels(pixels, 100, 150, corners); // [OCR 추가]
    final indices = [
      0,
      output.width - 1,
      output.width * output.height - 1,
      output.width * (output.height - 1),
    ]; // [OCR 추가]
    for (var index = 0; index < 4; index++) {
      // [OCR 추가]
      expect(
        output.pixels[indices[index] * 4],
        closeTo(corners[index].dx, 1),
      ); // [OCR 추가]
      expect(
        output.pixels[indices[index] * 4 + 1],
        closeTo(corners[index].dy, 1),
      ); // [OCR 추가]
      expect(output.pixels[indices[index] * 4 + 3], 255); // [OCR 추가]
    } // [OCR 추가]
    final identity = warpReceiptPixels(pixels, 100, 150, const [
      Offset.zero,
      Offset(99, 0),
      Offset(99, 149),
      Offset(0, 149),
    ]); // [OCR 추가]
    expect(identity.pixels, pixels); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('작은 화면에서 손잡이 이동·원본 사용·뒤로 취소가 가능하다', (tester) async {
    // [OCR 추가]
    tester.view.physicalSize = const Size(360, 640); // [OCR 추가]
    tester.view.devicePixelRatio = 1; // [OCR 추가]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
    final recorder = PictureRecorder(); // [OCR 추가]
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 100, 200),
      Paint()..color = Colors.white,
    ); // [OCR 추가]
    final picture = recorder.endRecording(); // [OCR 추가]
    late Uint8List bytes; // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      final image = await picture.toImage(100, 200); // [OCR 추가]
      bytes = (await image.toByteData(
        format: ImageByteFormat.png,
      ))!.buffer.asUint8List(); // [OCR 추가]
      image.dispose();
      picture.dispose(); // [OCR 추가]
    }); // [OCR 추가]
    Uint8List? result; // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            // [OCR 추가]
            onPressed: () async {
              result = await Navigator.push<Uint8List>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptPerspectiveScreen(bytes: bytes),
                ),
              );
            }, // [OCR 추가]
            child: const Text('열기'), // [OCR 추가]
          ),
        ),
      ),
    ); // [OCR 추가]
    await tester.tap(find.text('열기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가] 화면을 먼저 생성한 뒤 실제 이미지 비동기 처리를 기다린다.
    for (var attempt = 0; attempt < 30; attempt++) {
      // [OCR 추가]
      await tester.runAsync(() async {
        // [OCR 추가]
        await Future<void>.delayed(
          const Duration(milliseconds: 20),
        ); // [OCR 추가]
      }); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
      if (find
              .byKey(const ValueKey('perspective-corner-0'))
              .evaluate()
              .isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty) {
        break;
      } // [OCR 추가]
    } // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      find.byKey(const ValueKey('perspective-corner-0')),
      findsOneWidget,
    ); // [OCR 추가]
    await tester.drag(
      find.byKey(const ValueKey('perspective-corner-0')),
      const Offset(10, 15),
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
    await tester.tap(find.text('원본 사용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(result, same(bytes)); // [OCR 추가]
    result = null; // [OCR 추가]
    await tester.tap(find.text('열기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가] 화면을 먼저 생성한 뒤 실제 이미지 비동기 처리를 기다린다.
    for (var attempt = 0; attempt < 30; attempt++) {
      // [OCR 추가]
      await tester.runAsync(() async {
        // [OCR 추가]
        await Future<void>.delayed(
          const Duration(milliseconds: 20),
        ); // [OCR 추가]
      }); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
      if (find
              .byKey(const ValueKey('perspective-corner-0'))
              .evaluate()
              .isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty) {
        break;
      } // [OCR 추가]
    } // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.pageBack(); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(result, isNull); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
