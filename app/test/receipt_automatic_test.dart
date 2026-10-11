import 'receipt_region_test.dart' show loadRegion; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_selection_screen.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]

ReceiptOcrCandidate name(String id, String text, double top) => // [OCR 추가]
ReceiptOcrCandidate(
  // [OCR 추가]
  id: id, // [OCR 추가]
  text: text, // [OCR 추가]
  bounds: Rect.fromLTWH(10, top, 100, 20), // [OCR 추가]
); // [OCR 추가]
ReceiptOcrCandidate number(
  // [OCR 추가]
  String id, // [OCR 추가]
  int value, // [OCR 추가]
  double top, { // [OCR 추가]
  bool quantity = false, // [OCR 추가]
}) => ReceiptOcrCandidate(
  // [OCR 추가]
  id: id, // [OCR 추가]
  text: '$value', // [OCR 추가]
  number: value, // [OCR 추가]
  bounds: Rect.fromLTWH(
    quantity ? 180 : 260,
    top,
    quantity ? 20 : 80,
    20,
  ), // [OCR 추가]
); // [OCR 추가]
ReceiptOcrResult source(
  // [OCR 추가]
  List<ReceiptOcrCandidate> names, // [OCR 추가]
  List<ReceiptOcrCandidate> numbers, // [OCR 추가]
) => ReceiptOcrResult(
  // [OCR 추가]
  text: '합성 OCR', // [OCR 추가]
  photoPath: '/missing.jpg', // [OCR 추가]
  rows: [
    // [OCR 추가]
    // [OCR 추가]
    for (final candidate in [...names, ...numbers]) // [OCR 추가]
      ReceiptOcrRow(
        // [OCR 추가]
        id: candidate.id, // [OCR 추가]
        text: candidate.text, // [OCR 추가]
        bounds: candidate.bounds, // [OCR 추가]
        tokens: [
          // [OCR 추가]
          ReceiptOcrToken(
            // [OCR 추가]
            id: candidate.id, // [OCR 추가]
            text: candidate.text, // [OCR 추가]
            bounds: candidate.bounds, // [OCR 추가]
          ), // [OCR 추가]
        ], // [OCR 추가]
      ), // [OCR 추가]
  ], // [OCR 추가]
  products: names, // [OCR 추가]
  numbers: numbers, // [OCR 추가]
); // [OCR 추가]
void main() {
  // [OCR 추가]
  // [OCR 추가]
  test('첫 총액·수량 기준 자동: 공백 뒤도 검색하고 안내·할인·누락은 체크 해제한다', () {
    // [OCR 추가]
    // [OCR 추가]
    final names = [
      // [OCR 추가]
      name('persil', '퍼실', 10), // [OCR 추가]
      name('milk', '베지밀', 50), // [OCR 추가]
      name('bleach', '유한락스', 130), // [OCR 추가]
      name('point', '포인트카드', 170), // [OCR 추가]
      name('card', '카드결제 안내', 210), // [OCR 추가]
      name('missing', '금액누락 상품', 250), // [OCR 추가]
    ]; // [OCR 추가]
    final numbers = [
      // [OCR 추가]
      number('q1', 3, 10, quantity: true), // [OCR 추가]
      number('p1', 80940, 10), // [OCR 추가]
      number('q2', 2, 50, quantity: true), // [OCR 추가]
      number('p2', 33760, 50), // [OCR 추가]
      number('q3', 1, 130, quantity: true), // [OCR 추가]
      number('p3', 8880, 130), // [OCR 추가]
      number('discount', -15000, 170), // [OCR 추가]
      number('footer', 320600, 210), // [OCR 추가]
    ]; // [OCR 추가]
    final lines = automaticReceiptLines(
      // [OCR 추가]
      source(names, numbers), // [OCR 추가]
      ReceiptAutomaticSeed(
        // [OCR 추가]
        product: names.first, // [OCR 추가]
        amount: numbers[1], // [OCR 추가]
        quantity: numbers.first, // [OCR 추가]
        isUnitPrice: false, // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      lines.map((line) => line.title), // [OCR 추가]
      names.map((name) => name.text), // [OCR 추가]
    ); // [OCR 추가]
    expect(lines.take(3).map((line) => line.total), [
      // [OCR 추가]
      80940, // [OCR 추가]
      33760, // [OCR 추가]
      8880, // [OCR 추가]
    ]); // [OCR 추가]
    expect(lines.first.unitPrice, 26980); // [OCR 추가]
    expect(lines.take(3).every((line) => line.selected), isTrue); // [OCR 추가]
    expect(lines.skip(3).every((line) => !line.selected), isTrue); // [OCR 추가]
    expect(lines.last.quantity, 0); // [OCR 추가]
  }); // [OCR 추가]
  test('스너글·스테비아 수량이 없으면 다음 칫솔·우유 수량을 가져오지 않는다', () {
    // [OCR 추가]
    // [OCR 추가]
    final names = [
      // [OCR 추가]
      name('persil', '퍼실', 10), // [OCR 추가]
      name('snuggle', '스너글', 50), // [OCR 추가]
      name('brush', '칫솔', 90), // [OCR 추가]
      name('stevia', '스테비아', 130), // [OCR 추가]
      name('milk', '우유', 170), // [OCR 추가]
    ]; // [OCR 추가]
    final numbers = [
      // [OCR 추가]
      number('q1', 3, 10, quantity: true), // [OCR 추가]
      number('p1', 80940, 10), // [OCR 추가]
      number('p2', 37960, 50), // [OCR 추가]
      number('q3', 1, 90, quantity: true), // [OCR 추가]
      number('p3', 12980, 90), // [OCR 추가]
      number('p4', 11980, 130), // [OCR 추가]
      number('q5', 2, 170, quantity: true), // [OCR 추가]
      number('p5', 19980, 170), // [OCR 추가]
    ]; // [OCR 추가]
    final lines = automaticReceiptLines(
      // [OCR 추가]
      source(names, numbers), // [OCR 추가]
      ReceiptAutomaticSeed(
        // [OCR 추가]
        product: names.first, // [OCR 추가]
        amount: numbers[1], // [OCR 추가]
        quantity: numbers.first, // [OCR 추가]
        isUnitPrice: false, // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    expect(lines[1].quantity, 0); // [OCR 추가]
    expect(lines[1].selected, isFalse); // [OCR 추가]
    expect(lines[1].total, 37960); // [OCR 추가]
    expect(lines[3].quantity, 0); // [OCR 추가]
    expect(lines[3].selected, isFalse); // [OCR 추가]
    expect(lines[3].total, 11980); // [OCR 추가]
    expect(lines[2].quantity, 1); // [OCR 추가]
    expect(lines[4].quantity, 2); // [OCR 추가]
  }); // [OCR 추가]
  test('단가 자동은 수량 선택 해제 시 1, 선택 시 같은 행 수량으로 총액을 계산한다', () {
    // [OCR 추가]
    // [OCR 추가]
    final names = [
      // [OCR 추가]
      name('first', '퍼실', 10), // [OCR 추가]
      name('next', '베지밀', 50), // [OCR 추가]
    ]; // [OCR 추가]
    final numbers = [
      // [OCR 추가]
      number('q1', 3, 10, quantity: true), // [OCR 추가]
      number('p1', 26980, 10), // [OCR 추가]
      number('q2', 2, 50, quantity: true), // [OCR 추가]
      number('p2', 16880, 50), // [OCR 추가]
    ]; // [OCR 추가]
    final result = source(names, numbers); // [OCR 추가]
    final one = automaticReceiptLines(
      // [OCR 추가]
      result, // [OCR 추가]
      ReceiptAutomaticSeed(
        // [OCR 추가]
        product: names.first, // [OCR 추가]
        amount: numbers[1], // [OCR 추가]
        isUnitPrice: true, // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    expect(one.map((line) => line.quantity), [1, 1]); // [OCR 추가]
    expect(one.map((line) => line.total), [26980, 16880]); // [OCR 추가]
    final many = automaticReceiptLines(
      // [OCR 추가]
      result, // [OCR 추가]
      ReceiptAutomaticSeed(
        // [OCR 추가]
        product: names.first, // [OCR 추가]
        amount: numbers[1], // [OCR 추가]
        quantity: numbers.first, // [OCR 추가]
        isUnitPrice: true, // [OCR 추가]
        includeQuantity: true, // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    expect(many.map((line) => line.quantity), [3, 2]); // [OCR 추가]
    expect(many.map((line) => line.total), [80940, 33760]); // [OCR 추가]
  }); // [OCR 추가]
  test('첫 수량이 다음 상품 행이면 거부하고 모호한 수량·가격은 확정하지 않는다', () {
    // [OCR 추가]
    // [OCR 추가]
    final names = [
      // [OCR 추가]
      name('first', '퍼실', 10), // [OCR 추가]
      name('next', '베지밀', 50), // [OCR 추가]
    ]; // [OCR 추가]
    final numbers = [
      // [OCR 추가]
      number('q1', 3, 10, quantity: true), // [OCR 추가]
      number('p1', 80940, 10), // [OCR 추가]
      number('q2', 1, 50, quantity: true), // [OCR 추가]
      number('q2b', 2, 50, quantity: true), // [OCR 추가]
      number('p2', 33760, 50), // [OCR 추가]
    ]; // [OCR 추가]
    final result = source(names, numbers); // [OCR 추가]
    expect(
      // [OCR 추가]
      () => automaticReceiptLines(
        // [OCR 추가]
        result, // [OCR 추가]
        ReceiptAutomaticSeed(
          // [OCR 추가]
          product: names.first, // [OCR 추가]
          amount: numbers[1], // [OCR 추가]
          quantity: numbers[2], // [OCR 추가]
          isUnitPrice: false, // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
      throwsFormatException, // [OCR 추가]
    ); // [OCR 추가]
    final lines = automaticReceiptLines(
      // [OCR 추가]
      result, // [OCR 추가]
      ReceiptAutomaticSeed(
        // [OCR 추가]
        product: names.first, // [OCR 추가]
        amount: numbers[1], // [OCR 추가]
        quantity: numbers.first, // [OCR 추가]
        isUnitPrice: false, // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    expect(lines.last.quantity, 0); // [OCR 추가]
    expect(lines.last.selected, isFalse); // [OCR 추가]
    final ambiguous = source(names, [
      // [OCR 추가]
      ...numbers, // [OCR 추가]
      number('p2b', 33760, 50), // [OCR 추가]
    ]); // [OCR 추가]
    expect(
      // [OCR 추가]
      automaticReceiptLines(
        // [OCR 추가]
        ambiguous, // [OCR 추가]
        ReceiptAutomaticSeed(
          // [OCR 추가]
          product: names.first, // [OCR 추가]
          amount: numbers[1], // [OCR 추가]
          quantity: numbers.first, // [OCR 추가]
          isUnitPrice: false, // [OCR 추가]
        ), // [OCR 추가]
      ).last.selected, // [OCR 추가]
      isFalse, // [OCR 추가]
    ); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('첫 수량을 다른 줄로 바꿔도 선택한 금액과 실행 버튼을 유지한다', (tester) async {
    // [OCR 추가] 실제 첫 기준 선택 화면에서 수량 변경이 금액 선택을 지우는 회귀를 검사한다.
    final product = name('first', '퍼실', 10);
    final q1 = number('q1', 3, 10, quantity: true);
    final q2 = number('q2', 3, 35, quantity: true);
    final amount = number('p1', 80940, 55);
    final draft = ReceiptDraft(
      id: 'independent-seed',
      store: '마트',
      purchasedOn: '2026-10-08',
      lines: [],
      ocrResult: source([product, name('next', '베지밀', 100)], [q1, q2, amount]),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReceiptSelectionScreen(draft: draft)),
    );
    await loadRegion(tester);
    Future<void> tap(Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        100,
        scrollable: find.byType(Scrollable).last,
      ); // [OCR 수정]
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap(find.byKey(const ValueKey('ocr-candidate-first')));
    await tap(find.byKey(const ValueKey('ocr-candidate-q1')));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ocr-candidate-p1')),
      100,
      scrollable: find.byType(Scrollable).last,
    ); // [OCR 추가]
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ocr-candidate-p1')), findsOneWidget);
    await tap(find.byKey(const ValueKey('ocr-candidate-p1')));
    await tap(find.byKey(const ValueKey('ocr-seed-수량')));
    await tap(find.byKey(const ValueKey('ocr-candidate-q2')));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ocr-candidate-p1')),
      100,
      scrollable: find.byType(Scrollable).last,
    ); // [OCR 추가]
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ocr-candidate-p1')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '끝까지 자동 선택'),
    );
    expect(button.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  }); // [OCR 추가]
  test('첫 수량의 행이 달라도 같은 상품의 금액 후보는 유지한다', () {
    // [OCR 추가] 수량·금액을 서로 다른 줄에 인식한 첫 상품과 다음 상품을 재현한다.
    final product = name('first', '퍼실', 10);
    final nextProduct = name('next', '베지밀', 100);
    final q1 = number('q1', 3, 10, quantity: true);
    final q2 = number('q2', 3, 35, quantity: true);
    final amount = number('p1', 80940, 55);
    final nextAmount = number('p2', 33760, 100);
    final result = source([product, nextProduct], [q1, q2, amount, nextAmount]);
    for (final quantity in [q1, q2]) {
      final candidates = receiptAutomaticAmountsNear(
        result,
        product,
        quantity: quantity,
      );
      expect(candidates.map((c) => c.id), contains(amount.id));
      expect(candidates.map((c) => c.id), isNot(contains(nextAmount.id)));
      expect(candidates.map((c) => c.id), isNot(contains(quantity.id)));
    }
    final lines = automaticReceiptLines(
      result,
      ReceiptAutomaticSeed(
        product: product,
        amount: amount,
        quantity: q1,
        isUnitPrice: false,
      ),
    );
    expect(lines.first.quantity, 3);
    expect(lines.first.total, 80940);
  }); // [OCR 추가]
  test('자동 금액 후보는 상품명으로 좁히며 수량 자체·다음 상품 행을 제외한다', () {
    // [OCR 수정]
    // [OCR 추가]
    final product = name('first', '퍼실', 10); // [OCR 추가]
    final quantity = number('quantity', 3, 10, quantity: true); // [OCR 추가]
    final amount = number('amount', 80940, 10); // [OCR 추가]
    final nextAmount = number('next', 33760, 50); // [OCR 추가]
    const left = ReceiptOcrCandidate(
      // [OCR 수정]
      id: 'left', // [OCR 수정]
      text: '100', // [OCR 수정]
      number: 100, // [OCR 수정]
      bounds: Rect.fromLTWH(0, 10, 8, 20), // [OCR 수정]
    ); // [OCR 추가]
    final candidates = receiptAutomaticAmountsNear(
      // [OCR 수정]
      source(
        [product, name('next-product', '베지밀', 50)],
        [quantity, amount, nextAmount, left],
      ), // [OCR 수정]
      product, // [OCR 수정]
      quantity: quantity, // [OCR 수정]
    ); // [OCR 추가]
    expect(candidates.map((candidate) => candidate.id), ['amount']); // [OCR 추가]
  }); // [OCR 추가]
  test('자동 연결은 첫 세 영역의 상대 위치를 유지하고 다른 행·다른 금액 열은 체크하지 않는다', () {
    // [OCR 수정]
    // [OCR 추가]
    final names = [
      // [OCR 수정]
      name('first', '퍼실', 10), // [OCR 수정]
      name('second', '베지밀', 50), // [OCR 수정]
      name('wrong', '다른 열 금액', 90), // [OCR 수정]
    ]; // [OCR 추가]
    final firstQuantity = number('q1', 3, 10, quantity: true); // [OCR 추가]
    final firstAmount = number('p1', 80940, 10); // [OCR 추가]
    final secondQuantity = ReceiptOcrCandidate(
      // [OCR 수정]
      id: 'q2', // [OCR 수정]
      text: '2', // [OCR 수정]
      number: 2, // [OCR 수정]
      bounds: firstQuantity.bounds.shift(const Offset(28, 40)), // [OCR 수정]
    ); // [OCR 추가]
    final secondAmount = ReceiptOcrCandidate(
      // [OCR 수정]
      id: 'p2', // [OCR 수정]
      text: '33760', // [OCR 수정]
      number: 33760, // [OCR 수정]
      bounds: firstAmount.bounds.shift(const Offset(28, 40)), // [OCR 수정]
    ); // [OCR 추가]
    final other = ReceiptOcrCandidate(
      // [OCR 수정]
      id: 'other', // [OCR 수정]
      text: '9000', // [OCR 수정]
      number: 9000, // [OCR 수정]
      bounds: firstAmount.bounds.shift(const Offset(-100, 80)), // [OCR 수정]
    ); // [OCR 추가]
    final lines = automaticReceiptLines(
      // [OCR 수정]
      source(names, [
        // [OCR 수정]
        firstQuantity, // [OCR 수정]
        firstAmount, // [OCR 수정]
        secondQuantity, // [OCR 수정]
        secondAmount, // [OCR 수정]
        other, // [OCR 수정]
      ]), // [OCR 수정]
      ReceiptAutomaticSeed(
        // [OCR 수정]
        product: names.first, // [OCR 수정]
        amount: firstAmount, // [OCR 수정]
        quantity: firstQuantity, // [OCR 수정]
        isUnitPrice: false, // [OCR 수정]
      ), // [OCR 수정]
    ); // [OCR 추가]
    expect(lines.map((line) => line.selected), [true, true, false]); // [OCR 추가]
    expect(lines[1].quantity, 2); // [OCR 추가]
    expect(lines[1].total, 33760); // [OCR 추가]
  }); // [OCR 추가]

  for (final size in [const Size(360, 640), const Size(480, 900)]) {
    // [OCR 추가]
    testWidgets('긴 후보 목록에서도 자동 입력 선택이 첫 화면에 보인다: $size', (tester) async {
      // [OCR 추가]
      tester.view.physicalSize = size; // [OCR 추가]
      tester.view.devicePixelRatio = 1; // [OCR 추가]
      addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
      addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
      final names = [
        for (var index = 0; index < 60; index++)
          name('long-$index', '길이가 다른 상품명 후보 $index', 10 + index * 50),
      ]; // [OCR 추가]
      final draft = ReceiptDraft(
        id: 'visibility',
        store: '',
        purchasedOn: '2026-10-06',
        lines: [],
        ocrResult: source(names, []),
      ); // [OCR 추가]
      await tester.pumpWidget(
        MaterialApp(home: ReceiptSelectionScreen(draft: draft)),
      ); // [OCR 추가]
      await loadRegion(tester); // [OCR 추가]
      final automatic = find.byKey(
        const ValueKey('ocr-automatic-names'),
      ); // [OCR 수정] // [OCR 추가]
      expect(automatic.hitTestable(), findsOneWidget); // [OCR 추가]
      final manual = find.byKey(const ValueKey('ocr-manual-names')); // [OCR 추가]
      final mode = find.byKey(
        const ValueKey('ocr-unit-price-toggle'),
      ); // [OCR 수정]
      expect(find.byType(SwitchListTile), findsOneWidget); // [OCR 수정]
      expect(tester.widget<SwitchListTile>(mode).value, isFalse); // [OCR 수정]
      expect(tester.getSize(manual), tester.getSize(automatic)); // [OCR 추가]
      expect(
        tester.getRect(manual).top,
        tester.getRect(automatic).top,
      ); // [OCR 추가]
      expect(
        tester.getRect(manual).left,
        tester.getRect(mode).left,
      ); // [OCR 수정]
      expect(
        tester.getRect(automatic).right,
        tester.getRect(mode).right,
      ); // [OCR 수정]
      final list = tester.widget<ListView>(find.byType(ListView)); // [OCR 추가]
      expect(list.controller!.offset, 0); // [OCR 추가]
      expect(
        // [OCR 수정]
        find.text('첫 상품명·수량·금액 선택').evaluate().isNotEmpty, // [OCR 수정]
        isTrue, // [OCR 수정]
      ); // [OCR 추가]
      await tester.tap(
        find.byKey(const ValueKey('ocr-manual-names')),
      ); // [OCR 수정]
      await tester.pumpAndSettle(); // [OCR 추가]
      expect(
        find.text('첫 상품명·수량·금액 선택').evaluate().isNotEmpty,
        isFalse, // [OCR 수정]
      ); // [OCR 추가]
      expect(
        find.text('상품명 전체 수동 선택'),
        findsOneWidget, // [OCR 수정]
      ); // [OCR 추가]
      await tester.tap(automatic); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      expect(
        find.text('첫 상품명·수량·금액 선택').evaluate().isNotEmpty,
        isTrue, // [OCR 수정]
      ); // [OCR 추가]
      expect(automatic.hitTestable(), findsOneWidget); // [OCR 추가]
      expect(tester.takeException(), isNull); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  for (final mode in [(false, true), (true, true)]) {
    // [OCR 추가]
    // [OCR 추가]
    final unit = mode.$1; // [OCR 추가]
    final includeQuantity = mode.$2; // [OCR 추가]
    testWidgets('전체 자동 UI: 단가=$unit, 수량 자동=$includeQuantity', (tester) async {
      // [OCR 추가]
      // [OCR 추가]
      final names = [
        // [OCR 추가]
        name('first', '퍼실', 10), // [OCR 추가]
        name('next', '베지밀', 50), // [OCR 추가]
      ]; // [OCR 추가]
      final numbers = [
        // [OCR 추가]
        number('q1', 3, 10, quantity: true), // [OCR 추가]
        number('p1', unit ? 26980 : 80940, 10), // [OCR 추가]
        number('q2', 2, 50, quantity: true), // [OCR 추가]
        number('p2', unit ? 16880 : 33760, 50), // [OCR 추가]
      ]; // [OCR 추가]
      ReceiptDraft? returned; // [OCR 추가]
      final draft = ReceiptDraft(
        // [OCR 추가]
        id: 'auto', // [OCR 추가]
        store: '마트', // [OCR 추가]
        purchasedOn: '2026-10-06', // [OCR 추가]
        lines: [], // [OCR 추가]
        ocrResult: source(names, numbers), // [OCR 추가]
      ); // [OCR 추가]
      await tester.pumpWidget(
        // [OCR 추가]
        MaterialApp(
          // [OCR 추가]
          home: Builder(
            // [OCR 추가]
            builder: (context) => Scaffold(
              // [OCR 추가]
              body: TextButton(
                // [OCR 추가]
                child: const Text('열기'), // [OCR 추가]
                onPressed: () async {
                  // [OCR 추가]
                  returned = await Navigator.push<ReceiptDraft>(
                    // [OCR 추가]
                    context, // [OCR 추가]
                    MaterialPageRoute(
                      // [OCR 추가]
                      builder: (_) =>
                          ReceiptSelectionScreen(draft: draft), // [OCR 추가]
                    ), // [OCR 추가]
                  ); // [OCR 추가]
                }, // [OCR 추가]
              ), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ); // [OCR 추가]
      await tester.tap(find.text('열기')); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
      for (var i = 0; i < 5; i++) {
        // [OCR 추가]
        await tester.runAsync(() async {
          // [OCR 추가]
          await Future<void>.delayed(
            const Duration(milliseconds: 20),
          ); // [OCR 추가]
        }); // [OCR 추가]
        await tester.pump(); // [OCR 추가]
      } // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      Future<void> tap(Finder finder) async {
        // [OCR 추가]
        // [OCR 추가]
        await tester.scrollUntilVisible(
          // [OCR 추가]
          finder, // [OCR 추가]
          100, // [OCR 추가]
          scrollable: find.byType(Scrollable).last, // [OCR 추가]
        ); // [OCR 추가]
        await tester.pumpAndSettle(); // [OCR 추가]
        await tester.tap(finder); // [OCR 추가]
        await tester.pumpAndSettle(); // [OCR 추가]
      } // [OCR 추가]

      expect(
        // [OCR 수정]
        find.text('첫 상품명·수량·금액 선택').evaluate().isNotEmpty, // [OCR 수정]
        isTrue, // [OCR 수정]
      ); // [OCR 수정]
      for (final field in ['상품명', '수량', '금액']) {
        // [OCR 추가]
        expect(
          find.byKey(ValueKey('ocr-seed-$field')),
          findsOneWidget,
        ); // [OCR 추가]
      } // [OCR 추가]
      if (unit) {
        // [OCR 수정]
        await tap(
          find.byKey(const ValueKey('ocr-unit-price-toggle')),
        ); // [OCR 수정]
      } // [OCR 수정]
      tester // [OCR 추가]
          .state<ScrollableState>(find.byType(Scrollable).last) // [OCR 추가]
          .position // [OCR 추가]
          .jumpTo(0); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      await tap(find.byKey(const ValueKey('ocr-candidate-first'))); // [OCR 추가]
      // [OCR 수정] 세 입력 칸을 동시에 제시하고, 수량·금액이 없으면 자동 실행을 막는다.
      for (final field in ['상품명', '수량', '금액']) {
        // [OCR 추가]
        expect(
          find.byKey(ValueKey('ocr-seed-$field')),
          findsOneWidget,
        ); // [OCR 추가]
      } // [OCR 추가]
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '끝까지 자동 선택'),
            )
            .onPressed,
        isNull,
      ); // [OCR 수정]
      await tap(find.byKey(const ValueKey('ocr-candidate-q1'))); // [OCR 추가]
      if (unit) {
        // [OCR 추가]
        await tap(find.byKey(const ValueKey('ocr-quantity-up'))); // [OCR 추가]
        expect(
          find.byKey(const ValueKey('ocr-edit-value')),
          findsNothing,
        ); // [OCR 추가]
        expect(find.text('4개'), findsOneWidget); // [OCR 추가]
      } // [OCR 추가]
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '끝까지 자동 선택'),
            )
            .onPressed,
        isNull,
      ); // [OCR 추가]
      expect(
        // [OCR 수정]
        find.byKey(const ValueKey('ocr-candidate-p2')), // [OCR 수정]
        findsNothing, // [OCR 수정]
      ); // [OCR 추가]
      await tap(find.byKey(const ValueKey('ocr-candidate-p1'))); // [OCR 추가]
      await tester.tap(find.text('끝까지 자동 선택')); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      expect(
        // [OCR 추가]
        returned!.lines.map((line) => line.quantity), // [OCR 추가]
        unit ? [4, 2] : [3, 2], // [OCR 수정]
      ); // [OCR 추가]
      expect(
        // [OCR 추가]
        returned!.lines.map((line) => line.total), // [OCR 추가]
        unit ? [107920, 33760] : [80940, 33760], // [OCR 수정]
      ); // [OCR 추가]
      expect(draft.lines, isEmpty); // [OCR 추가]
      expect(tester.takeException(), isNull); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]
} // [OCR 추가]
