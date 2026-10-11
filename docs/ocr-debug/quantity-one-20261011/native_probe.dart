import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:how_much/receipt_image.dart';
import 'package:how_much/ocr_service.dart';
import 'package:how_much/receipt_perspective.dart';

// [OCR 추가] 실제 에뮬레이터 ML Kit 비교용이다. 앱 저장소·계정은 열지 않는다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('실사진 수량1의 한국어·라틴/부분·행 OCR 비교', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('수량 OCR 비교 중'))),
    );
    final directory = await Directory.systemTemp.createTemp('quantity-probe-');
    final recognizers = {
      'korean': TextRecognizer(script: TextRecognitionScript.korean),
      'latin': TextRecognizer(script: TextRecognitionScript.latin),
    };
    final results = <Map<String, dynamic>>[];
    Future<void> compare(
      String name,
      Uint8List photo,
      ui.Rect quantity,
      ui.Rect row,
    ) async {
      final production = await OcrService().withReceiptRegionSession(
        photo,
        (session) => session.recognizeQuantityRegion(
          quantity,
          horizontalContext: row.right - quantity.right,
        ),
      );
      debugPrint(
        'QUANTITY_PRODUCTION ${jsonEncode({'name': name, 'value': production, 'success': production == '1'})}',
      );
      for (final scope in {'quantity': quantity, 'row': row}.entries) {
        final cropped = await cropReceiptRegion(photo, scope.value);
        final path = '${directory.path}/crop.png';
        await File(path).writeAsBytes(cropped, flush: true);
        for (final model in recognizers.entries) {
          final timer = Stopwatch()..start();
          final recognized = await model.value.processImage(
            InputImage.fromFilePath(path),
          );
          final tokens = [
            for (final block in recognized.blocks)
              for (final line in block.lines)
                for (final word in line.elements)
                  {
                    'text': word.text,
                    'bounds': [
                      word.boundingBox.left + scope.value.left.floor(),
                      word.boundingBox.top + scope.value.top.floor(),
                      word.boundingBox.right + scope.value.left.floor(),
                      word.boundingBox.bottom + scope.value.top.floor(),
                    ],
                    'confidence': word.confidence,
                  },
          ];
          final hits = tokens.where((word) {
            final bounds = word['bounds'] as List<double>;
            final center = ui.Offset(
              (bounds[0] + bounds[2]) / 2,
              (bounds[1] + bounds[3]) / 2,
            );
            return quantity.contains(center) && word['text'] == '1';
          }).toList();
          final result = {
            'name': name,
            'scope': scope.key,
            'model': model.key,
            'quantity': [
              quantity.left,
              quantity.top,
              quantity.right,
              quantity.bottom,
            ],
            'crop': [
              scope.value.left,
              scope.value.top,
              scope.value.right,
              scope.value.bottom,
            ],
            'text': recognized.text,
            'tokens': tokens,
            'success': hits.length == 1,
            'milliseconds': timer.elapsedMilliseconds,
          };
          results.add(result);
          // [OCR 추가] 원문·위치만 시험 로그에 남기며 사용자 계정·인증 정보는 접근하지 않는다.
          debugPrint('QUANTITY_PROBE ${jsonEncode(result)}');
        }
      }
    }

    try {
      final kyobo = (await rootBundle.load(
        'integration_test/quantity_probe_fixtures/kyobo-second.jpg',
      )).buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(kyobo);
      final image = (await codec.getNextFrame()).image;
      final sx = image.width / 1368;
      final sy = image.height / 1824;
      image.dispose();
      codec.dispose();
      const positions = [
        (817.0, 87.0),
        (817.0, 185.0),
        (819.0, 282.0),
        (822.0, 379.0),
        (824.0, 476.0),
        (827.0, 576.0),
        (831.0, 676.0),
        (834.0, 771.0),
        (837.0, 870.0),
        (838.0, 969.0),
        (840.0, 1064.0),
      ];
      for (final (index, position) in positions.indexed) {
        await compare(
          'kyobo-original-$index',
          kyobo,
          ui.Rect.fromLTRB(
            (position.$1 - 28) * sx,
            (position.$2 - 26) * sy,
            (position.$1 + 28) * sx,
            (position.$2 + 26) * sy,
          ),
          ui.Rect.fromLTRB(
            620 * sx,
            (position.$2 - 26) * sy,
            1080 * sx,
            (position.$2 + 26) * sy,
          ),
        );
      }
      // [OCR 추가] 사용자에게 보였던 실제 보정 모서리를 재현한 것이 아닌 별도 수동 기준 보정이다.
      final corners = [
        ui.Offset(163 * sx, 0),
        ui.Offset(1157 * sx, 0),
        ui.Offset(1175 * sx, 1090 * sy),
        ui.Offset(194 * sx, 1120 * sy),
      ];
      final corrected = await correctReceiptPerspective(kyobo, corners);
      await File('${Directory.systemTemp.path}/quantity-probe-corrected.png')
          .writeAsBytes(corrected);
      final correctedFile = File('${directory.path}/corrected.png');
      await correctedFile.writeAsBytes(corrected);
      final whole = await recognizers['korean']!.processImage(
        InputImage.fromFilePath(correctedFile.path),
      );
      final qWords = [
        for (final block in whole.blocks)
          for (final line in block.lines)
            for (final word in line.elements)
              if (word.text == '1') word,
      ];
      debugPrint(
        'QUANTITY_PROBE_CORRECTED ${jsonEncode({
          'text': whole.text,
          'ones': [
            for (final word in qWords) [word.boundingBox.left, word.boundingBox.top, word.boundingBox.right, word.boundingBox.bottom],
          ],
        })}',
      );
      const correctedYs = [
        193.0,
        406.0,
        622.0,
        837.0,
        1063.0,
        1280.0,
        1499.0,
        1720.0,
        1937.0,
        2151.0,
        2373.0,
      ];
      for (final (index, y) in correctedYs.indexed) {
        final x = 1405.0;
        await compare(
          'kyobo-corrected-$index',
          corrected,
          ui.Rect.fromLTRB(x - 55, y - 55, x + 55, y + 55),
          ui.Rect.fromLTRB(1000, y - 55, 1970, y + 55),
        );
      }
      final pepsi = (await rootBundle.load(
        'integration_test/quantity_probe_fixtures/pepsi-row.png',
      )).buffer.asUint8List();
      await compare(
        'pepsi',
        pepsi,
        const ui.Rect.fromLTRB(450, 0, 530, 64),
        const ui.Rect.fromLTRB(0, 0, 1362, 64),
      );
      await File('${Directory.systemTemp.path}/quantity-probe-results.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      expect(results, hasLength(92));
    } finally {
      for (final recognizer in recognizers.values) {
        await recognizer.close();
      }
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
