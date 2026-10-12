import 'package:how_much/receipt_column_scan.dart'; // [OCR 추가]
import 'dart:async'; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_selection_screen.dart'; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto, loadRegion; // [OCR 추가]

// [OCR 추가] 위치별 모의 응답으로 실제 ML Kit 품질과 재시도/행 연결의 제어 흐름을 분리한다.
ReceiptOcrResult missingQuantitySource({bool missingAmount = false}) =>
    fixture.source(
      // [OCR 추가]
      [
        fixture.name('first', '퍼실', 10),
        fixture.name('snuggle', '스너글', 50), // [OCR 추가]
        fixture.name('brush', '칫솔', 90), fixture.name('point', '포인트카드', 130),
      ], // [OCR 추가]
      [
        fixture.number('q1', 3, 10, quantity: true),
        fixture.number('p1', 80940, 10), // [OCR 추가]
        if (!missingAmount) fixture.number('p2', 37960, 50), // [OCR 추가]
        fixture.number('q3', 1, 90, quantity: true),
        fixture.number('p3', 12980, 90), // [OCR 추가]
        fixture.number('discount', -15000, 130),
      ], // [OCR 추가]
    ); // [OCR 추가]

ReceiptAutomaticSeed seedFor(ReceiptOcrResult source, {bool unit = false}) =>
    ReceiptAutomaticSeed(
      // [OCR 추가]
      product: source.products.first,
      quantity: source.numbers.first, // [OCR 추가]
      amount: source.numbers[1],
      isUnitPrice: unit,
      includeQuantity: true, // [OCR 추가]
    ); // [OCR 추가]

Future<List<ReceiptLineDraft>?> read(
  ReceiptOcrResult source, // [OCR 추가]
  Future<String> Function(Uint8List, Rect) recognize, { // [OCR 추가]
  bool Function()? isCurrent,
  bool unit = false, // [OCR 추가]
}) => readAutomaticReceiptLines(
  // [OCR 추가]
  source: source,
  seed: seedFor(source, unit: unit), // [OCR 추가]
  photoBytes: Uint8List.fromList([1]),
  photoSize: const Size(400, 600), // [OCR 추가]
  recognize: recognize,
  isCurrent: isCurrent ?? () => true, // [OCR 추가]
); // [OCR 추가]

