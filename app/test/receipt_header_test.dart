import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'receipt_ocr_test.dart' as ocr; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]

void main() {
  for (final companion in ['상품명', '단가', '금액']) {
    // [OCR 추가]
    test('수량과 $companion 두 단어만 같은 행에 있어도 머리글이다', () {
      // [OCR 추가]
      final result = ocr.resultFor([
        // [OCR 추가]
        ocr.row(['매장'], top: 0), // [OCR 추가]
        ocr.row(['수량', companion], top: 30), // [OCR 추가]
        ocr.row(['퍼실'], top: 60), // [OCR 추가]
      ]); // [OCR 추가]
      expect(receiptProductStartBelowHeader(result.rows), 50); // [OCR 추가]
      expect(result.products.map((candidate) => candidate.text), [
        '퍼실',
      ]); // [OCR 추가]
    }); // [OCR 추가]
    test('수량과 $companion 쌍이 붙은 두 행에 나뉘면 둘째 행 아래부터 찾는다', () {
      // [OCR 추가]
      final rows = [
        ocr.row([companion], top: 30),
        ocr.row(['수량'], top: 52),
      ]; // [OCR 추가]
      expect(receiptProductStartBelowHeader(rows), 72); // [OCR 추가]
      expect(
        receiptProductStartBelowHeader([
          rows.first,
          ocr.row(['수량'], top: 70),
        ]),
        isNull,
      ); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]
  test('첫 행에 수량 쌍이 있어도 바로 붙은 나머지 머리글 행까지 제외한다', () {
    // [OCR 추가]
    final rows = [
      ocr.row(['수량', '금액'], top: 30),
      ocr.row(['상품코드', '상품명', '단가'], top: 52),
    ]; // [OCR 추가]
    expect(receiptProductStartBelowHeader(rows), 72); // [OCR 추가]
  }); // [OCR 추가]
  test('수량만 또는 수량과 상품코드만 있으면 머리글로 확정하지 않는다', () {
    // [OCR 추가]
    expect(
      receiptProductStartBelowHeader([
        ocr.row(['수량'], top: 30),
      ]),
      isNull,
    ); // [OCR 추가]
    expect(
      receiptProductStartBelowHeader([
        ocr.row(['수량', '상품코드'], top: 30),
      ]),
      isNull,
    ); // [OCR 추가]
  }); // [OCR 추가]

  test('붙어 있는 두 머리글 행은 둘째 행 하단을 기준으로 삼는다', () {
    // [OCR 추가]
    final result = ocr.resultFor([
      // [OCR 추가]
      ocr.row(['매장'], top: 0), // [OCR 추가]
      ocr.row(['상품코드', '상품명'], top: 30), // [OCR 추가]
      ocr.row(['단가', '수량', '금액'], top: 52), // [OCR 추가]
      ocr.row(['퍼실'], top: 74), // [OCR 추가]
    ]); // [OCR 추가]
    expect(receiptProductStartBelowHeader(result.rows), 72); // [OCR 추가]
    expect(result.products.map((candidate) => candidate.text), [
      '퍼실',
    ]); // [OCR 추가]
  }); // [OCR 추가]

  test('떨어진 두 행이나 중간에 다른 행이 있으면 머리글을 합치지 않는다', () {
    // [OCR 추가]
    expect(
      receiptProductStartBelowHeader([
        // [OCR 추가]
        ocr.row(['상품코드', '상품명'], top: 30), // [OCR 추가]
        ocr.row(['수량'], top: 65), // [OCR 추가]
      ]),
      isNull,
    ); // [OCR 추가]
    expect(
      receiptProductStartBelowHeader([
        // [OCR 추가]
        ocr.row(['상품코드', '상품명'], top: 30), // [OCR 추가]
        ocr.row(['쿠폰 안내'], top: 52), // [OCR 추가]
        ocr.row(['수량'], top: 74), // [OCR 추가]
      ]),
      isNull,
    ); // [OCR 추가]
  }); // [OCR 추가]

  // [OCR 추가]
  test('다섯 머리글의 같은 행 하단부터 상품명 후보를 만든다', () {
    // [OCR 추가]
    final result = ocr.resultFor([
      // [OCR 추가]
      ocr.row(['트레이더스'], top: 0), // [OCR 추가]
      ocr.row(['상품코드', '상품명', '단가', '수량', '금액'], top: 30), // [OCR 추가]
      ocr.row(['퍼실', '3', '80,940'], top: 60), // [OCR 추가]
    ]); // [OCR 추가]
    expect(receiptProductStartBelowHeader(result.rows), 50); // [OCR 추가]
    expect(result.products.map((candidate) => candidate.text), [
      '퍼실',
    ]); // [OCR 추가]
    expect(result.numbers.map((candidate) => candidate.number), [
      3,
      80940,
    ]); // [OCR 추가]
    expect(result.rows.length, 3); // [OCR 추가]
    expect(result.text, contains('트레이더스')); // [OCR 추가]
  }); // [OCR 추가]

  test('열별로 나뉜 머리글과 내부 공백을 같은 사진 행으로 확인한다', () {
    // [OCR 추가]
    final rows = [
      // [OCR 추가]
      ocr.row(['상품 코드'], top: 30), ocr.row(['상품 명'], top: 32), // [OCR 추가]
      ocr.row(['단가'], top: 31),
      ocr.row(['수량'], top: 30),
      ocr.row(['금액'], top: 33), // [OCR 추가]
    ]; // [OCR 추가]
    expect(receiptProductStartBelowHeader(rows), 53); // [OCR 추가]
  }); // [OCR 추가]

  test('다른 행에 흩어지거나 수량과 짝이 없으면 기존 상품명 탐색을 유지한다', () {
    // [OCR 추가]
    final scattered = [
      for (var index = 0; index < 5; index++) // [OCR 추가]
        ocr.row([
          ['상품코드', '상품명', '단가', '수량', '금액'][index],
        ], top: index * 40.0),
    ]; // [OCR 추가]
    expect(receiptProductStartBelowHeader(scattered), isNull); // [OCR 추가]
    final partial = ocr.resultFor([
      ocr.row(['매장'], top: 0),
      ocr.row(['상품명', '단가', '금액'], top: 30),
      ocr.row(['퍼실'], top: 60),
    ]); // [OCR 추가]
    expect(receiptProductStartBelowHeader(partial.rows), isNull); // [OCR 추가]
    expect(
      partial.products.map((candidate) => candidate.text),
      containsAll(['매장', '퍼실']),
    ); // [OCR 추가]
  }); // [OCR 추가]

  test('자동 선택은 전체 OCR의 머리글 경계와 기준 상품 위 실제 상품을 유지한다', () async {
    // [OCR 추가]
    final first = fixture.name('first', '퍼실', 60); // [OCR 추가]
    final seedName = fixture.name('seed', '베지밀', 100); // [OCR 추가]
    final q1 = fixture.number('q1', 3, 60, quantity: true); // [OCR 추가]
    final p1 = fixture.number('p1', 80940, 60); // [OCR 추가]
    final q2 = fixture.number('q2', 2, 100, quantity: true); // [OCR 추가]
    final p2 = fixture.number('p2', 15000, 100); // [OCR 추가]
    final base = fixture.source(
      [fixture.name('shop', '매장', 0), first, seedName],
      [q1, p1, q2, p2],
    ); // [OCR 추가]
    final source = ReceiptOcrResult(
      text: base.text,
      photoPath: base.photoPath, // [OCR 추가]
      rows: [
        ...base.rows,
        ocr.row(['상품명', '상품코드'], top: 8), // [OCR 수정]
        ocr.row(['단가', '수량', '금액'], top: 30),
      ], // [OCR 추가]
      products: base.products,
      numbers: base.numbers,
    ); // [OCR 추가]
    final seed = ReceiptAutomaticSeed(
      product: seedName,
      quantity: q2,
      amount: p2,
      isUnitPrice: false,
    ); // [OCR 추가]
    final crops = <Rect>[]; // [OCR 추가]
    final readBounds = <Rect>[]; // [OCR 추가]
    final lines = await readAutomaticReceiptLines(
      source: source,
      seed: seed, // [OCR 추가]
      photoBytes: Uint8List(0),
      photoSize: const Size(400, 600),
      isCurrent: () => true, // [OCR 추가]
      scanRegion: (_, bounds) async {
        // [OCR 추가]
        crops.add(bounds); // [OCR 추가]
        if (crops.length == 1) {
          return [first, fixture.name('header', '상품명', 30)]; // [OCR 추가]
        } // [OCR 추가]
        if (bounds == crops[1]) {
          // [OCR 수정]
          return [q1]; // [OCR 수정] 추가 수량 열 확인에도 같은 행을 반환한다.
        } // [OCR 수정] // [OCR 추가]
        return [p1]; // [OCR 추가]
      }, // [OCR 추가]
      recognize: (_, bounds) async {
        readBounds.add(bounds);
        return bounds.center.dx < 230 ? '3' : '80940';
      },
    ); // [OCR 추가]
    expect(crops, isEmpty); // [OCR 수정] 기존 이름·숫자가 있으면 열 보완을 생략한다.
    expect(crops.every((crop) => crop.top == 50), isTrue); // [OCR 추가]
    expect(lines!.map((line) => line.title), ['퍼실', '베지밀']); // [OCR 추가]
    expect(lines.every((line) => line.selected), isTrue); // [OCR 추가]
    expect(lines.first.quantity, 3); // [OCR 추가]
    expect(readBounds.length, 0); // [OCR 수정] 전체 OCR 수량·금액을 재사용한다.
    expect(readBounds.every((bounds) => bounds.top >= 50), isTrue); // [OCR 추가]
  }); // [OCR 추가]

  test('사진을 열지 못하는 자동 후보 흐름도 머리글 위 상품명을 제외한다', () {
    // [OCR 추가]
    final first = fixture.name('first', '퍼실', 60); // [OCR 추가]
    final q = fixture.number('q', 1, 60, quantity: true); // [OCR 추가]
    final p = fixture.number('p', 5000, 60); // [OCR 추가]
    final base = fixture.source(
      [fixture.name('shop', '매장', 0), first],
      [q, p],
    ); // [OCR 추가]
    final source = ReceiptOcrResult(
      text: base.text,
      photoPath: base.photoPath, // [OCR 추가]
      rows: [
        ...base.rows,
        ocr.row(['상품명', '상품코드', '단가', '수량', '금액'], top: 30),
      ], // [OCR 추가]
      products: base.products,
      numbers: base.numbers,
    ); // [OCR 추가]
    final lines = automaticReceiptLines(
      source,
      ReceiptAutomaticSeed(
        product: first,
        quantity: q,
        amount: p,
        isUnitPrice: false,
      ),
    ); // [OCR 추가]
    expect(lines.map((line) => line.title), ['퍼실']); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
