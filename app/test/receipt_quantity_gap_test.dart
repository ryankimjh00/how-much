import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_column_scan.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]
import 'receipt_automatic_retry_test.dart' show seedFor; // [OCR 추가]

ReceiptOcrCandidate quantity(double top) =>
    fixture.number('q-$top', 1, top, quantity: true); // [OCR 추가]

void main() {
  test('수량 행 사이가 정상 간격3배 이상 끊기면 직전 행까지 읽는다', () {
    expect(
      receiptQuantityGapEnd([
        for (final top in [10.0, 50.0, 90.0, 250.0, 290.0]) quantity(top),
      ], 320),
      120,
    ); // [OCR 추가]
  });
  // [OCR 추가] 알려진 상품명은 수량 OCR 누락을 설명한다. 실제 공백의 종료 규칙은 유지한다.
  test('수량 공백 안에 상품명 행이 있으면 뒤 상품을 버리지 않는다', () {
    final rows = [
      for (final top in [10.0, 50.0, 90.0, 250.0, 290.0]) quantity(top),
    ];
    expect(
      receiptQuantityGapEnd(
        rows,
        320,
        productRows: [fixture.name('missing', '수량 누락 상품', 170).bounds],
      ),
      isNull,
    );
    expect(
      receiptQuantityGapEnd(
        rows,
        320,
        productRows: [fixture.name('before-gap', '기존 상품', 90).bounds],
      ),
      120,
    );
  });
  test('마지막 수량 아래 상품명이 남아 있으면 사진 끝 공백을 확정하지 않는다', () {
    final rows = [quantity(10), quantity(50), quantity(90)];
    expect(
      receiptQuantityGapEnd(
        rows,
        600,
        productRows: [fixture.name('last', '마지막 수량 누락', 130).bounds],
      ),
      isNull,
    );
  });
  test('두 행 간격이나 마지막 수량 아래 짧은 여백은 끊김으로 확정하지 않는다', () {
    expect(
      receiptQuantityGapEnd([
        for (final top in [10.0, 50.0, 90.0, 170.0]) quantity(top),
      ], 200),
      isNull,
    ); // [OCR 추가]
    expect(
      receiptQuantityGapEnd([quantity(10), quantity(50)], 600),
      isNull,
    ); // [OCR 추가]
  });
  test('마지막 수량 아래 세 행이 비면 멈추고 사진 높이가 없으면 추측하지 않는다', () {
    final rows = [quantity(10), quantity(50), quantity(90)]; // [OCR 추가]
    expect(receiptQuantityGapEnd(rows, 600), 120); // [OCR 추가]
    expect(receiptQuantityGapEnd(rows, 140), isNull); // [OCR 추가]
    expect(receiptQuantityGapEnd(rows, double.infinity), isNull); // [OCR 추가]
  });
  test('중복 박스와 글자·할인·금액은 수량 행 간격에 섞지 않는다', () {
    final rows = [
      quantity(10),
      quantity(10),
      quantity(50),
      quantity(90),
      quantity(250),
      const ReceiptOcrCandidate(
        id: 'capacity',
        text: '1L',
        bounds: Rect.fromLTRB(180, 130, 200, 150),
      ),
      fixture.number('discount', -15000, 170, quantity: true),
      fixture.number('amount', 3500, 210, quantity: true),
    ]; // [OCR 추가]
    expect(receiptQuantityGapEnd(rows, 400), 120); // [OCR 추가]
  });
  for (final missingQuantity in [false, true]) {
    test('전체·열 수량으로 종료 위치를 반영하고 하단 후보 재인식을 생략한다: $missingQuantity', () async {
      // [OCR 추가] 모의 열 응답이며 실제 사진 인식 결과와 구분한다.
      final names = [
        fixture.name('first', '퍼실', 10),
        fixture.name('second', '베지밀', 50),
        fixture.name('third', '락스', 90),
        fixture.name('footer', '안내조각', 250),
      ]; // [OCR 추가]
      final source = fixture.source(names, [
        quantity(10),
        fixture.number('p1', 9000, 10),
        quantity(50),
        fixture.number('p2', 8000, 50),
        if (!missingQuantity) quantity(90),
        fixture.number('p3', 7000, 90),
      ]); // [OCR 추가]
      final crops = <Rect>[]; // [OCR 추가]
      var partials = 0; // [OCR 추가]
      ReceiptOcrResult? accumulated; // [OCR 추가]
      final lines = await readAutomaticReceiptLines(
        source: source,
        seed: seedFor(source),
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => true,
        scanRegion: (_, bounds) async {
          crops.add(bounds);
          return bounds.center.dx < 170
              ? names
              : [quantity(10), quantity(50), quantity(90), quantity(250)];
        },
        recognize: (_, _) async {
          partials++;
          return '';
        },
        onCandidates: (result) => accumulated = result,
      );
      expect(lines!.map((line) => line.title), ['퍼실', '베지밀', '락스']); // [OCR 추가]
      expect(lines.every((line) => line.selected), isTrue); // [OCR 추가]
      expect(partials, 0); // [OCR 추가]
      expect(crops, hasLength(missingQuantity ? 1 : 0)); // [OCR 추가]
      if (missingQuantity) {
        expect(crops.single.bottom, 600); // [OCR 수정] 이후 수량 응답의 공백 경계를 적용한다.
      }
      expect(
        accumulated!.products.any((name) => name.id == 'footer'),
        isTrue,
      ); // [OCR 추가] 자동 범위 밖이어도 원본 후보는 버리지 않는다.
      expect(source.products, hasLength(4)); // [OCR 추가]
    });
  }
}
