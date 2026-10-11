import 'dart:io'; // [OCR 추가]
import 'dart:math' as math; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter/services.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/app_store.dart'; // [OCR 추가]
import 'package:how_much/cloud_service.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/ocr_service.dart'; // [OCR 추가]
import 'package:how_much/receipt_image.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_product_regions.dart'; // [OCR 추가]
import 'package:how_much/receipt_region_screen.dart'; // [OCR 추가]
import 'package:how_much/receipt_selection_screen.dart'; // [OCR 추가]
import 'package:how_much/screens.dart'; // [OCR 추가]
import 'package:shared_preferences/shared_preferences.dart'; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto, loadRegion; // [OCR 추가]

List<ui.Offset> tiltedLine(double degrees, {double width = 120}) {
  // [OCR 추가]
  // [OCR 추가]
  final angle = degrees * math.pi / 180; // [OCR 추가]
  ui.Offset rotate(double x, double y) => ui.Offset(
    // [OCR 추가]
    // [OCR 추가]
    x * math.cos(angle) - y * math.sin(angle), // [OCR 추가]
    x * math.sin(angle) + y * math.cos(angle), // [OCR 추가]
  ); // [OCR 추가]
  return [
    // [OCR 추가]
    rotate(0, 0), // [OCR 추가]
    rotate(width, 0), // [OCR 추가]
    rotate(width, 20), // [OCR 추가]
    rotate(0, 20), // [OCR 추가]
  ]; // [OCR 추가]
} // [OCR 추가]

Map<String, dynamic> response({bool corrected = false, bool empty = false}) {
  // [OCR 추가]
  // [OCR 추가]
  final rect = {
    // [OCR 추가]
    'left': 40.0, // [OCR 추가]
    'top': 50.0, // [OCR 추가]
    'right': 160.0, // [OCR 추가]
    'bottom': 80.0, // [OCR 추가]
  }; // [OCR 추가]
  final texts =
      corrected // [OCR 추가]
      ? ['퍼실', '3', '80,940'] // [OCR 추가]
      : ['퍼실', '2', '53,960']; // [OCR 추가]
  final lines = [
    // [OCR 추가]
    // [OCR 추가]
    for (var index = 0; index < texts.length; index++) // [OCR 추가]
      {
        // [OCR 추가]
        // [OCR 추가]
        'text': texts[index], // [OCR 추가]
        'rect': {
          // [OCR 추가]
          ...rect, // [OCR 추가]
          'top': 50.0 + index * 50, // [OCR 추가]
          'bottom': 80.0 + index * 50, // [OCR 추가]
        }, // [OCR 추가]
        'recognizedLanguages': <String>[], // [OCR 추가]
        'points': [
          // [OCR 추가]
          // [OCR 추가]
          for (final point in tiltedLine(corrected ? 0 : 4)) // [OCR 추가]
            {'x': point.dx.round(), 'y': point.dy.round()}, // [OCR 추가]
        ], // [OCR 추가]
        'elements': [], // [OCR 추가]
      }, // [OCR 추가]
  ]; // [OCR 추가]
  return {
    // [OCR 추가]
    // [OCR 추가]
    'text': empty ? '' : texts.join('\n'), // [OCR 추가]
    'blocks':
        empty // [OCR 추가]
        ? [] // [OCR 추가]
        : [
            // [OCR 추가]
            // [OCR 추가]
            {
              // [OCR 추가]
              // [OCR 추가]
              'text': texts.join('\n'), // [OCR 추가]
              'rect': rect, // [OCR 추가]
              'recognizedLanguages': <String>[], // [OCR 추가]
              'points': [], // [OCR 추가]
              'lines': lines, // [OCR 추가]
            }, // [OCR 추가]
          ], // [OCR 추가]
  }; // [OCR 추가]
} // [OCR 추가]