void main() {
  test('주변 후보를 없애거나 첫 숫자 행에 잘못 추가해도 사람의 첫 상품은 독립적으로 확정한다', () {
    final product = fixture.name('human-product', '카드케이스', 10);
    final quantity = fixture.number('human-quantity', 3, 70, quantity: true);
    final amount = fixture.number('human-amount', 80940, 70);
    final seed = ReceiptAutomaticSeed(
      product: product,
      quantity: quantity,
      amount: amount,
      isUnitPrice: false,
    );
    for (final surrounding in <List<ReceiptOcrCandidate>>[
      [],
      [fixture.name('false-next', '다른 상품으로 잘못 읽힌 후보', 50)],
      [fixture.name('same-row', '같은 금액에 겹친 후보', 10)],
    ]) {
      final lines = automaticReceiptLines(
        fixture.source(surrounding, [quantity, amount]),
        seed,
      );
      final human = lines.singleWhere(
        (line) => line.ocrProduct!.id == product.id,
      );
      expect(human.title, '카드케이스');
      expect(human.quantity, 3);
      expect(human.total, 80940);
      expect(human.selected, isTrue);
      expect(human.ocrNotice, isEmpty);
      expect(human.ocrQuantity, same(quantity));
      expect(human.ocrAmount, same(amount));
    }
  }); // [OCR 추가] 다른 후보의 행·구매 안내 판정·중복 금액이 첫 상품에 영향을 주지 못한다.

  for (final boundary in ['header', 'end']) {
    test('확정한 첫 품목은 자동 $boundary 경계 밖이어도 이름·수량·금액을 유지한다', () {
      final first = fixture.name('seed', '원래 이름', 60);
      final selected = ReceiptOcrCandidate(
        id: first.id,
        text: '수정한 첫 품목',
        bounds: first.bounds,
      );
      final quantity = fixture.number('q1', 3, 60, quantity: true);
      final amount = fixture.number('p1', 80940, 60);
      final base = fixture.source(
        [first, fixture.name('next', '베지밀', 140)],
        [quantity, amount],
      );
      final data = ReceiptOcrResult(
        text: base.text,
        photoPath: base.photoPath,
        products: base.products,
        numbers: base.numbers,
        rows: [
          ...base.rows,
          ReceiptOcrRow(
            id: 'header',
            text: '단가 수량',
            bounds: const Rect.fromLTWH(10, 90, 330, 20),
            tokens: const [],
          ),
        ],
      );
      final lines = automaticReceiptLines(
        data,
        ReceiptAutomaticSeed(
          product: selected,
          quantity: quantity,
          amount: amount,
          isUnitPrice: false,
        ),
        endBefore: boundary == 'end' ? 50 : null,
      );
      final seedLine = lines.singleWhere(
        (line) => line.ocrProduct!.id == selected.id,
      );
      expect(seedLine.title, '수정한 첫 품목');
      expect(seedLine.quantity, 3);
      expect(seedLine.total, 80940);
      expect(seedLine.selected, isTrue);
      expect(seedLine.ocrProduct, same(selected));
      expect(seedLine.ocrQuantity, same(quantity));
      expect(seedLine.ocrAmount, same(amount));
    }); // [OCR 추가] OCR 경계 추정으로 사람이 확인한 기준 항목을 버리는 실패를 재현한다.
  }

  test('첫 품목이 상품명 행의 오른쪽 조각이면 병합 후에도 확정 항목 하나를 유지한다', () async {
    final left = ReceiptOcrCandidate(
      id: 'left-piece',
      text: '앞 조각',
      bounds: const Rect.fromLTWH(10, 10, 20, 20),
    );
    final seedName = ReceiptOcrCandidate(
      id: 'seed-piece',
      text: '확정한 상품명',
      bounds: const Rect.fromLTWH(25, 10, 90, 20),
    );
    final quantity = fixture.number('q1', 3, 40, quantity: true);
    final amount = fixture.number('p1', 80940, 40);
    final base = fixture.source([left, seedName], [quantity, amount]);
    final data = ReceiptOcrResult(
      text: base.text,
      photoPath: base.photoPath,
      products: base.products,
      numbers: base.numbers,
      rows: [
        ...base.rows,
        ReceiptOcrRow(
          id: 'whole-name-row',
          text: '앞 조각 확정한 상품명',
          bounds: const Rect.fromLTWH(10, 10, 105, 20),
          tokens: [
            for (final name in [left, seedName])
              ReceiptOcrToken(
                id: name.id,
                text: name.text,
                bounds: name.bounds,
              ),
          ],
        ),
      ],
    );
    var reads = 0;
    final lines = await readAutomaticReceiptLines(
      source: data,
      seed: ReceiptAutomaticSeed(
        product: seedName,
        quantity: quantity,
        amount: amount,
        isUnitPrice: false,
      ),
      photoBytes: Uint8List(0),
      photoSize: const Size(400, 600),
      isCurrent: () => true,
      recognize: (_, _) async {
        reads++;
        return '잘못된 재인식';
      },
    );
    expect(lines, hasLength(1));
    expect(lines!.single.title, '확정한 상품명');
    expect(lines.single.ocrProduct, same(seedName));
    expect(lines.single.quantity, 3);
    expect(lines.single.total, 80940);
    expect(lines.single.selected, isTrue);
    expect(reads, 0);
  }); // [OCR 추가] 병합 앵커가 바뀌어 첫 ID를 잃고 숫자를 다시 찾는 회귀를 확인한다.

  for (final cancelled in [false, true]) {
    test('별도 작업자의 수량·금액은 동시 시작하고 각 첫 성공에서 종료한다: $cancelled', () async {
      // [OCR 추가] 두 모의 호출을 동시에 대기시켜 병렬 실행과 취소 결과 유실 방지를 검사한다.
      final source = fixture.source(
        [fixture.name('first', '퍼실', 10), fixture.name('second', '베지밀', 50)],
        [
          fixture.number('q1', 3, 10, quantity: true),
          fixture.number('p1', 80940, 10),
        ],
      );
      final amountStarted = Completer<void>();
      final quantityStarted = Completer<void>();
      final release = Completer<void>();
      var current = true;
      var amounts = 0;
      var quantities = 0;
      final work = readAutomaticReceiptLines(
        source: source,
        seed: seedFor(source),
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => current,
        recognize: (_, bounds) async {
          amounts++;
          if (amounts == 1) amountStarted.complete();
          await release.future;
          return '15000';
        },
        recognizeQuantity: (_, bounds) async {
          quantities++;
          if (quantities == 1) quantityStarted.complete();
          await release.future;
          return '2';
        },
      ); // [OCR 추가]
      try {
        await Future.wait([
          amountStarted.future,
          quantityStarted.future,
        ]).timeout(const Duration(seconds: 2));
        expect(amounts, 1);
        expect(quantities, 1);
        if (cancelled) current = false;
      } finally {
        release.complete(); // [OCR 추가] 검사 실패 시에도 대기한 두 호출을 해제한다.
      }
      final result = await work;
      if (cancelled) {
        expect(result, isNull);
        expect(amounts, 1);
        expect(quantities, 1);
      } else {
        expect(amounts, 1);
        expect(quantities, 1);
        expect(result![1].selected, isTrue);
        expect(result[1].quantity, 2);
        expect(result[1].total, 15000);
      }
    }); // [OCR 추가]
  }

  // [OCR 추가]
  for (final missingAmount in [false, true]) {
    // [OCR 추가]
    test(
      '자동 영역 반복은 누락된 수량${missingAmount ? '·금액' : ''}을 복구하고 각 영역 첫 성공 직후 멈춘다',
      () async {
        // [OCR 추가]
        final source = missingQuantitySource(
          missingAmount: missingAmount,
        ); // [OCR 추가]
        final calls = <Rect>[]; // [OCR 추가]
        final lines = (await read(source, (_, bounds) async {
          // [OCR 추가]
          calls.add(bounds); // [OCR 추가]
          final quantity = bounds.center.dx < 230; // [OCR 추가]
          if (bounds.center.dy < 80) {
            // [OCR 추가]
            return quantity ? '2' : '37,960원'; // [OCR 추가]
          } // [OCR 추가]
          return quantity ? '1' : '12,980원'; // [OCR 추가]
        }))!; // [OCR 추가]
        expect(calls.length, missingAmount ? 2 : 1); // [OCR 추가]
        expect(lines.map((line) => line.quantity), [3, 2, 1, 0]); // [OCR 추가]
        expect(lines.map((line) => line.total), [
          80940,
          37960,
          12980,
          0,
        ]); // [OCR 추가]
        expect(lines[1].selected, isTrue); // [OCR 추가]
        expect(lines[1].unitPrice, 18980); // [OCR 추가]
        expect(lines[3].selected, isFalse); // [OCR 추가]
        expect(
          lines[1].ocrQuantity!.bounds,
          calls[missingAmount ? 1 : 0],
        ); // [OCR 추가]
        if (missingAmount) {
          expect(lines[1].ocrAmount!.bounds, calls[0]);
        } else {
          expect(
            lines[1].ocrAmount!.bounds.center,
            source.numbers
                .firstWhere((number) => number.id == 'p2')
                .bounds
                .center,
          );
        } // [OCR 수정] 기존 금액은 위치와 값을 재사용한다. // [OCR 추가]
        expect(lines.first.ocrAmount!.id, 'p1'); // [OCR 추가]
        expect(
          source.numbers.any((candidate) => candidate.number == 2),
          isFalse,
        ); // [OCR 추가]
        for (final bounds in calls.take(2)) {
          // [OCR 추가]
          expect(bounds.top, greaterThanOrEqualTo(40)); // [OCR 추가]
          expect(bounds.bottom, lessThanOrEqualTo(80)); // [OCR 추가]
        } // [OCR 추가]
      },
    ); // [OCR 추가]
  } // [OCR 추가]

  test('금액 폭이 달라도 우측 끝을 기준으로 누락된 수량 열을 다시 읽는다', () async {
    // [OCR 추가]
    final original = missingQuantitySource(); // [OCR 추가]
    final source = fixture.source(original.products, [
      // [OCR 추가]
      for (final candidate in original.numbers) // [OCR 추가]
        if (candidate.id == 'p2')
          ReceiptOcrCandidate(
            // [OCR 추가]
            id: candidate.id,
            text: candidate.text,
            number: candidate.number, // [OCR 추가]
            bounds: const Rect.fromLTWH(290, 50, 50, 20), // [OCR 추가]
          )
        else
          candidate, // [OCR 추가]
    ]); // [OCR 추가]
    var quantityCalls = 0; // [OCR 추가]
    final lines = (await read(source, (_, bounds) async {
      // [OCR 추가]
      if (bounds.center.dy < 80 && bounds.center.dx < 230) {
        // [OCR 추가]
        quantityCalls++; // [OCR 추가]
        expect(bounds.center.dx, closeTo(190, 1)); // [OCR 추가]
        return '2'; // [OCR 추가]
      } // [OCR 추가]
      return bounds.center.dx < 230 ? '1' : '37960'; // [OCR 추가]
    }))!; // [OCR 추가]
    expect(quantityCalls, 1); // [OCR 추가]
    expect(lines[1].quantity, 2); // [OCR 추가]
    expect(lines[1].selected, isTrue); // [OCR 추가]
  }); // [OCR 추가]

  test('수량 5회 실패는 다음 칫솔의 1을 가져오지 않고 다음 상품 인식을 계속한다', () async {
    // [OCR 추가]
    var quantityFailures = 0; // [OCR 추가]
    final lines = (await read(missingQuantitySource(), (_, bounds) async {
      // [OCR 추가]
      if (bounds.center.dy < 80) {
        // [OCR 추가]
        if (bounds.center.dx < 230) {
          // [OCR 추가]
          quantityFailures++; // [OCR 추가]
          expect(bounds.bottom, lessThanOrEqualTo(80)); // [OCR 추가]
          return ''; // [OCR 추가] 바로 아래 칫솔의 1은 영역 밖에 있다.
        } // [OCR 추가]
        return '37960'; // [OCR 추가]
      } // [OCR 추가]
      return bounds.center.dx < 230 ? '1' : '12980'; // [OCR 추가]
    }))!; // [OCR 추가]
    expect(quantityFailures, 5); // [OCR 추가]
    expect(lines[1].quantity, 0); // [OCR 추가]
    expect(lines[1].ocrQuantity, isNull); // [OCR 추가]
    expect(lines[1].selected, isFalse); // [OCR 추가]
    expect(lines[1].total, 37960); // [OCR 추가]
    expect(lines[2].quantity, 1); // [OCR 추가]
    expect(lines[2].selected, isTrue); // [OCR 추가]
  }); // [OCR 추가]

  test('자동 재인식 실패 시 기존 숫자를 새 결과로 복구하지 않는다', () async {
    // [OCR 추가]
    var amountFailures = 0; // [OCR 추가]
    final original = missingQuantitySource(); // [OCR 수정]
    final source = fixture.source(original.products, [
      for (final number in original.numbers)
        if (number.id == 'p2')
          ReceiptOcrCandidate(
            id: number.id,
            text: number.text,
            number: number.number,
            bounds: number.bounds.shift(const Offset(-200, 0)),
          )
        else
          number,
    ]); // [OCR 수정] 다른 열의 옛 숫자는 현재 금액으로 연결하지 않는다. // [OCR 추가]
    final lines = (await read(source, (_, bounds) async {
      // [OCR 추가]
      if (bounds.center.dy < 80 && bounds.center.dx > 230) {
        // [OCR 추가]
        amountFailures++; // [OCR 추가]
        throw StateError('부분 인식 실패'); // [OCR 추가]
      } // [OCR 추가]
      if (bounds.center.dx < 230) return '2'; // [OCR 추가]
      return '12980'; // [OCR 추가]
    }))!; // [OCR 추가]
    expect(amountFailures, 5); // [OCR 추가]
    expect(lines[1].total, 0); // [OCR 추가]
    expect(lines[1].ocrAmount, isNull); // [OCR 추가]
    expect(lines[1].ocrInputAmount, isNull); // [OCR 추가]
    expect(lines[1].selected, isFalse); // [OCR 추가]
    expect(
      source.numbers.firstWhere((number) => number.id == 'p2').number,
      37960,
    ); // [OCR 추가]
  }); // [OCR 추가]

  test('유효 수량만 성공으로 세고 단가는 읽힌 수량과 곱해 개당 가격을 유지한다', () async {
    // [OCR 추가]
    var quantityCalls = 0; // [OCR 추가]
    final lines = (await read(missingQuantitySource(missingAmount: true), (
      _,
      bounds,
    ) async {
      // [OCR 추가]
      if (bounds.center.dy < 80 && bounds.center.dx < 230) {
        // [OCR 추가]
        quantityCalls++; // [OCR 추가]
        if (quantityCalls == 1) return '0'; // [OCR 추가]
        if (quantityCalls == 2) return '1000'; // [OCR 추가]
        if (quantityCalls == 3) return '1L'; // [OCR 추가]
        return '2'; // [OCR 추가]
      } // [OCR 추가]
      return bounds.center.dx < 230 ? '1' : '1000'; // [OCR 추가]
    }, unit: true))!; // [OCR 추가]
    expect(quantityCalls, 4); // [OCR 추가]
    expect(lines[1].quantity, 2); // [OCR 추가]
    expect(lines[1].total, 2000); // [OCR 추가]
    expect(lines[1].unitPrice, 1000); // [OCR 추가]
    expect(lines[1].selected, isTrue); // [OCR 추가]
  }); // [OCR 추가]

  test('첫 성공 뒤 다른 결과를 읽지 않고 확정한다', () async {
    // [OCR 추가]
    var quantityCalls = 0; // [OCR 추가]
    final lines = (await read(missingQuantitySource(), (_, bounds) async {
      // [OCR 추가]
      if (bounds.center.dy < 80 && bounds.center.dx < 230) {
        // [OCR 추가]
        return '${++quantityCalls}'; // [OCR 추가]
      } // [OCR 추가]
      return bounds.center.dx < 230 ? '1' : '12980'; // [OCR 추가]
    }))!; // [OCR 추가]
    expect(quantityCalls, 1); // [OCR 추가]
    expect(lines[1].selected, isTrue); // [OCR 추가]
    expect(lines[1].quantity, 1); // [OCR 수정] 첫 성공값으로 확정한다. // [OCR 추가]
  }); // [OCR 추가]

  test('한 번 읽히면 즉시 확정하고 나머지 시도는 하지 않는다', () async {
    // [OCR 추가]
    var quantityCalls = 0; // [OCR 추가]
    final lines = (await read(missingQuantitySource(), (_, bounds) async {
      // [OCR 추가]
      if (bounds.center.dy < 80 && bounds.center.dx < 230) {
        // [OCR 추가]
        quantityCalls++; // [OCR 추가]
        return quantityCalls <= 2 ? '2' : ''; // [OCR 추가]
      } // [OCR 추가]
      return bounds.center.dx < 230 ? '1' : '12980'; // [OCR 추가]
    }))!; // [OCR 추가]
    expect(quantityCalls, 1); // [OCR 추가]
    expect(lines[1].quantity, 2); // [OCR 추가]
    expect(lines[1].selected, isTrue); // [OCR 추가]
  }); // [OCR 추가]

  test('자동 선택 취소 중 늦은 응답은 반영하지 않고 다음 영역 호출도 중단한다', () async {
    // [OCR 추가]
    final pending = Completer<String>(); // [OCR 추가]
    var current = true; // [OCR 추가]
    var calls = 0; // [OCR 추가]
    final work = read(missingQuantitySource(missingAmount: true), (_, _) {
      calls++;
      return pending.future;
    }, isCurrent: () => current); // [OCR 추가]
    expect(calls, 1); // [OCR 추가]
    current = false; // [OCR 추가]
    pending.complete('37960'); // [OCR 추가]
    expect(await work, isNull); // [OCR 추가]
    expect(calls, 1); // [OCR 추가]
  }); // [OCR 추가]

  test('진행 박스 좌표는 미세 조정/행 경계 제한 후 실제 인식에 전달한 영역과 같다', () async {
    // [OCR 추가]
    final source = missingQuantitySource(); // [OCR 추가]
    final shown = <Rect>[]; // [OCR 추가]
    final readBounds = <Rect>[]; // [OCR 추가]
    final fields = <String>[]; // [OCR 추가]
    await readAutomaticReceiptLines(
      // [OCR 추가]
      source: source,
      seed: seedFor(source),
      photoBytes: Uint8List.fromList([1]), // [OCR 추가]
      photoSize: const Size(400, 600),
      isCurrent: () => true, // [OCR 추가]
      onProgress: (item, total, field, attempts, successes, bounds) {
        // [OCR 추가]
        if (field == '상품명 확인') return; // [OCR 추가] 상품명 표시는 숫자 인식 호출이 아니다.
        shown.add(bounds); // [OCR 추가]
        fields.add(field); // [OCR 추가]
      }, // [OCR 추가]
      recognize: (_, bounds) async {
        // [OCR 추가]
        readBounds.add(bounds); // [OCR 추가]
        if (bounds.center.dy < 80 && bounds.center.dx < 230) {
          // [OCR 추가]
          return ''; // [OCR 추가]
        } // [OCR 추가]
        return bounds.center.dx < 230 ? '1' : '37960'; // [OCR 추가]
      }, // [OCR 추가]
    ); // [OCR 추가]
    expect(shown, readBounds); // [OCR 추가]
    expect(shown.length, 5); // [OCR 추가]
    final quantityBounds = [
      for (var i = 0; i < shown.length; i++) // [OCR 추가]
        if (fields[i] == '수량' && shown[i].center.dy < 80) shown[i],
    ]; // [OCR 추가]
    expect(quantityBounds.length, 5); // [OCR 추가]
    expect(quantityBounds.toSet().length, greaterThan(1)); // [OCR 추가]
    expect(
      quantityBounds.every((bounds) => bounds.top >= 40 && bounds.bottom <= 80),
      isTrue,
    ); // [OCR 추가]
  }); // [OCR 추가]

  testWidgets('병렬 인식 중 수량·금액 박스와 문구를 함께 표시하고 취소 시 지운다', (tester) async {
    // [OCR 추가] 두 모의 OCR 응답을 보류한 상태에서 실제 화면의 동시 표시를 검사한다.
    final path = await regionPhoto(tester);
    final base = missingQuantitySource(missingAmount: true);
    final draft = ReceiptDraft(
      id: 'parallel-ui',
      store: '마트',
      purchasedOn: '2026-10-08',
      lines: [],
      ocrResult: ReceiptOcrResult(
        text: base.text,
        photoPath: path,
        rows: base.rows,
        products: base.products,
        numbers: base.numbers,
      ),
    );
    final amountResponse = Completer<String>();
    final quantityResponse = Completer<String>();
    var amounts = 0;
    var quantities = 0;
    Rect? firstQuantityRead; // [OCR 추가]
    final columnCrops = <Rect>[]; // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('열기'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptSelectionScreen(
                    draft: draft,
                    scanRegion: (_, bounds) async {
                      // [OCR 추가]
                      columnCrops.add(bounds); // [OCR 추가]
                      return []; // [OCR 추가]
                    }, // [OCR 추가]
                    recognizeRegion: (_, bounds) async {
                      amounts++;
                      return await amountResponse.future;
                    },
                    recognizeQuantity: (_, bounds) async {
                      firstQuantityRead ??= bounds; // [OCR 추가]
                      quantities++;
                      return await quantityResponse.future;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pump();
    await loadRegion(tester);
    Size? selectedQuantityBoxSize; // [OCR 추가]
    final fitScale =
        tester.getSize(find.byType(InteractiveViewer)).width / 400; // [OCR 추가]
    for (final id in ['first', 'q1', 'p1']) {
      final finder = find.byKey(ValueKey('ocr-candidate-$id'));
      await tester.scrollUntilVisible(
        finder,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      if (id == 'q1') {
        // [OCR 추가]
        selectedQuantityBoxSize = tester.getSize(
          find.byKey(const ValueKey('ocr-box-q1')),
        ); // [OCR 추가]
      } // [OCR 추가]
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
    // [OCR 추가] 다시 선택해도 여백은 한 번만 적용하고 실제 읽는 영역은 화면 박스와 일치해야 한다.
    await tester.tap(find.byKey(const ValueKey('ocr-seed-수량'))); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      tester.getSize(find.byKey(const ValueKey('ocr-box-q1'))),
      selectedQuantityBoxSize,
    ); // [OCR 추가]
    await tester.tap(
      find.byKey(const ValueKey('ocr-box-q1')), // [OCR 수정]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('끝까지 자동 선택'));
    for (var i = 0; i < 30 && (amounts == 0 || quantities == 0); i++) {
      // [OCR 수정]
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(amounts, 1);
    expect(quantities, 1);
    expect(
      firstQuantityRead!.width,
      closeTo(
        selectedQuantityBoxSize!.width / fitScale +
            2 *
                receiptAutomaticHorizontalPadding(
                  selectedQuantityBoxSize.height / fitScale,
                ),
        .01,
      ),
    ); // [OCR 추가]
    expect(
      firstQuantityRead!.height,
      closeTo(selectedQuantityBoxSize.height / fitScale, .01),
    ); // [OCR 추가]
    expect(
      columnCrops.single.width,
      closeTo(firstQuantityRead!.width, 2),
    ); // [OCR 추가]
    expect(
      base.numbers.first.bounds.size,
      const Size(20, 20),
    ); // [OCR 추가] 원본 OCR 좌표는 변경하지 않는다.
    expect(
      find.byKey(const ValueKey('ocr-automatic-reading-box-금액')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ocr-automatic-reading-box-수량')),
      findsOneWidget,
    );
    final progress = tester
        .widget<Text>(find.byKey(const ValueKey('ocr-automatic-progress')))
        .data!;
    expect(progress, contains('금액 1회'));
    expect(progress, contains('수량 1회'));
    Navigator.of(tester.element(find.byType(ReceiptSelectionScreen))).pop();
    await tester.pumpAndSettle();
    amountResponse.complete('15000');
    quantityResponse.complete('2');
    await tester.pumpAndSettle();
    expect(amounts, 1);
    expect(quantities, 1);
    expect(
      find.byKey(const ValueKey('ocr-automatic-reading-box-금액')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('ocr-automatic-reading-box-수량')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  }); // [OCR 추가]
  for (final scenario in ['complete', 'cancel', 'paused-frames']) {
    // [OCR 수정]
    final cancel = scenario == 'cancel'; // [OCR 추가]
    // [OCR 추가]
    testWidgets('끝까지 자동 선택의 실제 버튼 연결과 중복 방지·화면 취소: $scenario', (tester) async {
      // [OCR 추가]
      final path = await regionPhoto(tester); // [OCR 추가]
      final base = missingQuantitySource(missingAmount: true); // [OCR 수정]
      // [OCR 추가] 화면 아래쪽 상품을 사용해 자동 이동 없이 박스가 화면 밖에 있는 경우도 검증한다.
      ReceiptOcrCandidate shifted(ReceiptOcrCandidate candidate) =>
          ReceiptOcrCandidate(
            // [OCR 추가]
            id: candidate.id,
            text: candidate.text,
            number: candidate.number, // [OCR 추가]
            bounds:
                ['first', 'q1', 'p1'].contains(candidate.id) // [OCR 추가]
                ? candidate.bounds
                : candidate.bounds.shift(const Offset(0, 300)), // [OCR 추가]
          ); // [OCR 추가]
      final original = fixture.source(
        base.products.map(shifted).toList(),
        base.numbers.map(shifted).toList(),
      ); // [OCR 수정]
      final draft = ReceiptDraft(
        id: 'retry',
        store: '마트',
        purchasedOn: '2026-10-07',
        lines: [], // [OCR 추가]
        ocrResult: ReceiptOcrResult(
          text: original.text,
          photoPath: path, // [OCR 추가]
          rows: original.rows,
          products: original.products,
          numbers: original.numbers,
        ),
      ); // [OCR 추가]
      final firstResponse = Completer<String>(); // [OCR 추가]
      final quantityResponse = Completer<String>(); // [OCR 추가]
      final attemptedBounds = <Rect>[]; // [OCR 추가]
      var calls = 0; // [OCR 추가]
      var scans = 0; // [OCR 추가]
      ReceiptDraft? saved; // [OCR 추가]
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: // [OCR 추가]
              TextButton(
                child: const Text('열기'),
                onPressed: () async {
                  // [OCR 추가]
                  saved = await Navigator.push<ReceiptDraft>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptSelectionScreen(
                        // [OCR 추가]
                        draft: draft, // [OCR 추가]
                        scanRegion: scenario == 'complete'
                            ? (_, bounds) async {
                                scans++; // [OCR 추가]
                                expect(bounds.bottom, 600); // [OCR 추가]
                                return <ReceiptOcrCandidate>[]; // [OCR 추가]
                              }
                            : null, // [OCR 추가]
                        recognizeRegion: (_, bounds) async {
                          // [OCR 추가]
                          calls++; // [OCR 추가]
                          attemptedBounds.add(bounds); // [OCR 추가]
                          if (calls == 1) {
                            // [OCR 추가]
                            return await firstResponse.future; // [OCR 추가]
                          } // [OCR 추가]
                          if (calls == 2) {
                            // [OCR 추가]
                            return await quantityResponse.future; // [OCR 추가]
                          } // [OCR 추가]
                          final quantity = bounds.center.dx < 230; // [OCR 추가]
                          return bounds.center.dy < 380
                              ? (quantity ? '2' : '37960')
                              : (quantity ? '1' : '12980'); // [OCR 추가]
                        }, // [OCR 추가]
                      ),
                    ),
                  ); // [OCR 추가]
                },
              ), // [OCR 추가]
            ),
          ),
        ),
      ); // [OCR 추가]
      await tester.tap(find.text('열기')); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
      await loadRegion(tester); // [OCR 추가]
      for (final id in ['first', 'q1', 'p1']) {
        // [OCR 추가]
        final finder = find.byKey(ValueKey('ocr-candidate-$id')); // [OCR 추가]
        await tester.scrollUntilVisible(
          finder,
          100,
          scrollable: find.byType(Scrollable).last,
        ); // [OCR 추가]
        await tester.pumpAndSettle(); // [OCR 추가]
        await tester.tap(finder); // [OCR 추가]
        await tester.pumpAndSettle(); // [OCR 추가]
      } // [OCR 추가]
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      ); // [OCR 추가]
      viewer.transformationController!.value = Matrix4.diagonal3Values(
        2,
        2,
        1,
      ); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
      if (scenario == 'paused-frames') {
        // [OCR 추가]
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        ); // [OCR 추가]
        addTearDown(
          () => tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          ),
        ); // [OCR 추가]
      } // [OCR 추가]
      await tester.tap(find.text('끝까지 자동 선택')); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
      if (scenario == 'cancel') {
        // [OCR 추가] 숫자 재인식 전 현재 상품명 위치를 실제 사진 박스로 표시한다.
        expect(find.textContaining('상품명 확인'), findsOneWidget); // [OCR 추가]
        final box = tester.widget<Positioned>(
          find.byKey(const ValueKey('ocr-automatic-reading-box')),
        ); // [OCR 추가]
        final scale =
            tester.getRect(find.byType(InteractiveViewer)).width /
            400; // [OCR 추가]
        expect(
          box.left,
          closeTo(original.products[1].bounds.left * scale, .01),
        ); // [OCR 추가]
        expect(
          box.top,
          closeTo(original.products[1].bounds.top * scale, .01),
        ); // [OCR 추가]
        expect(calls, 0); // [OCR 추가]
      } // [OCR 추가]
      if (scenario == 'paused-frames') {
        // [OCR 추가]
        expect(calls, 0); // [OCR 추가]
        for (var i = 0; i < 12 && calls == 0; i++) {
          // [OCR 수정]
          await tester.pump(const Duration(milliseconds: 50)); // [OCR 추가]
        } // [OCR 추가]
        expect(calls, 1); // [OCR 추가] 프레임이 없어도 무기한 기다리지 않는다.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ); // [OCR 추가]
      } // [OCR 추가]
      for (var i = 0; i < 10 && calls == 0; i++) {
        // [OCR 수정]
        await tester.pump(const Duration(milliseconds: 50)); // [OCR 수정]
      } // [OCR 수정]
      await tester.pump(); // [OCR 수정]
      expect(calls, 1); // [OCR 추가]
      expect(saved, isNull); // [OCR 추가]
      expect(
        scans,
        scenario == 'complete' ? 1 : 0,
      ); // [OCR 수정] 수량 열만 재검사한다. // [OCR 추가]
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '자동 선택 중…'))
            .onPressed,
        isNull,
      ); // [OCR 추가]
      void expectReadingBox(Rect bounds) {
        // [OCR 추가]
        final finder = find.byKey(
          ValueKey(
            bounds.center.dx < 230
                ? 'ocr-automatic-reading-box-수량'
                : 'ocr-automatic-reading-box-금액',
          ),
        ); // [OCR 수정]
        final box = tester.widget<Positioned>(finder); // [OCR 추가]
        final viewport = tester.getRect(
          find.byType(InteractiveViewer),
        ); // [OCR 추가]
        final scale = viewport.width / 400; // [OCR 추가]
        expect(box.left, closeTo(bounds.left * scale, .01)); // [OCR 추가]
        expect(box.top, closeTo(bounds.top * scale, .01)); // [OCR 추가]
        expect(box.width, closeTo(bounds.width * scale, .01)); // [OCR 추가]
        expect(box.height, closeTo(bounds.height * scale, .01)); // [OCR 추가]
        expect(
          viewport.contains(tester.getRect(finder).center),
          isTrue,
        ); // [OCR 추가]
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          2,
        ); // [OCR 추가]
      } // [OCR 추가]

      expectReadingBox(attemptedBounds.first); // [OCR 추가]
      expect(
        viewer.transformationController!.value.storage[13],
        lessThan(0),
      ); // [OCR 추가]
      if (cancel) {
        // [OCR 추가]
        Navigator.of(
          tester.element(find.byType(ReceiptSelectionScreen)),
        ).pop(); // [OCR 추가]
        await tester.pumpAndSettle(); // [OCR 추가]
        firstResponse.complete('37960'); // [OCR 추가]
        await tester.pumpAndSettle(); // [OCR 추가]
        expect(calls, 1); // [OCR 추가]
        expect(saved, isNull); // [OCR 추가]
        expect(tester.takeException(), isNull); // [OCR 추가]
        return; // [OCR 추가]
      } // [OCR 추가]
      firstResponse.complete('37960'); // [OCR 추가]
      for (var i = 0; i < 10 && calls < 2; i++) {
        // [OCR 추가]
        await tester.pump(const Duration(milliseconds: 20)); // [OCR 추가]
      } // [OCR 추가]
      expect(calls, 2); // [OCR 추가]
      expectReadingBox(attemptedBounds[1]); // [OCR 추가]
      expect(find.textContaining('수량 1회'), findsOneWidget); // [OCR 추가]
      quantityResponse.complete('2'); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      expect(calls, 2); // [OCR 수정] 셋째 상품의 기존 수량·금액은 재사용한다.
      expect(saved!.lines[1].quantity, 2); // [OCR 추가]
      expect(saved!.lines[1].selected, isTrue); // [OCR 추가]
      expect(
        saved!.ocrResult!.numbers.any((candidate) => candidate.number == 2),
        isTrue,
      ); // [OCR 추가] 부분 OCR 수량도 검토의 후보 목록에 누적한다.
      expect(
        saved!.ocrResult!.rows.any((row) => row.text == '2'),
        isTrue,
      ); // [OCR 추가] 재선택에 필요한 행 좌표도 남긴다.
      expect(
        find.byKey(const ValueKey('ocr-automatic-reading-box')),
        findsNothing,
      ); // [OCR 추가]
      expect(tester.takeException(), isNull); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]
} // [OCR 추가]
