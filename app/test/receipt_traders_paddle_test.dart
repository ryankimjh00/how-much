// [OCR 추가] 저장된 Android Paddle 실제 응답 재생이다. 새 사진 재인식 시험과 구분한다.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/receipt_automatic.dart';
import 'package:how_much/ocr_service.dart';
import 'package:how_much/receipt_ocr.dart';
import 'package:how_much/receipt_text_recognizer.dart';

ReceiptOcrResult tradersSource() {
  final responses = File(
    '../docs/ocr-comparison/20261012-android/results/paddle-base-psm3.jsonl',
  ).readAsLinesSync();
  final recorded = responses
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .singleWhere((entry) => entry['id'] == 'traders-recreated');
  final tokens = [
    for (final token in recorded['tokens'])
      {
        ...token,
        'points': [
          [token['bounds'][0], token['bounds'][1]],
          [token['bounds'][2], token['bounds'][1]],
          [token['bounds'][2], token['bounds'][3]],
          [token['bounds'][0], token['bounds'][3]],
        ],
      },
  ];
  return receiptOcrFromRecognizedText(
    receiptRecognizedTextFromNative({
      'text': recorded['text'],
      'lines': [
        for (final token in tokens)
          {
            ...token,
            'elements': [token],
          },
      ],
    }),
    '/recorded-traders.png',
  );
}

ReceiptAutomaticSeed tradersSeed(ReceiptOcrResult source) =>
    ReceiptAutomaticSeed(
      product: source.products.singleWhere((item) => item.text.contains('퍼실')),
      quantity: source.numbers.singleWhere((item) => item.number == 3),
      amount: source.numbers.singleWhere((item) => item.number == 80940),
      isUnitPrice: false,
    );

void main() {
  test('트레이더스 Paddle 전체 수량 누락이 다음 상품명을 버리지 않는다', () {
    final source = tradersSource();
    final lines = automaticReceiptLines(source, tradersSeed(source));
    expect(lines.any((line) => line.title.contains('베지밀')), isTrue);
    expect(lines.any((line) => line.title.contains('스너글')), isTrue);
    expect(lines.any((line) => line.title.contains('마미손')), isTrue);
    expect(lines.first.quantity, 3);
    expect(lines.first.total, 80940);
    expect(lines.first.selected, isTrue);
    final snuggle = lines.singleWhere((line) => line.title.contains('스너글'));
    expect(
      snuggle.selected,
      isFalse,
    ); // [OCR 추가] 이름 보존은 누락 수량을 임의로 확정하는 것이 아니다.
  });

  test('수량 열도 같은 상품명 사이 누락을 종료 경계로 다시 적용하지 않는다', () async {
    final source = tradersSource();
    final crops = <Rect>[];
    final lines = await readAutomaticReceiptLines(
      source: source,
      seed: tradersSeed(source),
      photoBytes: Uint8List(0),
      photoSize: const Size(941, 1672),
      isCurrent: () => true,
      scanRegion: (_, bounds) async {
        crops.add(bounds);
        return source.numbers
            .where((item) => bounds.contains(item.bounds.center))
            .toList();
      },
      recognize: (_, bounds) async => '',
      recognizeQuantity: (_, bounds) async => '',
    );
    expect(crops, hasLength(1));
    expect(crops.single.bottom, greaterThan(1122));
    expect(lines!.any((line) => line.title.contains('마미손')), isTrue);
    expect(lines.any((line) => line.title.contains('베지밀')), isTrue);
    expect(lines.any((line) => line.title.contains('결제대상')), isFalse);
  });
}
