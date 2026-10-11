import 'package:how_much/receipt_region_retry.dart'
    show receiptRegionRetryEnvelope; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_column_scan.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]
import 'receipt_automatic_retry_test.dart' as retry; // [OCR 추가]

ReceiptOcrCandidate row(String id, String text, Rect bounds) => // [OCR 추가]
    ReceiptOcrCandidate(id: id, text: text, bounds: bounds); // [OCR 추가]

void main() {
  test('병렬 금액 처리 중 첫 수량 열 성공값을 재인식 없이 사용한다', () async {
    // [OCR 추가] 초기 열 탐색은 순차이고 첫 성공 뒤 수량 부분 호출도 하지 않는다.
    final first = fixture.name('first', '퍼실', 10);
    final second = fixture.name('second', '베지밀', 50);
    final q1 = fixture.number('q1', 3, 10, quantity: true);
    final q2 = fixture.number('q2', 2, 50, quantity: true);
    final p1 = fixture.number('p1', 80940, 10);
    var mainBusy = false;
    var quantityCalls = 0;
    final result = await readAutomaticReceiptLines(
      source: fixture.source([first, second], [q1, p1]),
      seed: ReceiptAutomaticSeed(
        product: first,
        quantity: q1,
        amount: p1,
        isUnitPrice: false,
      ),
      photoBytes: Uint8List(0),
      photoSize: const Size(400, 600),
      isCurrent: () => true,
      scanRegion: (_, bounds) async {
        expect(mainBusy, isFalse);
        return bounds.center.dx > 170 && bounds.center.dx < 230 ? [q2] : [];
      },
      recognize: (_, bounds) async {
        expect(mainBusy, isFalse);
        mainBusy = true;
        await Future<void>.delayed(Duration.zero);
        mainBusy = false;
        return '15000';
      },
      recognizeQuantity: (_, bounds) async {
        quantityCalls++;
        return '2';
      },
    ); // [OCR 추가]
    expect(quantityCalls, 0);
    expect(result![1].selected, isTrue);
    expect(result[1].quantity, 2);
  }); // [OCR 추가]
  for (final scenario in [
    'stable',
    'missing',
    'conflict',
    'partial-conflict',
    'cancel', // [OCR 수정] 최초 열 인식 도중 취소를 확인한다.
  ]) {
    // [OCR 추가]
    test('열 수량을 실제 첫 성공으로 보존하고 추가 열 확인을 생략한다: $scenario', () async {
      // [OCR 추가]
      final names = [
        fixture.name('first', '퍼실', 10),
        fixture.name('second', '베지밀', 50),
        fixture.name('third', '우유', 90),
      ]; // [OCR 추가]
      final quantities = [
        for (var i = 0; i < 3; i++)
          fixture.number('q$i', 1, 10 + i * 40, quantity: true),
      ]; // [OCR 추가]
      final amount = fixture.number('amount', 15000, 10); // [OCR 추가]
      final source = fixture.source(names, [
        quantities.first,
        amount,
      ]); // [OCR 추가]
      var current = true; // [OCR 추가]
      var quantityPasses = 0; // [OCR 추가]
      var partialQuantities = 0; // [OCR 추가]
      final result = await readAutomaticReceiptLines(
        source: source, // [OCR 추가]
        seed: ReceiptAutomaticSeed(
          product: names.first,
          quantity: quantities.first,
          amount: amount,
          isUnitPrice: false,
        ), // [OCR 추가]
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => current, // [OCR 추가]
        scanRegion: (_, bounds) async {
          // [OCR 추가]
          if (bounds.center.dx < 170 || bounds.center.dx > 230) {
            // [OCR 추가]
            return []; // [OCR 추가]
          } // [OCR 추가]
          quantityPasses++; // [OCR 추가]
          if (quantityPasses == 1 && scenario == 'cancel') {
            current = false;
            return quantities;
          } // [OCR 추가]
          if (quantityPasses > 1 &&
              (scenario == 'missing' || scenario == 'partial-conflict')) {
            // [OCR 추가]
            return []; // [OCR 추가]
          } // [OCR 추가]
          if (quantityPasses == 2 && scenario == 'conflict') {
            // [OCR 추가]
            return [
              quantities.first,
              row('different', '2', quantities[1].bounds),
              quantities[2],
            ]; // [OCR 추가]
          } // [OCR 추가]
          return quantities; // [OCR 추가]
        }, // [OCR 추가]
        recognize: (_, bounds) async {
          // [OCR 추가]
          if (bounds.center.dx < 230) {
            partialQuantities++;
            return scenario == 'partial-conflict' ? '2' : ''; // [OCR 수정]
          } // [OCR 추가]
          return '15000'; // [OCR 추가]
        }, // [OCR 추가]
      ); // [OCR 추가]
      if (scenario == 'cancel') {
        // [OCR 추가]
        expect(result, isNull);
        expect(quantityPasses, 1);
        expect(partialQuantities, 0);
        return; // [OCR 추가]
      } // [OCR 추가]
      expect(quantityPasses, 1); // [OCR 수정] 첫 열 결과가 유효하면 추가 호출하지 않는다.
      expect(result![1].quantity, 1); // [OCR 추가] 부분 OCR 실패가 열에서 읽힌 값을 비우지 않는다.
      expect(result[2].quantity, 1); // [OCR 추가]
      expect(
        result[1].ocrQuantity!.id,
        isNot(result[2].ocrQuantity!.id),
      ); // [OCR 추가]
      expect(result[1].ocrQuantity!.bounds.center.dy, 60); // [OCR 추가]
      expect(result[2].ocrQuantity!.bounds.center.dy, 100); // [OCR 추가]
      expect(result[1].selected, isTrue); // [OCR 수정] // [OCR 추가]
      expect(result[2].selected, isTrue); // [OCR 수정]
      expect(partialQuantities, 0); // [OCR 수정] 첫 열 성공 이후 부분 OCR을 하지 않는다.
    }); // [OCR 수정]
  } // [OCR 수정]

  for (final scanFound in [false, true]) {
    test('작게 읽힌 기존 숫자를 재사용해도 첫 수량·금액 높이를 유지한다: $scanFound', () async {
      // [OCR 추가] 후보와 열 탐색 모두 작은 박스를 반환하는 실제 축소 경로를 재현한다.
      final first = fixture.name('first', '퍼실', 10);
      final second = fixture.name('second', '베지밀', 110);
      const q1 = ReceiptOcrCandidate(
        id: 'q1',
        text: '3',
        number: 3,
        bounds: Rect.fromLTWH(160, 6, 60, 28),
      );
      const p1 = ReceiptOcrCandidate(
        id: 'p1',
        text: '80940',
        number: 80940,
        bounds: Rect.fromLTWH(270, 4, 70, 32),
      );
      const q2 = ReceiptOcrCandidate(
        id: 'q2',
        text: '2',
        number: 2,
        bounds: Rect.fromLTWH(187, 117, 6, 6),
      );
      const p2 = ReceiptOcrCandidate(
        id: 'p2',
        text: '15000',
        number: 15000,
        bounds: Rect.fromLTWH(290, 117, 50, 6),
      );
      final reads = <Rect>[];
      var amountCalls = 0;
      var quantityCalls = 0;
      final result = await readAutomaticReceiptLines(
        source: fixture.source([first, second], [q1, p1, q2, p2]),
        seed: ReceiptAutomaticSeed(
          product: first,
          quantity: q1,
          amount: p1,
          isUnitPrice: false,
        ),
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => true,
        scanRegion: (_, bounds) async {
          if (!scanFound) return [];
          if (bounds.center.dx > 230) return [p2];
          if (bounds.center.dx > 160) return [q2];
          return [];
        },
        recognize: (_, bounds) async {
          reads.add(bounds);
          if (bounds.center.dx < 230) {
            quantityCalls++;
            return quantityCalls < 4 ? '' : '2';
          }
          amountCalls++;
          return amountCalls < 5 ? '' : '15000';
        },
      ); // [OCR 추가]
      expect(amountCalls, 0); // [OCR 수정] 전체 OCR 금액을 재사용한다.
      // [OCR 추가] 전체 OCR에서 수량이 연결되면 열·부분 호출은 하지 않는다.
      expect(quantityCalls, 0); // [OCR 수정] 전체 OCR 수량을 재사용한다.
      expect(
        reads
            .where((r) => r.center.dx > 230)
            .every((r) => r.height >= p1.bounds.height),
        isTrue,
      );
      expect(
        reads
            .where((r) => r.center.dx < 230)
            .every((r) => r.height >= q1.bounds.height),
        isTrue,
      );
      expect(result![1].selected, isTrue);
      expect(
        result[1].ocrAmount!.bounds.height,
        greaterThanOrEqualTo(p1.bounds.height),
      );
      expect(
        result[1].ocrQuantity!.bounds.height,
        greaterThanOrEqualTo(q1.bounds.height),
      );
    }); // [OCR 추가]
  }
  for (final scanFound in [false, true]) {
    // [OCR 추가]
    test('첫 수량 박스의 수정한 크기를 열 탐색과 각 상품 재인식에 그대로 사용한다: $scanFound', () async {
      // [OCR 추가]
      final first = fixture.name('first', '퍼실', 10); // [OCR 추가]
      final second = fixture.name('second', '베지밀', 50); // [OCR 추가]
      final q1 = row(
        'q1',
        '3',
        const Rect.fromLTWH(160, 6, 60, 28),
      ); // [OCR 추가]
      final seedQuantity = ReceiptOcrCandidate(
        id: q1.id,
        text: q1.text,
        number: 3,
        bounds: q1.bounds,
      ); // [OCR 추가]
      final q2 = ReceiptOcrCandidate(
        id: 'q2',
        text: '2',
        number: 2,
        bounds: const Rect.fromLTWH(187, 56, 6, 8),
      ); // [OCR 추가]
      final p1 = fixture.number('p1', 80940, 10); // [OCR 추가]
      final p2 = fixture.number('p2', 15000, 50); // [OCR 추가]
      final source = fixture.source(
        [first, second],
        [seedQuantity, p1, q2, p2],
      ); // [OCR 추가]
      final crops = <Rect>[]; // [OCR 추가]
      final reads = <Rect>[]; // [OCR 추가]
      final result = await readAutomaticReceiptLines(
        source: source, // [OCR 추가]
        seed: ReceiptAutomaticSeed(
          product: first,
          quantity: seedQuantity,
          amount: p1,
          isUnitPrice: false,
        ), // [OCR 추가]
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => true, // [OCR 추가]
        scanRegion: (_, bounds) async {
          // [OCR 추가]
          crops.add(bounds); // [OCR 추가]
          return scanFound && crops.length == 2 ? [q2] : []; // [OCR 추가]
        }, // [OCR 추가]
        recognize: (_, bounds) async {
          reads.add(bounds);
          return bounds.center.dx < 230 ? '2' : '15000';
        },
      ); // [OCR 추가]
      expect(crops, isEmpty); // [OCR 수정] 두 숫자가 이미 연결되어 열을 읽지 않는다.
      final quantityBounds = result![1].ocrQuantity!.bounds; // [OCR 수정]
      expect(quantityBounds.height, seedQuantity.bounds.height); // [OCR 수정]
      expect(
        quantityBounds.width,
        closeTo(
          seedQuantity.bounds.width +
              2 * receiptAutomaticHorizontalPadding(seedQuantity.bounds.height),
          .01,
        ),
      ); // [OCR 수정]
      expect(quantityBounds.center, q2.bounds.center); // [OCR 수정]
      expect(reads.length, 0); // [OCR 수정] 열 성공이면 수량 부분 호출을 생략한다.
      expect(result[1].quantity, 2); // [OCR 추가]
      expect(result[1].selected, isTrue); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  // [OCR 추가]
  test('열 크롭의 분리 콤마·음수와 행 좌표를 사진 좌표로 복원한다', () {
    // [OCR 추가]
    final source = buildReceiptOcrResult(
      text: '퍼실 -15,000',
      photoPath: '',
      rows: [
        // [OCR 추가]
        ReceiptOcrRow(
          id: 'row',
          text: '퍼실 -15,000',
          bounds: const Rect.fromLTWH(2, 5, 98, 20),
          tokens: [
            // [OCR 추가]
            const ReceiptOcrToken(
              id: 'name',
              text: '퍼실',
              bounds: Rect.fromLTWH(2, 5, 30, 20),
            ), // [OCR 추가]
            const ReceiptOcrToken(
              id: 'price',
              text: '-15,000',
              bounds: Rect.fromLTWH(40, 5, 60, 20),
            ), // [OCR 추가]
          ],
        ), // [OCR 추가]
      ],
    ); // [OCR 추가]
    final rows = receiptCropRowsInPhoto(
      source,
      const Rect.fromLTWH(100, 200, 120, 400),
    ); // [OCR 추가]
    expect(rows.single.text, '퍼실 -15,000'); // [OCR 추가]
    expect(
      rows.single.bounds,
      const Rect.fromLTWH(102, 205, 98, 20),
    ); // [OCR 추가]
  }); // [OCR 추가]

  test('같은 값의 서로 다른 행 위치를 보관하고 가까운 행이 유일할 때만 고른다', () {
    // [OCR 추가]
    final rows = [
      row('a', '1', const Rect.fromLTWH(182, 52, 16, 18)),
      row('b', '1', const Rect.fromLTWH(182, 92, 16, 18)),
    ]; // [OCR 추가]
    const expected = Rect.fromLTWH(180, 50, 20, 20); // [OCR 추가]
    const allowed = Rect.fromLTRB(0, 40, 400, 80); // [OCR 추가]
    expect(
      receiptColumnRowNear(rows, expected, allowed, quantity: true)?.id,
      'a',
    ); // [OCR 추가]
    expect(
      receiptColumnRowNear(
        [
          rows.first,
          row('ambiguous', '2', const Rect.fromLTWH(184, 54, 16, 18)),
        ],
        expected,
        allowed,
        quantity: true,
      ),
      isNull,
    ); // [OCR 추가]
    expect(
      receiptColumnRowNear([rows.last], expected, allowed, quantity: true),
      isNull,
    ); // [OCR 추가]
  }); // [OCR 추가]

  test('열 탐색은 세 열을 순서대로 읽고 실패한 열만 빈 결과로 유지한다', () async {
    // [OCR 추가]
    final source = retry.missingQuantitySource(); // [OCR 추가]
    final seed = retry.seedFor(source); // [OCR 추가]
    final crops = <Rect>[]; // [OCR 추가]
    final result = await scanReceiptColumns(
      product: seed.product,
      amount: seed.amount,
      quantity: seed.quantity, // [OCR 추가]
      photoBytes: Uint8List(0),
      photoSize: const Size(400, 600),
      isCurrent: () => true, // [OCR 추가]
      recognize: (_, bounds) async {
        // [OCR 추가]
        crops.add(bounds); // [OCR 추가]
        if (crops.length == 2) throw StateError('수량 열 인식 실패'); // [OCR 추가]
        return [
          row('r', '내용', Rect.fromLTWH(bounds.left + 2, 50, 10, 20)),
        ]; // [OCR 추가]
      },
    ); // [OCR 추가]
    expect(crops.length, 3); // [OCR 추가]
    expect(crops.every((crop) => crop.bottom == 600), isTrue); // [OCR 추가]
    expect(crops[0].right, lessThan(crops[1].left)); // [OCR 추가]
    expect(crops[1].right, lessThan(crops[2].left)); // [OCR 추가]
    expect(result!.products.length, 1); // [OCR 추가]
    expect(result.quantities, isEmpty); // [OCR 추가]
    expect(result.amounts.length, 1); // [OCR 추가]
  }); // [OCR 추가]

  test('열 탐색 중 취소하면 늦은 결과를 버리고 나머지 열은 호출하지 않는다', () async {
    // [OCR 추가]
    final seed = retry.seedFor(retry.missingQuantitySource()); // [OCR 추가]
    var current = true; // [OCR 추가]
    var calls = 0; // [OCR 추가]
    final result = await scanReceiptColumns(
      product: seed.product,
      amount: seed.amount,
      quantity: seed.quantity, // [OCR 추가]
      photoBytes: Uint8List(0),
      photoSize: const Size(400, 600),
      isCurrent: () => current, // [OCR 추가]
      recognize: (_, bounds) async {
        calls++;
        current = false;
        return [];
      },
    ); // [OCR 추가]
    expect(result, isNull); // [OCR 추가]
    expect(calls, 1); // [OCR 추가]
  }); // [OCR 추가]

  for (final failure in [false, true]) {
    // [OCR 추가]
    test('자동 선택은 가까운 탐색 행에서만 반복하며 실패해도 옛 숫자를 복원하지 않는다: $failure', () async {
      // [OCR 추가]
      final source = fixture.source(
        [
          fixture.name('first', '퍼실', 10),
          fixture.name('second', '스너글', 50),
        ], // [OCR 추가]
        [
          fixture.number('q1', 3, 10, quantity: true),
          fixture.number('p1', 80940, 10),
        ],
      ); // [OCR 추가]
      final scans = <Rect>[]; // [OCR 추가]
      final reads = <Rect>[]; // [OCR 추가]
      const q = Rect.fromLTWH(184, 53, 14, 16); // [OCR 추가]
      const p = Rect.fromLTWH(
        260,
        50,
        80,
        20,
      ); // [OCR 수정] 금액 열 대신 첫 금액과 이름의 상대 위치를 사용한다.
      final lines = await readAutomaticReceiptLines(
        source: source,
        seed: retry.seedFor(source), // [OCR 추가]
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => true, // [OCR 추가]
        scanRegion: (_, bounds) async {
          // [OCR 추가]
          scans.add(bounds); // [OCR 추가]
          if (scans.length == 1) {
            // [OCR 추가]
            return [
              row('q', '잘못 읽힌 글자', q),
              row('next', '1', q.shift(const Offset(0, 40))),
            ]; // [OCR 추가]
          } // [OCR 추가]
          return []; // [OCR 추가]
        }, // [OCR 추가]
        recognize: (_, bounds) async {
          // [OCR 추가]
          reads.add(bounds); // [OCR 추가]
          return failure
              ? ''
              : (bounds.center.dx < 230 ? '2' : '15000'); // [OCR 추가]
        },
      ); // [OCR 추가]
      expect(scans.length, 1); // [OCR 수정] 수량 열만 호출한다. // [OCR 추가]
      final searchAmount = Rect.fromCenter(
        center: p.center,
        width: p.width + 8, // [OCR 수정] 기준 높이20의 좌우4px 여백.
        height: source.numbers[1].bounds.height,
      ); // [OCR 수정] 후보 높이 대신 첫 금액 높이를 유지한다.
      expect(reads.first, searchAmount); // [OCR 수정]
      final quantityReads = reads
          .where((bounds) => bounds.center.dx < 230)
          .toList(); // [OCR 추가]
      expect(quantityReads.first.center, q.center); // [OCR 추가]
      expect(quantityReads.first.height, 20); // [OCR 추가]
      expect(
        quantityReads.first.width,
        28, // [OCR 수정] 첫 수량 폭20에 좌우4px씩 더한다.
      ); // [OCR 추가]
      expect(
        reads
            .where((bounds) => bounds.center.dx > 230)
            .every(
              (bounds) =>
                  receiptRegionRetryEnvelope(
                    searchAmount,
                  ).contains(bounds.topLeft) &&
                  receiptRegionRetryEnvelope(
                    searchAmount,
                  ).contains(bounds.bottomRight - const Offset(.001, .001)),
            ),
        isTrue,
      ); // [OCR 추가]
      expect(
        quantityReads.every(
          (bounds) =>
              bounds.top >= 40 &&
              bounds.bottom <= 80, // [OCR 수정] 확대해도 현재 상품 행의 위아래 경계를 넘지 않는다.
        ),
        isTrue,
      ); // [OCR 추가]
      expect(reads.length, failure ? 10 : 2); // [OCR 추가]
      expect(lines![1].selected, !failure); // [OCR 추가]
      if (failure) {
        // [OCR 추가]
        expect(lines[1].ocrAmount, isNull); // [OCR 추가]
        expect(lines[1].ocrQuantity, isNull); // [OCR 추가]
      } else {
        // [OCR 추가]
        expect(lines[1].quantity, 2); // [OCR 추가]
        expect(lines[1].total, 15000); // [OCR 추가]
      } // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  test('상품명 열의 새 행을 보완하고 기존 이름과 첫 기준을 중복시키지 않는다', () {
    // [OCR 추가]
    final first = fixture.name('first', '퍼실', 10); // [OCR 추가]
    final second = fixture.name('second', '스너글', 50); // [OCR 추가]
    final result = receiptProductsWithColumnRows(
      [first, second],
      [
        // [OCR 추가]
        row('same', '스너글', second.bounds), // [OCR 추가]
        row('new', '베지밀', const Rect.fromLTWH(12, 90, 100, 20)), // [OCR 추가]
        row('number', '123', const Rect.fromLTWH(12, 130, 100, 20)), // [OCR 추가]
        row(
          'code',
          '1234567890A',
          const Rect.fromLTWH(12, 170, 100, 20),
        ), // [OCR 추가]
      ],
      first,
    ); // [OCR 추가]
    expect(result.map((candidate) => candidate.id), [
      'first',
      'second',
      'column-name-new',
    ]); // [OCR 추가]
  }); // [OCR 추가]

  for (final scenario in ['다른 행', '잘린 영역', '열 밖 시작점']) {
    test('상품명 행 병합은 $scenario 후보를 합치지 않는다', () {
      // [OCR 추가] 긴 박스가 걸치기만 한 후보를 병합해 이름과 좌표를 잃지 않게 한다.
      final first = fixture.name('first', '첫 상품', 10);
      final left = row(
        'left',
        '앞이름',
        Rect.fromLTWH(scenario == '열 밖 시작점' ? 110 : 10, 90, 40, 20),
      );
      final right = row(
        'right',
        '뒷이름',
        Rect.fromLTWH(
          scenario == '열 밖 시작점' ? 170 : 80,
          scenario == '다른 행' ? 105 : 90,
          40,
          20,
        ),
      );
      final full = row(
        'full',
        '앞이름 뒷이름',
        Rect.fromLTWH(10, 90, scenario == '잘린 영역' ? 60 : 210, 20),
      );
      final result = receiptProductsWithColumnRows(
        [first, left, right],
        [full],
        first,
        mergeNameRows: true, // [OCR 추가] 전체 행 병합을 사용하는 경우의 경계도 검사한다.
      );
      expect(result.map((name) => name.id), ['first', 'left', 'right']);
      expect(result.where((name) => name.isMergedName), isEmpty);
    });
  }
} // [OCR 추가]
