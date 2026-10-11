import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_column_scan.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]
import 'receipt_automatic_retry_test.dart' show seedFor; // [OCR 추가]

void main() {
  const nameReadings = {
    '정상': '프리즘 220 라인 밴드 노트/크림',
    '글자 차이': '프리즘 220 라인 밴드 노트/크램',
    '문자열 잘림': '프리즘 220 라인 밴드 노트/크',
  };
  for (final entry in nameReadings.entries) {
    final reading = entry.key;
    test('전체 OCR 행 글자가 $reading 상태여도 좌표로 조각을 합쳐 실제 수량을 재사용한다', () async {
      // [OCR 추가] 교보 마지막 상품의 분리 실패를 합성한다. 실사진 OCR 결과와 구분한다.
      const first = ReceiptOcrCandidate(
        id: 'first',
        text: '스티커 CEREAL',
        bounds: Rect.fromLTWH(10, 10, 230, 20),
      );
      const front = ReceiptOcrCandidate(
        id: 'front',
        text: '프리즘',
        bounds: Rect.fromLTWH(10, 90, 50, 20),
      );
      const tail = ReceiptOcrCandidate(
        id: 'tail',
        text: '라인 밴드 노트/크림',
        bounds: Rect.fromLTWH(105, 90, 135, 20),
      );
      final full = ReceiptOcrCandidate(
        id: 'full',
        text: entry.value,
        bounds: Rect.fromLTWH(10, 90, 230, 20),
      );
      final base = fixture.source(
        [first, front, tail],
        [
          fixture.number('q1', 1, 40, quantity: true),
          fixture.number('p1', 4000, 40),
          fixture.number('q2', 1, 120, quantity: true),
          fixture.number('p2', 16800, 120),
        ],
      );
      final source = ReceiptOcrResult(
        text: base.text,
        photoPath: base.photoPath,
        rows: [
          ...base.rows,
          ReceiptOcrRow(
            id: full.id,
            text: full.text,
            bounds: full.bounds,
            tokens: [],
          ),
        ],
        products: base.products,
        numbers: base.numbers,
      ); // [OCR 수정] 새로운 열 인식이 아닌 기존 OCR 행이다.
      var partials = 0;
      final lines = await readAutomaticReceiptLines(
        source: source,
        seed: seedFor(source),
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => true,
        scanRegion: (_, _) async => [full],
        recognize: (_, _) async {
          partials++;
          return '300';
        },
      );
      expect(lines, hasLength(2));
      expect(
        lines!.last.title,
        reading == '정상' ? full.text : '프리즘 라인 밴드 노트/크림',
      );
      expect(lines.last.quantity, 1);
      expect(lines.last.total, 16800);
      expect(lines.last.selected, isTrue);
      expect(partials, 0);
      expect(source.products, [first, front, tail]);
    });
  }

  for (final positions in [(10.0, 10.0), (10.0, 40.0), (40.0, 10.0)]) {
    test('첫 상품명과 숫자가 같은 행이면 전체 이름으로 병합하지 않는다: $positions', () async {
      // [OCR 추가] 같은 행에 가격·수량이 있어도 긴 열 응답을 상품명으로 가져오지 않는다.
      const first = ReceiptOcrCandidate(
        id: 'first',
        text: '첫 상품',
        bounds: Rect.fromLTWH(10, 10, 230, 20),
      );
      const front = ReceiptOcrCandidate(
        id: 'front',
        text: '프리즘',
        bounds: Rect.fromLTWH(10, 90, 50, 20),
      );
      const tail = ReceiptOcrCandidate(
        id: 'tail',
        text: '라인 밴드 노트/크림',
        bounds: Rect.fromLTWH(105, 90, 135, 20),
      );
      const full = ReceiptOcrCandidate(
        id: 'full',
        text: '프리즘 220 라인 밴드 노트/크림 1 16800',
        bounds: Rect.fromLTWH(10, 90, 330, 20),
      );
      final source = fixture.source(
        [first, front, tail],
        [
          fixture.number('q1', 1, positions.$1, quantity: true),
          fixture.number('p1', 4000, positions.$2),
          fixture.number('q2', 1, positions.$1 + 80, quantity: true),
          fixture.number('p2', 16800, positions.$2 + 80),
        ],
      );
      ReceiptOcrResult? accumulated;
      final lines = await readAutomaticReceiptLines(
        source: source,
        seed: seedFor(source),
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => true,
        scanRegion: (_, _) async => [full],
        recognize: (_, _) async => '',
        onCandidates: (result) => accumulated = result,
      );
      expect(accumulated!.products, [first, front, tail]);
      expect(lines!.last.title, '프리즘');
      if (positions.$1 == positions.$2) expect(lines.last.quantity, 1);
      expect(lines.last.total, 16800);
      expect(lines.last.title, isNot(contains('16800')));
    });
  }

  for (final enlargedAmount in [false, true]) {
    test('확정된 숫자는 첫 박스 높이가 상품 행보다 커도 재사용한다: $enlargedAmount', () async {
      // [OCR 추가] 실제 화면의 한 글자 여백/영역 확대로 캐시가 높이 검사에서 버려지는 실패를 재현한다.
      final source = fixture.source(
        [
          fixture.name('first', '퍼실', 100),
          fixture.name('second', '베지밀', 140),
          fixture.name('third', '마미손', 180),
        ],
        [
          fixture.number('q1', 3, 100, quantity: true),
          fixture.number('p1', 80940, 100),
          fixture.number('q2', 2, 140, quantity: true),
          fixture.number('p2', 15000, 140),
          fixture.number('q3', 1, 180, quantity: true),
          fixture.number('p3', 9980, 180),
        ],
      ); // [OCR 추가]
      ReceiptOcrCandidate enlarged(ReceiptOcrCandidate candidate) =>
          ReceiptOcrCandidate(
            id: candidate.id,
            text: candidate.text,
            number: candidate.number,
            bounds: Rect.fromCenter(
              center: candidate.bounds.center,
              width: candidate.bounds.width,
              height: 80,
            ),
          ); // [OCR 추가]
      final seed = ReceiptAutomaticSeed(
        product: source.products.first,
        quantity: enlarged(source.numbers[0]),
        amount: enlargedAmount
            ? enlarged(source.numbers[1])
            : source.numbers[1],
        isUnitPrice: false,
      ); // [OCR 추가]
      var calls = 0; // [OCR 추가]
      final lines = await readAutomaticReceiptLines(
        source: source,
        seed: seed,
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => true,
        recognize: (_, _) async {
          calls++;
          return '';
        },
      ); // [OCR 추가]
      expect(lines!.every((line) => line.selected), isTrue); // [OCR 추가]
      expect(lines.map((line) => line.quantity), [3, 2, 1]); // [OCR 추가]
      expect(lines.map((line) => line.total), [80940, 15000, 9980]); // [OCR 추가]
      expect(
        lines[1].ocrQuantity!.bounds.height,
        80,
      ); // [OCR 추가] 값을 살리기 위해 첫 박스를 축소하지 않는다.
      if (enlargedAmount) {
        expect(lines[1].ocrAmount!.bounds.height, 80); // [OCR 추가]
      }
      expect(calls, 0); // [OCR 추가]
    });
  }

  test('전체 OCR의 연결된 숫자는 다시 읽지 않고 숫자 열도 건너뛴다', () async {
    // [OCR 추가] 모의 응답으로 호출 생략과 원본 불변을 검사하며 실제 인식률과 구분한다.
    final source = fixture.source(
      [fixture.name('first', '퍼실', 10), fixture.name('second', '베지밀', 50)],
      [
        fixture.number('q1', 3, 10, quantity: true),
        fixture.number('p1', 80940, 10),
        fixture.number('q2', 2, 50, quantity: true),
        fixture.number('p2', 15000, 50),
      ],
    ); // [OCR 추가]
    final scans = <Rect>[]; // [OCR 추가]
    var partials = 0; // [OCR 추가]
    ReceiptOcrResult? accumulated; // [OCR 추가]
    final lines = await readAutomaticReceiptLines(
      source: source,
      seed: seedFor(source),
      photoBytes: Uint8List(0),
      photoSize: const Size(400, 600),
      isCurrent: () => true, // [OCR 추가]
      scanRegion: (_, bounds) async {
        scans.add(bounds);
        return [];
      }, // [OCR 추가]
      recognize: (_, _) async {
        partials++;
        return '';
      }, // [OCR 추가]
      onCandidates: (result) => accumulated = result, // [OCR 추가]
    ); // [OCR 추가]
    expect(scans, isEmpty); // [OCR 수정] 기존 수량이 모두 연결되어 열을 읽지 않는다.
    expect(partials, 0); // [OCR 추가]
    expect(lines![1].selected, isTrue); // [OCR 추가]
    expect(lines[1].quantity, 2); // [OCR 추가]
    expect(lines[1].total, 15000); // [OCR 추가]
    expect(
      accumulated!.numbers.map((number) => number.id),
      source.numbers.map((number) => number.id),
    ); // [OCR 추가]
    expect(source.numbers, hasLength(4)); // [OCR 추가]
  });

  test('수량 열만 누적하고 전체 OCR 상품명·금액은 그대로 유지한다', () async {
    final first = fixture.name('first', '퍼실', 10); // [OCR 추가]
    final second = fixture.name('second', '베지밀', 50); // [OCR 추가]
    final third = fixture.name('third', '우유', 90); // [OCR 추가]
    final source = fixture.source(
      [first, second, third],
      [
        fixture.number('q1', 3, 10, quantity: true),
        fixture.number('p1', 80940, 10),
        fixture.number('q2', 2, 50, quantity: true),
        fixture.number('p2', 15000, 50),
        fixture.number('p3', 9000, 90),
      ],
    ); // [OCR 추가]
    final q3 = fixture.number('q3', 1, 90, quantity: true); // [OCR 추가]
    var partials = 0; // [OCR 추가]
    ReceiptOcrResult? accumulated; // [OCR 추가]
    final lines = await readAutomaticReceiptLines(
      source: source,
      seed: seedFor(source),
      photoBytes: Uint8List(0),
      photoSize: const Size(400, 600),
      isCurrent: () => true, // [OCR 추가]
      scanRegion: (_, bounds) async {
        // [OCR 수정] 이름·금액 열을 호출하면 실패하도록 해 수량 열만 보완하는 실제 연결을 검사한다.
        expect(bounds.center.dx, inExclusiveRange(170, 230));
        return [q3];
      },
      recognize: (_, _) async {
        partials++;
        return '';
      }, // [OCR 추가]
      onCandidates: (result) => accumulated = result, // [OCR 추가]
    ); // [OCR 추가]
    expect(partials, 0); // [OCR 추가]
    expect(lines!.map((line) => line.title), ['퍼실', '베지밀', '우유']); // [OCR 추가]
    expect(lines.every((line) => line.selected), isTrue); // [OCR 추가]
    expect(accumulated!.numbers, hasLength(6)); // [OCR 추가]
    expect(accumulated!.products, hasLength(3)); // [OCR 추가]
    final addedName = accumulated!.products.last; // [OCR 추가]
    expect(
      accumulated!.rows.any(
        (row) => row.tokens.any((token) => token.id == addedName.id),
      ),
      isTrue,
    ); // [OCR 추가] 새 후보도 검토의 행·박스 선택에 남는다.
    expect(source.products, hasLength(3)); // [OCR 추가]
    expect(source.numbers, hasLength(5)); // [OCR 추가]
  });

  for (final fail in [false, true]) {
    test('누락 수량만 부분 OCR으로 보완하고 금액은 실패해도 유지한다: $fail', () async {
      final source = fixture.source(
        [fixture.name('first', '퍼실', 10), fixture.name('second', '베지밀', 50)],
        [
          fixture.number('q1', 3, 10, quantity: true),
          fixture.number('p1', 80940, 10),
          fixture.number('p2', 15000, 50),
        ],
      ); // [OCR 추가]
      var calls = 0; // [OCR 추가]
      ReceiptOcrResult? accumulated; // [OCR 추가]
      final lines = await readAutomaticReceiptLines(
        source: source,
        seed: seedFor(source),
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 600),
        isCurrent: () => true, // [OCR 추가]
        scanRegion: (_, _) async => [], // [OCR 추가]
        recognize: (_, bounds) async {
          calls++;
          expect(bounds.center.dx, lessThan(230));
          return fail ? '' : '2';
        }, // [OCR 추가]
        onCandidates: (result) => accumulated = result, // [OCR 추가]
      ); // [OCR 추가]
      expect(calls, fail ? 5 : 1); // [OCR 추가]
      expect(lines![1].total, 15000); // [OCR 추가]
      expect(lines[1].quantity, fail ? 0 : 2); // [OCR 추가]
      expect(lines[1].selected, !fail); // [OCR 추가]
      expect(accumulated!.numbers, hasLength(fail ? 3 : 4)); // [OCR 추가]
    });
  }

  test('같은 값도 위치가 다르면 누적하며 같은 위치의 다른 값은 덮어쓰지 않는다', () {
    final q2 = fixture.number('q2', 1, 50, quantity: true); // [OCR 추가]
    final q3 = fixture.number('q3', 1, 90, quantity: true); // [OCR 추가]
    final duplicate = fixture.number(
      'duplicate',
      1,
      50,
      quantity: true,
    ); // [OCR 추가]
    final conflict = fixture.number(
      'conflict',
      2,
      50,
      quantity: true,
    ); // [OCR 추가]
    final result = receiptNumbersWithCandidates(
      [q2],
      [q3, duplicate, conflict],
    ); // [OCR 추가]
    expect(result.map((number) => number.id), [
      'q2',
      'q3',
      'conflict',
    ]); // [OCR 추가]
    expect(q2.number, 1); // [OCR 추가]
  });

  test('열 인식 중 취소하면 추가 후보를 외부로 전달하지 않는다', () async {
    final source = fixture.source(
      [fixture.name('first', '퍼실', 10), fixture.name('second', '베지밀', 50)],
      [
        fixture.number('q1', 3, 10, quantity: true),
        fixture.number('p1', 80940, 10),
      ],
    ); // [OCR 추가]
    var current = true; // [OCR 추가]
    var published = false; // [OCR 추가]
    final lines = await readAutomaticReceiptLines(
      source: source,
      seed: seedFor(source),
      photoBytes: Uint8List(0),
      photoSize: const Size(400, 600),
      isCurrent: () => current, // [OCR 추가]
      scanRegion: (_, _) async {
        current = false;
        return [fixture.name('second', '베지밀', 50)];
      }, // [OCR 추가]
      recognize: (_, _) async => '1', // [OCR 추가]
      onCandidates: (_) => published = true, // [OCR 추가]
    ); // [OCR 추가]
    expect(lines, isNull); // [OCR 추가]
    expect(published, isFalse); // [OCR 추가]
    expect(source.products, hasLength(2)); // [OCR 추가]
  });
}
