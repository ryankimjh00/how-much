import 'dart:io'; // [OCR 추가]
import 'dart:math' as math; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:flutter/services.dart'; // [OCR 추가]
import 'package:how_much/receipt_image.dart'; // [OCR 추가]
import 'package:how_much/ocr_service.dart'; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto; // [OCR 추가]
import 'receipt_tilt_test.dart' show response; // [OCR 추가]

void main() {
  // [OCR 추가]
  // [OCR 추가]
  testWidgets('확대는 긴 변 1600 목표·최대 3배이며 큰 사진은 원본 바이트를 유지한다', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    for (final size in [
      // [OCR 추가]
      const ui.Size(100, 200), // [OCR 추가]
      const ui.Size(300, 800), // [OCR 추가]
      const ui.Size(900, 1800), // [OCR 추가]
    ]) {
      // [OCR 추가]
      // [OCR 추가]
      final path = await regionPhoto(
        // [OCR 추가]
        tester, // [OCR 추가]
        width: size.width.toInt(), // [OCR 추가]
        height: size.height.toInt(), // [OCR 추가]
      ); // [OCR 추가]
      await tester.runAsync(() async {
        // [OCR 추가]
        // [OCR 추가]
        final bytes = await File(path).readAsBytes(); // [OCR 추가]
        final photo = await prepareReceiptPhoto(bytes); // [OCR 추가]
        final scale = (1600 / size.longestSide).clamp(1.0, 3.0); // [OCR 추가]
        expect(
          // [OCR 추가]
          photo.size, // [OCR 추가]
          ui.Size(
            // [OCR 추가]
            (size.width * scale).ceilToDouble(), // [OCR 추가]
            (size.height * scale).ceilToDouble(), // [OCR 추가]
          ), // [OCR 추가]
        ); // [OCR 추가]
        if (scale == 1) expect(photo.bytes, same(bytes)); // [OCR 추가]
      }); // [OCR 추가]
    } // [OCR 추가]
  }); // [OCR 추가]
  for (final outcome in [
    // [OCR 추가]
    'success', // [OCR 추가]
    'empty', // [OCR 추가]
    'error', // [OCR 추가]
    'straight', // [OCR 추가]
    'first-error', // [OCR 추가]
  ]) {
    // [OCR 추가]
    // [OCR 추가]
    testWidgets(
      // [OCR 추가]
      '모의 ML Kit 전체 전처리 $outcome: 첫 확대 OCR→원본 확대·회전→재OCR 및 사진·좌표 동시 복구', // [OCR 추가]
      (tester) async {
        // [OCR 추가]
        // [OCR 추가]
        final path = await regionPhoto(
          // [OCR 추가]
          tester, // [OCR 추가]
          width: 300, // [OCR 추가]
          height: 800, // [OCR 추가]
        ); // [OCR 추가]
        const channel = MethodChannel(
          // [OCR 추가]
          'google_mlkit_text_recognizer', // [OCR 추가]
        ); // [OCR 추가]
        final messenger =
            TestDefaultBinaryMessengerBinding // [OCR 추가]
                .instance // [OCR 추가]
                .defaultBinaryMessenger; // [OCR 추가]
        final temporaryPaths = <String>[]; // [OCR 추가]
        final inputs = <Uint8List>[]; // [OCR 추가]
        var closes = 0; // [OCR 추가]
        messenger.setMockMethodCallHandler(channel, (call) async {
          // [OCR 추가]
          // [OCR 추가]
          if (call.method == 'vision#closeTextRecognizer') {
            // [OCR 추가]
            closes++; // [OCR 추가]
            return null; // [OCR 추가]
          } // [OCR 추가]
          final photoPath = // [OCR 추가]
              (call.arguments as Map)['imageData']['path'] // [OCR 추가]
                  as String; // [OCR 추가]
          temporaryPaths.add(photoPath); // [OCR 추가]
          inputs.add(await File(photoPath).readAsBytes()); // [OCR 추가]
          if (outcome == 'first-error' || // [OCR 추가]
              (inputs.length == 2 && outcome == 'error')) {
            // [OCR 추가]
            // [OCR 추가]
            throw PlatformException(code: 'ocr-failed'); // [OCR 추가]
          } // [OCR 추가]
          return response(
            // [OCR 추가]
            corrected: inputs.length == 2 || outcome == 'straight', // [OCR 추가]
            empty: inputs.length == 2 && outcome == 'empty', // [OCR 추가]
          ); // [OCR 추가]
        }); // [OCR 추가]
        addTearDown(
          // [OCR 추가]
          () => messenger.setMockMethodCallHandler(channel, null), // [OCR 추가]
        ); // [OCR 추가]
        await tester.runAsync(() async {
          // [OCR 추가]
          // [OCR 추가]
          final original = await File(path).readAsBytes(); // [OCR 추가]
          if (outcome == 'first-error') {
            // [OCR 추가]
            // [OCR 추가]
            await expectLater(
              // [OCR 추가]
              OcrService().recognizePath(path), // [OCR 추가]
              throwsA(isA<PlatformException>()), // [OCR 추가]
            ); // [OCR 추가]
          } else {
            // [OCR 추가]
            // [OCR 추가]
            final result = (await OcrService().recognizePath(
              // [OCR 추가]
              path, // [OCR 추가]
            )).ocrResult!; // [OCR 추가]
            final first = await prepareReceiptPhoto(original); // [OCR 추가]
            expect(inputs.first, orderedEquals(first.bytes)); // [OCR 추가]
            final success = outcome == 'success'; // [OCR 추가]
            expect(
              // [OCR 추가]
              result.photoBytes, // [OCR 추가]
              orderedEquals(inputs[success ? 1 : 0]), // [OCR 추가]
            ); // [OCR 추가]
            if (inputs.length == 2) {
              // [OCR 추가]
              // [OCR 추가]
              final angle = estimateReceiptTilt([
                // [OCR 추가]
                // [OCR 추가]
                for (final line // [OCR 추가]
                    in (response()['blocks'] as List) // [OCR 추가]
                        .first['lines']) // [OCR 추가]
                  [
                    // [OCR 추가]
                    for (final point in line['points']) // [OCR 추가]
                      ui.Offset(
                        // [OCR 추가]
                        (point['x'] as int).toDouble(), // [OCR 추가]
                        (point['y'] as int).toDouble(), // [OCR 추가]
                      ), // [OCR 추가]
                  ], // [OCR 추가]
              ]); // [OCR 추가]
              final correctedFromOriginal = await prepareReceiptPhoto(
                // [OCR 추가]
                original, // [OCR 추가]
                angle: angle, // [OCR 추가]
              ); // [OCR 추가]
              expect(
                // [OCR 추가]
                inputs.last, // [OCR 추가]
                orderedEquals(correctedFromOriginal.bytes), // [OCR 추가]
              ); // [OCR 추가]
              // 이중 확대가 아니라 원본을 한번만 보간한 결과여야 한다. // [OCR 추가]
              expect(
                // [OCR 추가]
                result.numbers.map((n) => n.number), // [OCR 추가]
                success ? [3, 80940] : [2, 53960], // [OCR 추가]
              ); // [OCR 추가]
            } // [OCR 추가]
          } // [OCR 추가]
          expect(
            // [OCR 추가]
            inputs.length, // [OCR 추가]
            outcome == 'straight' || outcome == 'first-error'
                ? 1
                : 2, // [OCR 추가]
          ); // [OCR 추가]
          expect(closes, 1); // [OCR 수정] 성공·복구·첫 실패 모두 한 번 해제한다. // [OCR 추가]
          for (final temporaryPath in temporaryPaths) {
            // [OCR 추가]
            expect(
              await File(temporaryPath).parent.exists(),
              isFalse,
            ); // [OCR 추가]
          } // [OCR 추가]
          expect(
            // [OCR 추가]
            await File(path).readAsBytes(), // [OCR 추가]
            orderedEquals(original), // [OCR 추가]
          ); // [OCR 추가]
        }); // [OCR 추가]
      }, // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  const originalPath = String.fromEnvironment(
    // [OCR 추가]
    'OCR_COMPARISON_PHOTO', // [OCR 추가]
  ); // [OCR 추가]
  const linesPath = String.fromEnvironment('OCR_COMPARISON_LINES'); // [OCR 추가]
  const finalLinesPath = String.fromEnvironment(
    'OCR_COMPARISON_FINAL_LINES',
  ); // [OCR 추가]
  const outputPath = String.fromEnvironment(
    // [OCR 추가]
    'OCR_COMPARISON_OUTPUT', // [OCR 추가]
  ); // [OCR 추가]
  testWidgets('실제 사진 전처리 비교 자료 생성: 이 테스트 자체는 네이티브 OCR을 실행하지 않는다', (
    // [OCR 추가]
    tester, // [OCR 추가]
  ) async {
    // [OCR 추가]
    // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      // [OCR 추가]
      final bytes = await File(originalPath).readAsBytes(); // [OCR 추가]
      final output = await Directory(
        // [OCR 추가]
        outputPath, // [OCR 추가]
      ).create(recursive: true); // [OCR 추가]
      final first = await prepareReceiptPhoto(bytes); // [OCR 추가]
      await File(
        // [OCR 추가]
        '${output.path}/first.png', // [OCR 추가]
      ).writeAsBytes(first.bytes); // [OCR 추가]
      final lines = <List<ui.Offset>>[]; // [OCR 추가]
      if (linesPath.isNotEmpty) {
        // [OCR 추가]
        // [OCR 추가]
        for (final row in await File(linesPath).readAsLines()) {
          // [OCR 추가]
          // [OCR 추가]
          final fields = row.split('\t'); // [OCR 추가]
          if (fields.length < 3 || fields[2].isEmpty) continue; // [OCR 추가]
          lines.add([
            // [OCR 추가]
            for (final point in fields[2].split(';')) // [OCR 추가]
              ui.Offset(
                // [OCR 추가]
                double.parse(point.split(',')[0]), // [OCR 추가]
                double.parse(point.split(',')[1]), // [OCR 추가]
              ), // [OCR 추가]
          ]); // [OCR 추가]
        } // [OCR 추가]
      } // [OCR 추가]
      final angle = estimateReceiptTilt(lines); // [OCR 추가]
      final finalPhoto = await prepareReceiptPhoto(
        // [OCR 추가]
        bytes, // [OCR 추가]
        angle: angle, // [OCR 추가]
      ); // [OCR 추가]
      await File(
        // [OCR 추가]
        '${output.path}/final.png', // [OCR 추가]
      ).writeAsBytes(finalPhoto.bytes); // [OCR 추가]
      // 실제 최종 OCR 좌표로 첫 상품명과 금액만 표시한 비교 자료를 만든다. // [OCR 추가]
      if (finalLinesPath.isNotEmpty) {
        // [OCR 추가]
        final regions = <ui.Rect>[]; // [OCR 추가]
        for (final row in await File(finalLinesPath).readAsLines()) {
          // [OCR 추가]
          final fields = row.split('\t'); // [OCR 추가]
          if (!fields.first.contains('퍼실') && fields.first != '80,940') {
            // [OCR 추가]
            continue; // [OCR 추가]
          } // [OCR 추가]
          final values = fields[1]
              .substring('Rect.fromLTRB('.length, fields[1].length - 1)
              .split(',')
              .map(double.parse)
              .toList(); // [OCR 추가]
          regions.add(
            ui.Rect.fromLTRB(values[0], values[1], values[2], values[3]),
          ); // [OCR 추가]
        } // [OCR 추가]
        expect(regions, hasLength(2)); // [OCR 추가]
        final codec = await ui.instantiateImageCodec(
          finalPhoto.bytes,
        ); // [OCR 추가]
        final image = (await codec.getNextFrame()).image; // [OCR 추가]
        codec.dispose(); // [OCR 추가]
        final recorder = ui.PictureRecorder(); // [OCR 추가]
        final canvas = ui.Canvas(recorder)
          ..drawImage(image, ui.Offset.zero, ui.Paint()); // [OCR 추가]
        final paint = ui.Paint()
          ..color = const ui.Color(0xff4caf50)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1; // [OCR 추가]
        for (final region in regions) {
          // [OCR 추가]
          expect(
            region.left >= 0 &&
                region.top >= 0 &&
                region.right <= image.width &&
                region.bottom <= image.height,
            isTrue,
          ); // [OCR 추가]
          canvas.drawRect(region, paint); // [OCR 추가]
        } // [OCR 추가]
        final picture = recorder.endRecording(); // [OCR 추가]
        ui.Image? rendered; // [OCR 추가]
        try {
          // [OCR 추가]
          rendered = await picture.toImage(
            image.width,
            image.height,
          ); // [OCR 추가]
          final data = (await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          ))!; // [OCR 추가]
          await File('${output.path}/final-ocr-boxes.png').writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ); // [OCR 추가]
        } finally {
          // [OCR 추가]
          rendered?.dispose(); // [OCR 추가]
          picture.dispose(); // [OCR 추가]
          image.dispose(); // [OCR 추가]
        } // [OCR 추가]
      } // [OCR 추가]
      await File('${output.path}/preprocessing.txt').writeAsString(
        // [OCR 추가]
        'first=${first.size}\nangleDegrees=${angle * 180 / math.pi}\nfinal=${finalPhoto.size}\n', // [OCR 추가]
      ); // [OCR 추가]
      expect(
        // [OCR 추가]
        await File(originalPath).readAsBytes(), // [OCR 추가]
        orderedEquals(bytes), // [OCR 추가]
      ); // [OCR 추가]
    }); // [OCR 추가]
  }, skip: originalPath.isEmpty || outputPath.isEmpty); // [OCR 추가]
} // [OCR 추가]