void main() {
  // [OCR 추가]
  // [OCR 추가]
  TestWidgetsFlutterBinding.ensureInitialized(); // [OCR 추가]
  test('기울기는 여러 긴 가로 글줄의 합의로 정하고 세로·짧은 숫자·불확실한 방향은 제외한다', () {
    // [OCR 추가]
    // [OCR 추가]
    for (final sign in [-1, 1]) {
      // [OCR 추가]
      // [OCR 추가]
      expect(
        // [OCR 추가]
        estimateReceiptTilt([
              // [OCR 추가]
              // [OCR 추가]
              tiltedLine(sign * 4), // [OCR 추가]
              tiltedLine(sign * 4.2), // [OCR 추가]
              tiltedLine(sign * 3.8), // [OCR 추가]
              tiltedLine(-sign * 10), // [OCR 추가]
              tiltedLine(90), // [OCR 추가]
              tiltedLine(-8, width: 15), // [OCR 추가]
              [const Offset(double.nan, 0)], // [OCR 추가]
            ]) * // [OCR 추가]
            180 / // [OCR 추가]
            math.pi, // [OCR 추가]
        closeTo(sign * 4, .3), // [OCR 추가]
      ); // [OCR 추가]
    } // [OCR 추가]
    expect(estimateReceiptTilt([tiltedLine(4), tiltedLine(4)]), 0); // [OCR 추가]
    expect(
      // [OCR 추가]
      estimateReceiptTilt([
        tiltedLine(.1),
        tiltedLine(0),
        tiltedLine(-.1),
      ]), // [OCR 추가]
      0, // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      estimateReceiptTilt([
        tiltedLine(30),
        tiltedLine(30),
        tiltedLine(30),
      ]), // [OCR 추가]
      0, // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      estimateReceiptTilt([
        // [OCR 추가]
        for (final angle in [-10, -5, 0, 5, 10])
          tiltedLine(angle.toDouble()), // [OCR 추가]
      ]), // [OCR 추가]
      0, // [OCR 추가]
    ); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('합성 사진: 최대 3배 확대와 반대 방향 회전 및 흰 여백을 확인한다', (tester) async {
    // [OCR 수정]
    // [OCR 추가]
    // [OCR 추가]
    final path = await regionPhoto(tester, width: 100, height: 200); // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      // [OCR 추가]
      final bytes = await File(path).readAsBytes(); // [OCR 추가]
      expect(
        // [OCR 수정]
        (await prepareReceiptPhoto(bytes)).size, // [OCR 수정]
        const Size(300, 600), // [OCR 수정]
      ); // [OCR 수정]
      for (final sign in [-1, 1]) {
        // [OCR 추가]
        // [OCR 추가]
        final angle = sign * 5 * math.pi / 180; // [OCR 추가]
        final rotated = await prepareReceiptPhoto(
          // [OCR 수정]
          bytes, // [OCR 수정]
          angle: angle, // [OCR 수정]
        ); // [OCR 수정]
        final codec = await ui.instantiateImageCodec(rotated.bytes); // [OCR 추가]
        final image = (await codec.getNextFrame()).image; // [OCR 추가]
        codec.dispose(); // [OCR 추가]
        expect(
          // [OCR 추가]
          image.width, // [OCR 추가]
          (300 * math.cos(angle) + 600 * math.sin(angle).abs()) // [OCR 수정]
              .ceil(), // [OCR 추가]
        ); // [OCR 추가]
        expect(
          // [OCR 추가]
          image.height, // [OCR 추가]
          (600 * math.cos(angle) + 300 * math.sin(angle).abs()) // [OCR 수정]
              .ceil(), // [OCR 추가]
        ); // [OCR 추가]
        final pixels = (await image.toByteData())!; // [OCR 추가]
        expect(
          // [OCR 추가]
          [for (var i = 0; i < 4; i++) pixels.getUint8(i)], // [OCR 추가]
          [255, 255, 255, 255], // [OCR 추가]
        ); // [OCR 추가]
        // 파란 영역 중심이 반대 방향 회전한 위치에 있어야 한다. // [OCR 추가]
        final x = // [OCR 추가]
            (image.width / 2 +
                    90 * math.cos(angle) - // [OCR 수정]
                    105 * math.sin(angle)) // [OCR 추가]
                .round(); // [OCR 추가]
        final y = // [OCR 추가]
            (image.height / 2 -
                    90 * math.sin(angle) - // [OCR 수정]
                    105 * math.cos(angle)) // [OCR 추가]
                .round(); // [OCR 추가]
        final offset = (y * image.width + x) * 4; // [OCR 추가]
        expect(
          // [OCR 추가]
          pixels.getUint8(offset + 2), // [OCR 추가]
          greaterThan(pixels.getUint8(offset)), // [OCR 추가]
        ); // [OCR 추가]
        image.dispose(); // [OCR 추가]
      } // [OCR 추가]
      await expectLater(
        // [OCR 추가]
        prepareReceiptPhoto(bytes, angle: double.nan), // [OCR 추가]
        throwsFormatException, // [OCR 추가]
      ); // [OCR 추가]
    }); // [OCR 추가]
  }); // [OCR 추가]
  for (final outcome in ['success', 'empty', 'error']) {
    // [OCR 추가]
    // [OCR 추가]
    testWidgets('모의 ML Kit 기울기 보정: $outcome 결과의 사진·좌표 일치와 실패 복구·임시 파일 정리', (
      // [OCR 추가]
      tester, // [OCR 추가]
    ) async {
      // [OCR 추가]
      // [OCR 추가]
      final path = await regionPhoto(tester); // [OCR 추가]
      const channel = MethodChannel('google_mlkit_text_recognizer'); // [OCR 추가]
      final messenger =
          TestDefaultBinaryMessengerBinding // [OCR 추가]
              .instance // [OCR 추가]
              .defaultBinaryMessenger; // [OCR 추가]
      var calls = 0; // [OCR 추가]
      var closes = 0; // [OCR 추가]
      String? correctedPath; // [OCR 추가]
      messenger.setMockMethodCallHandler(channel, (call) async {
        // [OCR 추가]
        // [OCR 추가]
        if (call.method == 'vision#closeTextRecognizer') {
          // [OCR 추가]
          closes++; // [OCR 추가]
          return null; // [OCR 추가]
        } // [OCR 추가]
        calls++; // [OCR 추가]
        if (calls == 1) return response(); // [OCR 추가]
        correctedPath = // [OCR 추가]
            (call.arguments as Map)['imageData']['path'] as String; // [OCR 추가]
        expect(await File(correctedPath!).exists(), isTrue); // [OCR 추가]
        if (outcome == 'error') {
          // [OCR 추가]
          throw PlatformException(code: 'ocr-failed'); // [OCR 추가]
        } // [OCR 추가]
        return response(corrected: true, empty: outcome == 'empty'); // [OCR 추가]
      }); // [OCR 추가]
      addTearDown(
        // [OCR 추가]
        () => messenger.setMockMethodCallHandler(channel, null), // [OCR 추가]
      ); // [OCR 추가]
      await tester.runAsync(() async {
        // [OCR 추가]
        // [OCR 추가]
        final original = await File(path).readAsBytes(); // [OCR 추가]
        final result = (await OcrService().recognizePath(
          // [OCR 추가]
          path, // [OCR 추가]
        )).ocrResult!; // [OCR 추가]
        expect(calls, 2); // [OCR 추가]
        expect(closes, 2); // [OCR 추가]
        expect(
          // [OCR 추가]
          await Directory(
            File(correctedPath!).parent.path,
          ).exists(), // [OCR 추가]
          isFalse, // [OCR 추가]
        ); // [OCR 추가]
        expect(
          // [OCR 추가]
          await File(path).readAsBytes(), // [OCR 추가]
          orderedEquals(original), // [OCR 추가]
        ); // [OCR 추가]
        expect(result.photoPath, path); // [OCR 추가]
        expect(
          // [OCR 추가]
          result.numbers.map((candidate) => candidate.number), // [OCR 추가]
          outcome == 'success' ? [3, 80940] : [2, 53960], // [OCR 추가]
        ); // [OCR 추가]
        if (outcome == 'success') {
          // [OCR 추가]
          // [OCR 추가]
          expect(result.photoBytes, isNotNull); // [OCR 추가]
          expect(result.photoBytes, isNot(orderedEquals(original))); // [OCR 추가]
          final fragments = ReceiptOcrResult(
            // [OCR 추가]
            text: result.text, // [OCR 추가]
            photoPath: path, // [OCR 추가]
            photoBytes: result.photoBytes, // [OCR 추가]
            rows: result.rows, // [OCR 추가]
            numbers: result.numbers, // [OCR 추가]
            products: [
              // [OCR 추가]
              const ReceiptOcrCandidate(
                id: 'left',
                text: '퍼',
                bounds: Rect.fromLTWH(40, 50, 20, 20),
              ), // [OCR 추가]
              const ReceiptOcrCandidate(
                id: 'right',
                text: '실',
                bounds: Rect.fromLTWH(65, 50, 20, 20),
              ), // [OCR 추가]
            ], // [OCR 추가]
          ); // [OCR 추가]
          final merged = mergeReceiptProductRegions(fragments); // [OCR 추가]
          expect(merged.products.single.isMergedName, isTrue); // [OCR 추가]
          expect(merged.photoBytes, same(result.photoBytes)); // [OCR 추가]
          final reread = await rereadMergedProductNames(
            merged,
            (_) async => '퍼실',
          ); // [OCR 추가]
          expect(reread.products.single.text, '퍼실'); // [OCR 추가]
          expect(reread.photoBytes, same(result.photoBytes)); // [OCR 추가]
          expect(
            // [OCR 추가]
            result.rows.first.bounds, // [OCR 추가]
            const Rect.fromLTRB(40, 50, 160, 80), // [OCR 추가]
          ); // [OCR 추가]
        } else {
          // [OCR 추가]
          // [OCR 추가]
          expect(
            // [OCR 수정]
            result.photoBytes, // [OCR 수정]
            orderedEquals(
              (await prepareReceiptPhoto(original)).bytes,
            ), // [OCR 수정]
          ); // [OCR 수정]
          expect(result.text, '퍼실\n2\n53,960'); // [OCR 추가]
        } // [OCR 추가]
      }); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]
  for (final screen in ['selection', 'review', 'region']) {
    // [OCR 추가]
    // [OCR 추가]
    testWidgets('보정 사진 전달: $screen 화면은 원본 경로 대신 같은 메모리 사진을 표시한다', (
      // [OCR 추가]
      tester, // [OCR 추가]
    ) async {
      // [OCR 추가]
      // [OCR 추가]
      SharedPreferences.setMockInitialValues({}); // [OCR 추가]
      final path = await regionPhoto(tester); // [OCR 추가]
      late Uint8List bytes; // [OCR 추가]
      await tester.runAsync(() async {
        // [OCR 추가]
        bytes = (await prepareReceiptPhoto(
          // [OCR 수정]
          await File(path).readAsBytes(), // [OCR 수정]
          angle: 4 * math.pi / 180, // [OCR 수정]
        )).bytes; // [OCR 수정] // [OCR 추가]
      }); // [OCR 추가]
      final source = ReceiptOcrResult(
        // [OCR 추가]
        text: '', // [OCR 추가]
        photoPath: '/missing-original.png', // [OCR 추가]
        photoBytes: bytes, // [OCR 추가]
        rows: [], // [OCR 추가]
        products: [], // [OCR 추가]
        numbers: [], // [OCR 추가]
      ); // [OCR 추가]
      final draft = ReceiptDraft(
        // [OCR 추가]
        id: 'tilt', // [OCR 추가]
        store: '', // [OCR 추가]
        purchasedOn: '2026-10-06', // [OCR 추가]
        lines: [], // [OCR 추가]
        ocrResult: source, // [OCR 추가]
      ); // [OCR 추가]
      final store = AppStore(CloudService(false)); // [OCR 추가]
      addTearDown(store.dispose); // [OCR 추가]
      late Widget page; // [OCR 추가]
      if (screen == 'selection') {
        // [OCR 추가]
        // [OCR 추가]
        page = ReceiptSelectionScreen(draft: draft); // [OCR 추가]
      } else if (screen == 'review') {
        // [OCR 추가]
        // [OCR 추가]
        page = ReceiptReviewScreen(store: store, draft: draft); // [OCR 추가]
      } else {
        // [OCR 추가]
        // [OCR 추가]
        page = ReceiptRegionScreen(
          // [OCR 추가]
          photoPath: source.photoPath, // [OCR 추가]
          photoBytes: bytes, // [OCR 추가]
          label: '수량', // [OCR 추가]
          numeric: true, // [OCR 추가]
        ); // [OCR 추가]
      } // [OCR 추가]
      await tester.pumpWidget(MaterialApp(home: page)); // [OCR 추가]
      await loadRegion(tester); // [OCR 추가]
      expect(find.byType(InteractiveViewer), findsOneWidget); // [OCR 추가]
      final image = tester.widget<Image>(find.byType(Image)); // [OCR 추가]
      expect((image.image as MemoryImage).bytes, same(bytes)); // [OCR 추가]
      expect(tester.takeException(), isNull); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]
} // [OCR 추가]
