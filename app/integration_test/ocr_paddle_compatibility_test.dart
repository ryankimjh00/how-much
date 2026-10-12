// [OCR 추가] 실제 사진으로 기본 Paddle 서비스의 전체·부분 인식과 API24 실행을 검증한다.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/ocr_service.dart';
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_text_recognizer.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('기본 Paddle 전체 영수증·영역 재인식·동시 수량 세션', (tester) async {
    expect(ReceiptTextRecognizer().engine, 'paddle');
    // [OCR 추가] 비교 채널은 동일 사진 준비에만 사용하며 인식은 기본 앱 채널로 실행한다.
    final fixtures = await ReceiptTextRecognizer.comparisonChannel
        .invokeListMethod<dynamic>('prepareCases', {'suite': 'base'});
    final cases = <String, Map<String, dynamic>>{
      for (final raw in fixtures!)
        (raw as Map)['id'] as String: Map<String, dynamic>.from(raw),
    };
    final service = OcrService();
    try {
      final whole = cases['kyobo-first-original']!;
      final file = File(whole['path'] as String);
      expect(
        sha256.convert(await file.readAsBytes()).toString(),
        whole['sha256'],
      );
      final draft = await service.recognizePath(
        file.path,
        allowManualRegions: true,
      );
      final result = draft.ocrResult!;
      expect(
        result.products.any((product) => product.text.contains('포스트')),
        isTrue,
      );
      expect(result.numbers.any((number) => number.number == 9600), isTrue);
      expect(result.photoBytes, isNotEmpty);

      // [OCR 추가] 실제 사진의 확인된 첫 이름·수량·결제금액으로 자동 선택 후 검토 초안까지 확인한다.
      final firstProduct = result.products.firstWhere(
        (product) => product.text.contains('포스트'),
      );
      final amounts =
          result.numbers.where((number) => number.number == 9600).toList()
            ..sort(
              (left, right) => left.bounds.right.compareTo(right.bounds.right),
            );
      final firstAmount = amounts.last;
      final quantities =
          result.numbers.where((number) => number.number == 1).toList()..sort(
            (left, right) =>
                (left.bounds.center.dy - firstAmount.bounds.center.dy)
                    .abs()
                    .compareTo(
                      (right.bounds.center.dy - firstAmount.bounds.center.dy)
                          .abs(),
                    ),
          );
      final firstQuantity = quantities.first;
      final photoCodec = await instantiateImageCodec(result.photoBytes!);
      final photo = (await photoCodec.getNextFrame()).image;
      final size = Size(photo.width.toDouble(), photo.height.toDouble());
      photo.dispose();
      photoCodec.dispose();
      final automatic = await service.withReceiptRegionSession(
        result.photoBytes!,
        (session) {
          return readAutomaticReceiptLines(
            source: result,
            seed: ReceiptAutomaticSeed(
              product: firstProduct,
              quantity: firstQuantity,
              amount: firstAmount,
              isUnitPrice: false,
            ),
            photoBytes: result.photoBytes!,
            photoSize: size,
            isCurrent: () => true,
            recognize: (_, bounds) => session.recognizeRegion(bounds),
            recognizeQuantity: (_, bounds) =>
                session.quantitySession!.recognizeQuantityRegion(
                  bounds,
                  horizontalContext:
                      (firstAmount.bounds.right - firstQuantity.bounds.right)
                          .abs(),
                ),
            scanRegion: (_, bounds) => session.recognizeRegionRows(bounds),
          );
        },
        parallelQuantity: true,
      );
      final firstReviewLine = automatic!.singleWhere(
        (line) => line.ocrProduct!.id == firstProduct.id,
      );
      expect(firstReviewLine.title, firstProduct.text);
      expect(firstReviewLine.quantity, 1);
      expect(firstReviewLine.total, 9600);
      expect(firstReviewLine.selected, isTrue);
      // ignore: avoid_print
      print(
        'PADDLE_FIRST_REVIEW ${jsonEncode({'title': firstReviewLine.title, 'quantity': firstReviewLine.quantity, 'total': firstReviewLine.total, 'checked': firstReviewLine.selected, 'review_items': automatic.length})}',
      );

      final quantity = cases['kyobo-first-original-quantity-01']!;
      final bytes = await File(quantity['path'] as String).readAsBytes();
      expect(sha256.convert(bytes).toString(), quantity['sha256']);
      // [OCR 추가] 단독 영역과 파일·인식기 재사용 세션이 모두 같은 수량을 읽어야 한다.
      const bounds = Rect.fromLTWH(0, 0, 150, 150);
      final value = await service.recognizeRegion(bytes, bounds);
      expect(value.trim(), '1');
      final values = await service.withReceiptRegionSession(bytes, (session) {
        return Future.wait([
          session.recognizeRegion(bounds),
          session.quantitySession!.recognizeRegion(bounds),
        ]);
      }, parallelQuantity: true);
      expect(values.map((text) => text.trim()).toList(), ['1', '1']);
      // [OCR 추가] 실제 서비스 결과이며 모의 응답 테스트와 구분하여 기록한다.
      // ignore: avoid_print
      print(
        'PADDLE_APP_SERVICE ${jsonEncode({'whole_products': result.products.length, 'whole_numbers': result.numbers.length, 'quantity': value, 'session_values': values})}',
      );
    } finally {
      await ReceiptTextRecognizer.comparisonChannel.invokeMethod<void>(
        'clearCases',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
