import 'dart:ui'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]
import 'receipt_automatic_retry_test.dart' as retry; // [OCR 추가]

ReceiptOcrCandidate shifted(
  ReceiptOcrCandidate candidate,
  String id,
  double dx,
  double dy, {
  int? value,
  double? width, // [OCR 추가]
}) => ReceiptOcrCandidate(
  // [OCR 추가]
  id: id,
  text: value?.toString() ?? candidate.text,
  number: value ?? candidate.number, // [OCR 추가]
  bounds: Rect.fromLTWH(
    candidate.bounds.left + dx,
    candidate.bounds.top + dy,
    width ?? candidate.bounds.width,
    candidate.bounds.height,
  ), // [OCR 수정] // [OCR 추가]
); // [OCR 추가]

void main() {
  test('삼선 보정 사진: 시작 열 밖의 짧은 결제 안내는 자동 후보에서 제외한다', () {
    // [OCR 추가]
    // [OCR 추가] 실제 측정 좌표 재생이며 같은 열 안의 가·계 조각까지 상품이라고 보장하는 테스트는 아니다.
    const first = ReceiptOcrCandidate(
      id: 'first',
      text: '삼선파장',
      bounds: Rect.fromLTRB(282, 830, 464, 884),
    ); // [OCR 추가]
    final names = [
      // [OCR 추가]
      first, // [OCR 추가]
      const ReceiptOcrCandidate(
        id: 'pepsi',
        text: '제로펩시',
        bounds: Rect.fromLTRB(283, 948, 468, 997),
      ), // [OCR 추가]
      const ReceiptOcrCandidate(
        id: 'bu',
        text: '부',
        bounds: Rect.fromLTRB(58, 1176, 104, 1218),
      ), // [OCR 추가]
      const ReceiptOcrCandidate(
        id: 'ga',
        text: '가',
        bounds: Rect.fromLTRB(310, 1176, 356, 1219),
      ), // [OCR 추가]
      const ReceiptOcrCandidate(
        id: 'gye',
        text: '계:',
        bounds: Rect.fromLTRB(336, 1283, 508, 1335),
      ), // [OCR 추가]
      const ReceiptOcrCandidate(
        id: 'hap',
        text: '합',
        bounds: Rect.fromLTRB(58, 1285, 152, 1331),
      ), // [OCR 추가]
      const ReceiptOcrCandidate(
        id: 'due',
        text: '받을금액:',
        bounds: Rect.fromLTRB(60, 1338, 495, 1389),
      ), // [OCR 추가]
      const ReceiptOcrCandidate(
        id: 'paid',
        text: '받은금액:',
        bounds: Rect.fromLTRB(61, 1398, 493, 1443),
      ), // [OCR 추가]
      const ReceiptOcrCandidate(
        id: 'card',
        text: '1.카드결제:',
        bounds: Rect.fromLTRB(65, 1569, 326, 1615),
      ), // [OCR 추가]
      const ReceiptOcrCandidate(
        id: 'price-label',
        text: '[금액]',
        bounds: Rect.fromLTRB(54, 1789, 226, 1843),
      ), // [OCR 추가]
    ]; // [OCR 추가]
    const quantity = ReceiptOcrCandidate(
      id: 'q',
      text: '1',
      number: 1,
      bounds: Rect.fromLTRB(478, 893, 493, 932),
    ); // [OCR 추가]
    const amount = ReceiptOcrCandidate(
      id: 'p',
      text: '12000',
      number: 12000,
      bounds: Rect.fromLTRB(959, 863, 1122, 917),
    ); // [OCR 추가]
    final source = fixture.source(names, [quantity, amount]); // [OCR 추가]
    final lines = automaticReceiptLines(
      source,
      const ReceiptAutomaticSeed(
        product: first,
        quantity: quantity,
        amount: amount,
        isUnitPrice: false,
      ),
    ); // [OCR 추가]
    expect(lines.map((line) => line.ocrProduct!.id), [
      'first',
      'pepsi',
      'ga',
      'gye',
    ]); // [OCR 추가]
    expect(source.products, hasLength(10)); // [OCR 추가]
  }); // [OCR 추가]
  for (final header in [false, true]) {
    // [OCR 추가]
    test('첫 이름 왼쪽 시작점의 한 글자 오차는 허용하고 이름 길이는 제한하지 않는다: header=$header', () {
      // [OCR 추가]
      final first = fixture.name('first', '퍼실', 60); // [OCR 추가]
      final inside = ReceiptOcrCandidate(
        id: 'inside',
        text: '짧은 이름',
        bounds: const Rect.fromLTWH(20, 100, 300, 20),
      ); // [OCR 추가]
      final edge = ReceiptOcrCandidate(
        id: 'edge',
        text: '경계 이름',
        bounds: const Rect.fromLTWH(30, 140, 120, 20),
      ); // [OCR 추가]
      final outside = ReceiptOcrCandidate(
        id: 'outside',
        text: '긴 안내',
        bounds: const Rect.fromLTWH(30.1, 180, 5, 20),
      ); // [OCR 추가]
      final quantity = fixture.number(
        'quantity',
        1,
        60,
        quantity: true,
      ); // [OCR 추가]
      final amount = fixture.number('amount', 1000, 60); // [OCR 추가]
      final base = fixture.source(
        [first, inside, edge, outside],
        [quantity, amount],
      ); // [OCR 추가]
      final source = ReceiptOcrResult(
        text: base.text,
        photoPath: base.photoPath,
        products: base.products,
        numbers: base.numbers, // [OCR 추가]
        rows: [
          ...base.rows,
          if (header)
            ReceiptOcrRow(
              id: 'header',
              text: '상품명 수량',
              bounds: Rect.fromLTWH(10, 30, 200, 20),
              tokens: [],
            ),
        ],
      ); // [OCR 추가]
      final lines = automaticReceiptLines(
        source,
        ReceiptAutomaticSeed(
          product: first,
          quantity: quantity,
          amount: amount,
          isUnitPrice: false,
        ),
      ); // [OCR 추가]
      expect(lines.map((line) => line.ocrProduct!.id), [
        'first',
        'inside',
        'edge',
      ]); // [OCR 추가]
      expect(
        source.products,
        hasLength(4),
      ); // [OCR 추가] 수동 선택에 사용할 원문 후보는 지우지 않는다.
    }); // [OCR 추가]
  } // [OCR 추가]
  test('교보 원본 실측의 이름 시작점 오차를 허용하고 긴 이름도 유지한다', () {
    // [OCR 추가]
    const first = ReceiptOcrCandidate(
      id: 'first',
      text: '포스트잇',
      bounds: Rect.fromLTRB(554, 2249, 1491, 2323),
    ); // [OCR 추가]
    const second = ReceiptOcrCandidate(
      id: 'second',
      text: '스티커 101',
      bounds: Rect.fromLTRB(516, 2451, 1565, 2536),
    ); // [OCR 추가]
    const third = ReceiptOcrCandidate(
      id: 'third',
      text: '스티커 112',
      bounds: Rect.fromLTRB(505, 2652, 1573, 2742),
    ); // [OCR 추가]
    const outside = ReceiptOcrCandidate(
      id: 'outside',
      text: '긴 상품명', // [OCR 수정]
      bounds: Rect.fromLTRB(500, 3000, 2000, 3100),
    ); // [OCR 추가]
    const quantity = ReceiptOcrCandidate(
      id: 'qty',
      text: '1',
      number: 1,
      bounds: Rect.fromLTRB(1631, 2341.5, 1711, 2441.5),
    ); // [OCR 추가]
    const amount = ReceiptOcrCandidate(
      id: 'amount',
      text: '9600',
      number: 9600,
      bounds: Rect.fromLTRB(1960, 2362, 2139, 2433),
    ); // [OCR 추가]
    final lines = automaticReceiptLines(
      fixture.source([first, second, third, outside], [quantity, amount]),
      ReceiptAutomaticSeed(
        product: first,
        quantity: quantity,
        amount: amount,
        isUnitPrice: false,
      ),
    ); // [OCR 추가]
    expect(lines.map((line) => line.ocrProduct!.id), [
      'first',
      'second',
      'third',
      'outside', // [OCR 수정] 시작점이 같은 긴 이름은 끝 위치와 무관하게 유지한다.
    ]); // [OCR 추가] 기존 실제 좌표의 후보 필터 재생이며 새 OCR 결과가 아니다.
  }); // [OCR 추가]
  test('실제 앨범 선택과 보정 적용 좌표에서 교보 둘째·셋째 이름을 유지한다', () {
    // [OCR 추가] 실제 ML Kit 결과의 경계 재생이다. 금액·수량 자동 인식 성공과 구분한다.
    const first = ReceiptOcrCandidate(
      id: 'gallery-first',
      text: '포스트잇',
      bounds: Rect.fromLTRB(165, 1399, 749, 1448),
    ); // [OCR 추가]
    const second = ReceiptOcrCandidate(
      id: 'gallery-second',
      text: '스티커미니 101',
      bounds: Rect.fromLTRB(143, 1514, 795, 1566),
    ); // [OCR 추가]
    const third = ReceiptOcrCandidate(
      id: 'gallery-third',
      text: '스티커미니 112',
      bounds: Rect.fromLTRB(138, 1634, 799, 1688),
    ); // [OCR 추가]
    final lines = automaticReceiptLines(
      fixture.source([first, second, third], []),
      ReceiptAutomaticSeed(
        product: first,
        quantity: fixture.number('quantity', 1, 1448, quantity: true),
        amount: fixture.number('amount', 9600, 1448),
        isUnitPrice: false,
      ),
    ); // [OCR 추가]
    expect(lines.map((line) => line.ocrProduct!.id), [
      first.id,
      second.id,
      third.id,
    ]); // [OCR 추가]
  }); // [OCR 추가]
  test('삼선짜장 실측 좌표에서는 제로펩시를 유지하고 긴 부가세 안내를 제외한다', () {
    // [OCR 추가]
    const first = ReceiptOcrCandidate(
      id: 'first',
      text: '삼선파장',
      bounds: Rect.fromLTRB(832, 1430, 1116, 1513),
    ); // [OCR 추가]
    const pepsi = ReceiptOcrCandidate(
      id: 'pepsi',
      text: '제로펩시',
      bounds: Rect.fromLTRB(826, 1608, 1113, 1697),
    ); // [OCR 추가]
    const notice = ReceiptOcrCandidate(
      id: 'notice',
      text: '부가세 과세 물품가액',
      bounds: Rect.fromLTRB(434, 1881, 1295, 1969),
    ); // [OCR 추가]
    const quantity = ReceiptOcrCandidate(
      id: 'qty',
      text: '1',
      number: 1,
      bounds: Rect.fromLTRB(1100, 1505, 1180, 1605),
    ); // [OCR 추가]
    const amount = ReceiptOcrCandidate(
      id: 'amount',
      text: '12000',
      number: 12000,
      bounds: Rect.fromLTRB(1865, 1485, 2110, 1585),
    ); // [OCR 추가]
    final lines = automaticReceiptLines(
      fixture.source([first, pepsi, notice], [quantity, amount]),
      ReceiptAutomaticSeed(
        product: first,
        quantity: quantity,
        amount: amount,
        isUnitPrice: false,
      ),
    ); // [OCR 추가]
    expect(lines.map((line) => line.ocrProduct!.id), [
      'first',
      'pepsi',
    ]); // [OCR 추가] 실측 좌표 재생 테스트이며 새로운 실제 OCR 호출은 아니다.
  }); // [OCR 추가]
  test('상품명 시작 열 밖 후보에는 부분 OCR을 호출하지 않는다', () async {
    // [OCR 추가]
    final first = fixture.name('first', '퍼실', 10); // [OCR 추가]
    final outside = shifted(first, 'outside', 100, 40); // [OCR 추가]
    final source = fixture.source(
      [first, outside],
      [
        fixture.number('q', 1, 10, quantity: true),
        fixture.number('p', 1000, 10),
      ],
    ); // [OCR 추가]
    var calls = 0; // [OCR 추가]
    final lines = await retry.read(source, (_, bounds) async {
      calls++;
      return '1';
    }); // [OCR 추가]
    expect(calls, 0); // [OCR 추가]
    expect(lines!.map((line) => line.ocrProduct!.id), ['first']); // [OCR 추가]
  }); // [OCR 추가]

  // [OCR 추가]
  test('시작 열 오차 안의 둘째·셋째 이름 각각에서 상대 위치 숫자를 연결한다', () {
    // [OCR 추가]
    final first = fixture.name('first', '퍼실', 10); // [OCR 추가]
    final q1 = fixture.number('q1', 3, 10, quantity: true); // [OCR 추가]
    final p1 = fixture.number('p1', 80940, 10); // [OCR 추가]
    final second = shifted(first, 'second', 20, 40, width: 40); // [OCR 추가]
    final third = shifted(first, 'third', -20, 100, width: 200); // [OCR 추가]
    final source = fixture.source(
      [fixture.name('header', '마트', 0), first, second, third],
      [
        // [OCR 추가]
        q1, p1, // [OCR 추가]
        shifted(q1, 'q2', 20, 40, value: 2),
        shifted(p1, 'p2', 20, 40, value: 15000), // [OCR 추가]
        shifted(q1, 'q3', -20, 100, value: 1),
        shifted(p1, 'p3', -20, 100, value: 9000), // [OCR 추가]
        shifted(q1, 'wrong-q2', -60, 40, value: 9),
        shifted(p1, 'wrong-p2', -60, 40, value: 70000), // [OCR 추가]
      ],
    ); // [OCR 추가]
    final lines = automaticReceiptLines(
      source,
      ReceiptAutomaticSeed(
        product: first, // [OCR 추가] 앞의 매장명이 아니라 사용자가 고른 첫 상품을 기준으로 삼는다.
        quantity: q1, // [OCR 추가]
        amount: p1, // [OCR 추가]
        isUnitPrice: false, // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    expect(lines.map((line) => line.ocrProduct!.id), [
      'first',
      'second',
      'third',
    ]); // [OCR 추가]
    expect(lines.map((line) => line.quantity), [3, 2, 1]); // [OCR 추가]
    expect(lines.map((line) => line.total), [80940, 15000, 9000]); // [OCR 추가]
    expect(lines.every((line) => line.selected), isTrue); // [OCR 추가]
    expect(lines[1].ocrQuantity!.id, 'q2'); // [OCR 추가]
    expect(lines[1].ocrAmount!.id, 'p2'); // [OCR 추가]
  }); // [OCR 추가]

  test('금액이 잘못된 열에 있어도 수량은 해당 상품명과의 상대 거리로 얻는다', () {
    // [OCR 추가]
    final first = fixture.name('first', '퍼실', 10); // [OCR 추가]
    final q1 = fixture.number('q1', 3, 10, quantity: true); // [OCR 추가]
    final p1 = fixture.number('p1', 80940, 10); // [OCR 추가]
    final second = shifted(first, 'second', 20, 40, width: 40); // [OCR 추가]
    final source = fixture.source(
      [first, second],
      [
        q1, p1, // [OCR 추가]
        shifted(q1, 'q2', 20, 40, value: 2),
        shifted(p1, 'wrong-p2', -60, 40, value: 70000), // [OCR 추가]
      ],
    ); // [OCR 추가]
    final lines = automaticReceiptLines(
      source,
      retry.seedFor(source),
    ); // [OCR 추가]
    expect(lines[1].quantity, 2); // [OCR 추가]
    expect(lines[1].ocrQuantity!.id, 'q2'); // [OCR 추가]
    expect(lines[1].ocrAmount, isNull); // [OCR 추가]
    expect(lines[1].selected, isFalse); // [OCR 추가]
  }); // [OCR 추가]

  for (final candidates in ['missing', 'old-column', 'relative']) {
    // [OCR 추가]
    test(
      '영역 재인식은 이름 길이와 시작점 오차를 허용하고 해당 이름에서 숫자 위치를 찾는다: $candidates',
      () async {
        // [OCR 추가]
        final first = fixture.name('first', '퍼실', 10); // [OCR 추가]
        final second = ReceiptOcrCandidate(
          id: 'second',
          text: '베지밀 두유 상품',
          bounds: const Rect.fromLTWH(30, 50, 200, 20),
        ); // [OCR 추가]
        final q1 = fixture.number('q1', 3, 10, quantity: true); // [OCR 추가]
        final p1 = fixture.number('p1', 80940, 10); // [OCR 추가]
        final source = fixture.source(
          [first, second],
          [
            q1, p1, // [OCR 추가]
            if (candidates == 'old-column') ...[
              // [OCR 추가]
              shifted(q1, 'wrong-q2', -60, 40, value: 9),
              shifted(p1, 'wrong-p2', -60, 40, value: 70000), // [OCR 추가]
            ], // [OCR 추가]
            if (candidates == 'relative') ...[
              // [OCR 추가]
              shifted(q1, 'q2', 20, 40, value: 2),
              shifted(p1, 'p2', 20, 40, value: 15000), // [OCR 추가]
            ], // [OCR 추가]
          ],
        ); // [OCR 추가]
        final bounds = <Rect>[]; // [OCR 추가]
        final lines = (await retry.read(source, (_, rect) async {
          // [OCR 추가]
          bounds.add(rect); // [OCR 추가]
          return rect.center.dx < 290 ? '2' : '15000'; // [OCR 추가]
        }))!; // [OCR 추가]
        expect(bounds.length, candidates == 'relative' ? 0 : 2); // [OCR 수정]
        final amountBounds = lines[1].ocrAmount!.bounds; // [OCR 수정]
        final quantityBounds = lines[1].ocrQuantity!.bounds; // [OCR 수정]
        expect(amountBounds.right, 364); // [OCR 추가]
        expect(amountBounds.center.dy, 60); // [OCR 추가]
        expect(quantityBounds.center.dx, 210); // [OCR 추가]
        expect(quantityBounds.center.dy, 60); // [OCR 추가]
        // [OCR 수정] 기존 후보와 추정 영역 모두 첫 수량 박스 크기를 그대로 쓰고 중심은 유지한다.
        expect(quantityBounds.width, q1.bounds.width + 8); // [OCR 수정]
        expect(quantityBounds.height, q1.bounds.height); // [OCR 수정]
        expect(lines[1].quantity, 2); // [OCR 추가]
        expect(lines[1].total, 15000); // [OCR 추가]
        expect(lines[1].selected, isTrue); // [OCR 추가]
        if (bounds.isNotEmpty) {
          // [OCR 수정]
          expect(amountBounds, bounds.first); // [OCR 수정]
          expect(quantityBounds, bounds[1]); // [OCR 수정]
        }
      },
    ); // [OCR 추가]
  } // [OCR 추가]
} // [OCR 추가]
