import 'dart:async'; // [OCR 추가]
import 'dart:convert'; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:shared_preferences/shared_preferences.dart'; // [OCR 추가]
import 'package:how_much/app_store.dart'; // [OCR 추가]
import 'package:how_much/app_theme.dart'; // [OCR 추가]
import 'package:how_much/cloud_service.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/receipt_amount.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_selection_screen.dart'; // [OCR 추가]
import 'package:how_much/screens.dart'; // [OCR 추가]

class AmountTestCloud extends CloudService {
  // [OCR 추가]
  // [OCR 추가]
  AmountTestCloud() : super(true); // [OCR 추가]
  final changes = StreamController<String?>.broadcast(); // [OCR 추가]
  final remote = <AppRow>[]; // [OCR 추가]
  bool offline = true; // [OCR 추가]
  @override // [OCR 추가]
  String? get accountId => 'amount-account'; // [OCR 추가]
  @override // [OCR 추가]
  bool get canSync => true; // [OCR 추가]
  @override // [OCR 추가]
  Stream<String?> get authChanges => changes.stream; // [OCR 추가]
  @override // [OCR 추가]
  Future<SyncExchangeResult> exchange(List<AppRow> local) async {
    // [OCR 추가]
    // [OCR 추가]
    if (offline) throw StateError('기기 기록은 유지됩니다.'); // [OCR 추가]
    // [OCR 추가] 모의 전송도 JSON을 왕복시켜 기존 직렬화 과정에서 수량·총액이 보존되는지 확인한다.
    final decoded = // [OCR 추가]
        (jsonDecode(
                  jsonEncode(local.map((row) => row.toJson()).toList()),
                ) // [OCR 추가]
                as List) // [OCR 추가]
            .map(
              // [OCR 추가]
              (row) => AppRow.fromJson(
                Map<String, Object?>.from(row as Map),
              ), // [OCR 추가]
            ) // [OCR 추가]
            .toList(); // [OCR 추가]
    final result = reconcileRows(remote, decoded); // [OCR 추가]
    remote // [OCR 추가]
      ..clear() // [OCR 추가]
      ..addAll(result.rows); // [OCR 추가]
    return result; // [OCR 추가]
  } // [OCR 추가]
} // [OCR 추가]

ReceiptDraft amountDraft(ReceiptLineDraft line) => ReceiptDraft(
  // [OCR 추가]
  id: 'amount-test', // [OCR 추가]
  store: '마트', // [OCR 추가]
  purchasedOn: '2026-10-06', // [OCR 추가]
  lines: [line], // [OCR 추가]
); // [OCR 추가]
ReceiptDraft selectionDraft() {
  // [OCR 추가]
  // [OCR 추가]
  final tokens = [
    // [OCR 추가]
    // [OCR 추가]
    const ReceiptOcrToken(
      // [OCR 추가]
      id: 'name', // [OCR 추가]
      text: '퍼실', // [OCR 추가]
      bounds: Rect.fromLTWH(100, 100, 60, 20), // [OCR 추가]
    ), // [OCR 추가]
    const ReceiptOcrToken(
      // [OCR 추가]
      id: 'quantity', // [OCR 추가]
      text: '3', // [OCR 추가]
      bounds: Rect.fromLTWH(200, 100, 20, 20), // [OCR 추가]
    ), // [OCR 추가]
    const ReceiptOcrToken(
      // [OCR 추가]
      id: 'price', // [OCR 추가]
      text: '80,940', // [OCR 추가]
      bounds: Rect.fromLTWH(300, 100, 80, 20), // [OCR 추가]
    ), // [OCR 추가]
  ]; // [OCR 추가]
  final draft = amountDraft(
    // [OCR 추가]
    ReceiptLineDraft(id: 'old', title: '원본', total: 10), // [OCR 추가]
  ); // [OCR 추가]
  draft.ocrResult = buildReceiptOcrResult(
    // [OCR 추가]
    text: '퍼실 3 80,940', // [OCR 추가]
    photoPath: '/missing-stage3.jpg', // [OCR 추가]
    rows: [
      // [OCR 추가]
      ReceiptOcrRow(
        // [OCR 추가]
        id: 'row', // [OCR 추가]
        text: '퍼실 3 80,940', // [OCR 추가]
        bounds: const Rect.fromLTWH(100, 100, 280, 20), // [OCR 추가]
        tokens: tokens, // [OCR 추가]
      ), // [OCR 추가]
    ], // [OCR 추가]
  ); // [OCR 추가]
  return draft; // [OCR 추가]
} // [OCR 추가]

Future<void> showCandidate(WidgetTester tester, String id) async {
  // [OCR 추가]
  // [OCR 추가]
  final finder = find.byKey(ValueKey('ocr-candidate-$id')); // [OCR 추가]
  await tester.scrollUntilVisible(
    // [OCR 추가]
    finder, // [OCR 추가]
    120, // [OCR 추가]
    scrollable: find.byType(Scrollable).last, // [OCR 추가]
  ); // [OCR 추가]
  await tester.pumpAndSettle(); // [OCR 수정]
  await tester.tap(finder); // [OCR 추가]
  await tester.pump(); // [OCR 추가]
} // [OCR 추가]

Future<void> startSelection(
  // [OCR 추가]
  WidgetTester tester, // [OCR 추가]
  ReceiptDraft draft, // [OCR 추가]
  ValueChanged<ReceiptDraft?> onReturn, // [OCR 추가]
) async {
  // [OCR 추가]
  // [OCR 추가]
  await tester.pumpWidget(
    // [OCR 추가]
    MaterialApp(
      // [OCR 추가]
      theme: buildAppTheme(), // [OCR 추가]
      home: Builder(
        // [OCR 추가]
        builder: (context) => TextButton(
          // [OCR 추가]
          onPressed: () async {
            // [OCR 추가]
            onReturn(
              // [OCR 추가]
              await Navigator.push<ReceiptDraft>(
                // [OCR 추가]
                context, // [OCR 추가]
                MaterialPageRoute(
                  // [OCR 추가]
                  builder: (_) =>
                      ReceiptSelectionScreen(draft: draft), // [OCR 추가]
                ), // [OCR 추가]
              ), // [OCR 추가]
            ); // [OCR 추가]
          }, // [OCR 추가]
          child: const Text('열기'), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ), // [OCR 추가]
  ); // [OCR 추가]
  await tester.tap(find.text('열기')); // [OCR 추가]
  await tester.pumpAndSettle(); // [OCR 추가]
  await tester.tap(
    // [OCR 수정]
    find.byKey(const ValueKey('ocr-manual-names')), // [OCR 수정]
  ); // [OCR 추가] 직접 입력 회귀는 수동 흐름으로 검사한다.
  await tester.pumpAndSettle(); // [OCR 추가]
  await showCandidate(tester, 'name'); // [OCR 추가]
  await tester.tap(find.text('상품명 선택 완료 (1개)')); // [OCR 추가]
  await tester.pump(); // [OCR 추가]
} // [OCR 추가]

void main() {
  // [OCR 추가]
  // [OCR 추가]
  setUp(() => SharedPreferences.setMockInitialValues({})); // [OCR 추가]
  test('단가/총액 어느 입력 방식이든 수량 3의 결제금액·개당 가격이 일치한다', () {
    // [OCR 추가]
    // [OCR 추가]
    final unit = receiptLineFromAmount(
      // [OCR 추가]
      id: 'unit', // [OCR 추가]
      title: '퍼실', // [OCR 추가]
      amount: 26980, // [OCR 추가]
      quantity: 3, // [OCR 추가]
      isUnitPrice: true, // [OCR 추가]
    ); // [OCR 추가]
    final total = receiptLineFromAmount(
      // [OCR 추가]
      id: 'total', // [OCR 추가]
      title: '퍼실', // [OCR 추가]
      amount: 80940, // [OCR 추가]
      quantity: 3, // [OCR 추가]
      isUnitPrice: false, // [OCR 추가]
    ); // [OCR 추가]
    expect(unit.total, 80940); // [OCR 추가]
    expect(total.total, 80940); // [OCR 추가]
    expect(unit.unitPrice, 26980); // [OCR 추가]
    expect(total.unitPrice, 26980); // [OCR 추가]
    expect(
      // [OCR 추가]
      receiptLineFromAmount(
        // [OCR 추가]
        id: 'default', // [OCR 추가]
        title: '상품', // [OCR 추가]
        amount: 5000, // [OCR 추가]
        isUnitPrice: true, // [OCR 추가]
      ).quantity, // [OCR 추가]
      1, // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      receiptLineFromAmount(
        // [OCR 추가]
        id: 'a', // [OCR 추가]
        title: '상품', // [OCR 추가]
        amount: 5000, // [OCR 추가]
        quantity: 3, // [OCR 추가]
        isUnitPrice: true, // [OCR 추가]
      ).total, // [OCR 추가]
      15000, // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      receiptLineFromAmount(
        // [OCR 추가]
        id: 'b', // [OCR 추가]
        title: '상품', // [OCR 추가]
        amount: 15000, // [OCR 추가]
        quantity: 3, // [OCR 추가]
        isUnitPrice: false, // [OCR 추가]
      ).unitPrice, // [OCR 추가]
      5000, // [OCR 추가]
    ); // [OCR 추가]
  }); // [OCR 추가]
  test('총액의 수량 누락·잘못된 수량·음수·곱셈 한도 초과를 거부한다', () {
    // [OCR 추가]
    // [OCR 추가]
    expect(
      // [OCR 추가]
      () => receiptLineFromAmount(
        // [OCR 추가]
        id: 'missing', // [OCR 추가]
        title: '상품', // [OCR 추가]
        amount: 15000, // [OCR 추가]
        isUnitPrice: false, // [OCR 추가]
      ), // [OCR 추가]
      throwsFormatException, // [OCR 추가]
    ); // [OCR 추가]
    for (final quantity in [0, -1, 1000]) {
      // [OCR 추가]
      // [OCR 추가]
      expect(
        // [OCR 추가]
        () => receiptLineFromAmount(
          // [OCR 추가]
          id: 'invalid', // [OCR 추가]
          title: '상품', // [OCR 추가]
          amount: 5000, // [OCR 추가]
          quantity: quantity, // [OCR 추가]
          isUnitPrice: true, // [OCR 추가]
        ), // [OCR 추가]
        throwsFormatException, // [OCR 추가]
      ); // [OCR 추가]
    } // [OCR 추가]
    expect(
      // [OCR 추가]
      () => receiptLineFromAmount(
        // [OCR 추가]
        id: 'negative', // [OCR 추가]
        title: '상품', // [OCR 추가]
        amount: -15000, // [OCR 추가]
        quantity: 3, // [OCR 추가]
        isUnitPrice: false, // [OCR 추가]
      ), // [OCR 추가]
      throwsFormatException, // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      () => receiptLineFromAmount(
        // [OCR 추가]
        id: 'overflow', // [OCR 추가]
        title: '상품', // [OCR 추가]
        amount: 9999999, // [OCR 추가]
        quantity: 2, // [OCR 추가]
        isUnitPrice: true, // [OCR 추가]
      ), // [OCR 추가]
      throwsFormatException, // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      ReceiptLineDraft(
        // [OCR 추가]
        id: 'invalid', // [OCR 추가]
        title: '상품', // [OCR 추가]
        quantity: 0, // [OCR 추가]
        total: 15000, // [OCR 추가]
      ).unitPrice, // [OCR 추가]
      isNull, // [OCR 추가]
    ); // [OCR 추가]
  }); // [OCR 추가]
  test('develop 저장·재실행·모의 동기화 왕복, 서버 실패 후 수량·총액 보존', () async {
    // [OCR 추가]
    // [OCR 추가]
    final cloud = AmountTestCloud(); // [OCR 추가]
    final store = AppStore(cloud); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    addTearDown(cloud.changes.close); // [OCR 추가]
    await store.initialize(); // [OCR 추가]
    await store.saveReceipt(
      // [OCR 추가]
      amountDraft(
        // [OCR 추가]
        receiptLineFromAmount(
          // [OCR 추가]
          id: 'persil', // [OCR 추가]
          title: '퍼실', // [OCR 추가]
          amount: 26980, // [OCR 추가]
          quantity: 3, // [OCR 추가]
          isUnitPrice: true, // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await store.sync(); // [OCR 추가]
    expect(store.purchaseRows.single.purchase!.quantity, 3); // [OCR 추가]
    expect(store.purchaseRows.single.purchase!.total, 80940); // [OCR 추가]
    expect(store.pendingCount, 1); // [OCR 추가]
    final restored = AppStore(cloud); // [OCR 추가]
    addTearDown(restored.dispose); // [OCR 추가]
    await restored.initialize(); // [OCR 추가]
    expect(restored.purchaseRows.single.purchase!.unitPrice, 26980); // [OCR 추가]
    cloud.offline = false; // [OCR 추가]
    await restored.sync(); // [OCR 추가]
    final saved = cloud.remote.single.purchase!; // [OCR 추가]
    expect(saved.quantity, 3); // [OCR 추가]
    expect(saved.total, 80940); // [OCR 추가]
    expect(saved.unitPrice, 26980); // [OCR 추가]
    expect(saved.toJson().containsKey('discount'), isFalse); // [OCR 추가]
    expect(restored.pendingCount, 0); // [OCR 추가]
  }); // [OCR 추가]
  test('수량 0을 저장하려 하면 기존 기록과 로컬 스냅샷을 바꾸지 않는다', () async {
    // [OCR 추가]
    // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    await store.initialize(); // [OCR 추가]
    await store.saveReceipt(
      // [OCR 추가]
      amountDraft(
        // [OCR 추가]
        receiptLineFromAmount(
          // [OCR 추가]
          id: 'valid', // [OCR 추가]
          title: '퍼실', // [OCR 추가]
          amount: 80940, // [OCR 추가]
          quantity: 3, // [OCR 추가]
          isUnitPrice: false, // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    final before = jsonEncode(
      // [OCR 추가]
      store.rows.map((row) => row.toJson()).toList(), // [OCR 추가]
    ); // [OCR 추가]
    final invalid = ReceiptDraft(
      // [OCR 추가]
      id: 'invalid', // [OCR 추가]
      store: '마트', // [OCR 추가]
      purchasedOn: '2026-10-06', // [OCR 추가]
      lines: [
        // [OCR 추가]
        ReceiptLineDraft(
          id: 'zero',
          title: '상품',
          quantity: 0,
          total: 5000,
        ), // [OCR 추가]
      ], // [OCR 추가]
    ); // [OCR 추가]
    await expectLater(
      // [OCR 추가]
      store.saveReceipt(invalid), // [OCR 추가]
      throwsFormatException, // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      jsonEncode(store.rows.map((row) => row.toJson()).toList()), // [OCR 추가]
      before, // [OCR 추가]
    ); // [OCR 추가]
    final restored = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(restored.dispose); // [OCR 추가]
    await restored.initialize(); // [OCR 추가]
    expect(restored.purchaseRows.single.purchase!.unitPrice, 26980); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('금액은 기본 수량 1개로 진행하며 수량 후보를 길게 눌러 수정·취소한다', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    ReceiptDraft? selected; // [OCR 추가]
    final draft = selectionDraft(); // [OCR 추가]
    await startSelection(
      // [OCR 추가]
      tester, // [OCR 추가]
      draft, // [OCR 추가]
      (value) => selected = value, // [OCR 추가]
    ); // [OCR 추가]
    await showCandidate(tester, 'price'); // [OCR 추가]
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('ocr-unit-price-toggle')),
          )
          .value,
      isFalse,
    ); // [OCR 수정]
    await tester.tap(find.text('수량 확인')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(
      // [OCR 추가]
      tester // [OCR 추가]
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '선택한 항목 검토'),
          ) // [OCR 추가]
          .onPressed, // [OCR 추가]
      isNotNull, // [OCR 수정] 기본 수량 1개로 확인할 수 있다. // [OCR 추가]
    ); // [OCR 추가]
    await showCandidate(tester, 'quantity'); // [OCR 추가]
    await tester.longPress(
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-candidate-quantity')), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      find.byKey(const ValueKey('ocr-edit-value')),
      '2',
    ); // [OCR 추가]
    await tester.tap(find.text('취소')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      find.widgetWithText(OutlinedButton, '3개'),
      findsOneWidget,
    ); // [OCR 수정] 화살표 표시와 OCR 후보를 구분한다. // [OCR 추가]
    await tester.longPress(
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-candidate-quantity')), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      find.byKey(const ValueKey('ocr-edit-value')),
      '3',
    ); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('선택한 항목 검토')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(selected!.lines.single.quantity, 3); // [OCR 추가]
    expect(selected!.lines.single.total, 80940); // [OCR 추가]
    expect(selected!.lines.single.unitPrice, 26980); // [OCR 추가]
    expect(draft.lines.single.title, '원본'); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('단가·수량 직접 입력은 검증 후 적용하고 취소는 선택값을 유지한다', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    tester.view.physicalSize = const Size(320, 568); // [OCR 추가]
    tester.view.devicePixelRatio = 1; // [OCR 추가]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
    addTearDown(tester.view.resetViewInsets); // [OCR 추가]
    ReceiptDraft? selected; // [OCR 추가]
    await startSelection(
      // [OCR 추가]
      tester, // [OCR 추가]
      selectionDraft(), // [OCR 추가]
      (value) => selected = value, // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(
      find.byKey(const ValueKey('ocr-unit-price-toggle')),
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.scrollUntilVisible(
      // [OCR 추가]
      find.text('금액 직접 입력'), // [OCR 추가]
      120, // [OCR 추가]
      scrollable: find.byType(Scrollable).last, // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.ensureVisible(
      // [OCR 수정]
      find.widgetWithText(TextButton, '금액 직접 입력'), // [OCR 수정]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('금액 직접 입력')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-edit-value')), // [OCR 추가]
      '26,980', // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('수량 확인')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.scrollUntilVisible(
      // [OCR 추가]
      find.text('수량 직접 입력'), // [OCR 추가]
      120, // [OCR 추가]
      scrollable: find.byType(Scrollable).last, // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('수량 직접 입력')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    tester.view.viewInsets = const FakeViewPadding(bottom: 180); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.enterText(
      find.byKey(const ValueKey('ocr-edit-value')),
      '0',
    ); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(find.text('수량은 1~999개로 입력해주세요.'), findsOneWidget); // [OCR 추가]
    await tester.enterText(
      find.byKey(const ValueKey('ocr-edit-value')),
      '3',
    ); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    tester.view.resetViewInsets(); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.scrollUntilVisible(
      // [OCR 추가]
      find.text('수량 직접 입력'), // [OCR 추가]
      120, // [OCR 추가]
      scrollable: find.byType(Scrollable).last, // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('수량 직접 입력')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      find.byKey(const ValueKey('ocr-edit-value')),
      '7',
    ); // [OCR 추가]
    await tester.tap(find.text('취소')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('선택한 항목 검토')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(selected!.lines.single.quantity, 3); // [OCR 추가]
    expect(selected!.lines.single.total, 80940); // [OCR 추가]
    expect(selected!.lines.single.unitPrice, 26980); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('기존 검토 UI: 개당 가격 표시, 수량 수정 미확정 취소·확정 반영', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    tester.view.physicalSize = const Size(390, 844); // [OCR 추가]
    tester.view.devicePixelRatio = 1; // [OCR 추가]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    await store.initialize(); // [OCR 추가]
    final draft = amountDraft(
      // [OCR 추가]
      receiptLineFromAmount(
        // [OCR 추가]
        id: 'persil', // [OCR 추가]
        title: '퍼실', // [OCR 추가]
        amount: 80940, // [OCR 추가]
        quantity: 3, // [OCR 추가]
        isUnitPrice: false, // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 추가]
      MaterialApp(
        // [OCR 추가]
        theme: buildAppTheme(), // [OCR 추가]
        home: ReceiptReviewScreen(store: store, draft: draft), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('개당 26,980원 · 3개'), findsOneWidget); // [OCR 추가]
    await tester.tap(find.text('퍼실')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      // [OCR 추가]
      find.byKey(const ValueKey('receipt-quantity-persil')), // [OCR 추가]
      '2', // [OCR 추가]
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(find.text('개당 가격: 40,470원'), findsOneWidget); // [OCR 추가]
    await tester.ensureVisible(find.text('취소')); // [OCR 추가]
    await tester.tap(find.text('취소')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(draft.lines.single.quantity, 3); // [OCR 추가]
    await tester.tap(find.text('퍼실')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      // [OCR 추가]
      find.byKey(const ValueKey('receipt-quantity-persil')), // [OCR 추가]
      '2', // [OCR 추가]
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.ensureVisible(find.text('확인했어요')); // [OCR 추가]
    await tester.tap(find.text('확인했어요')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(draft.lines.single.quantity, 2); // [OCR 추가]
    expect(find.text('개당 40,470원 · 2개'), findsOneWidget); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]

  testWidgets('단가 검토: 수량 수정은 단가 유지, 총액 직접 수정은 전환, 취소·범위 초과는 원본 보존', (
    // [OCR 수정]
    tester, // [OCR 수정]
  ) async {
    // [OCR 수정]
    // [OCR 추가]
    tester.view.physicalSize = const Size(480, 900); // [OCR 추가]
    tester.view.devicePixelRatio = 1; // [OCR 추가]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
    SharedPreferences.setMockInitialValues({}); // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    await store.initialize(); // [OCR 추가]
    final line = ReceiptLineDraft(
      // [OCR 수정]
      id: 'unit-review', // [OCR 수정]
      title: '우유', // [OCR 수정]
      quantity: 3, // [OCR 수정]
      total: 15000, // [OCR 수정]
      ocrAmountIsUnitPrice: true, // [OCR 수정]
      ocrInputAmount: 5000, // [OCR 수정]
    ); // [OCR 추가]
    final draft = amountDraft(line); // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 수정]
      MaterialApp(
        // [OCR 수정]
        home: ReceiptReviewScreen(store: store, draft: draft), // [OCR 수정]
      ), // [OCR 수정]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    Future<void> open() async {
      // [OCR 수정]
      // [OCR 추가]
      await tester.tap(find.text('우유')); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
    } // [OCR 추가]

    Future<void> tap(String text) async {
      // [OCR 수정]
      // [OCR 추가]
      await tester.ensureVisible(find.text(text)); // [OCR 추가]
      await tester.tap(find.text(text)); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
    } // [OCR 추가]

    final quantity = find.byKey(
      // [OCR 수정]
      const ValueKey('receipt-quantity-unit-review'), // [OCR 수정]
    ); // [OCR 추가]
    final total = find.widgetWithText(TextFormField, '상품 결제금액'); // [OCR 추가]
    await open(); // [OCR 추가]
    await tester.enterText(quantity, '2'); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(find.text('개당 가격: 5,000원'), findsOneWidget); // [OCR 추가]
    expect(
      // [OCR 수정]
      tester.widget<TextFormField>(total).initialValue, // [OCR 수정]
      '10000', // [OCR 수정]
    ); // [OCR 추가]
    await tap('취소'); // [OCR 추가]
    expect(line.quantity, 3); // [OCR 수정]
    expect(line.total, 15000); // [OCR 수정]
    expect(line.ocrAmountIsUnitPrice, true); // [OCR 추가]
    for (final invalid in ['', '1000']) {
      // [OCR 수정]
      // [OCR 추가]
      await open(); // [OCR 추가]
      await tester.enterText(quantity, invalid); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
      await tap('확인했어요'); // [OCR 추가]
      expect(quantity, findsOneWidget); // [OCR 추가]
      expect(line.quantity, 3); // [OCR 추가]
      expect(line.total, 15000); // [OCR 추가]
      expect(line.ocrAmountIsUnitPrice, true); // [OCR 추가]
      await tap('취소'); // [OCR 추가]
    } // [OCR 추가]
    await open(); // [OCR 추가]
    await tester.enterText(quantity, '2'); // [OCR 수정]
    await tester.pump(); // [OCR 추가]
    await tap('확인했어요'); // [OCR 추가]
    expect(line.quantity, 2); // [OCR 수정]
    expect(line.total, 10000); // [OCR 수정]
    expect(line.unitPrice, 5000); // [OCR 수정]
    expect(line.ocrInputAmount, 5000); // [OCR 수정]
    expect(line.ocrAmountIsUnitPrice, true); // [OCR 추가]
    await store.saveReceipt(
      ReceiptDraft(
        id: 'unit-snapshot',
        store: draft.store,
        purchasedOn: draft.purchasedOn,
        lines: [line],
      ),
    ); // [OCR 추가]
    await open(); // [OCR 추가]
    await tester.enterText(total, '12000'); // [OCR 수정]
    await tester.pump(); // [OCR 추가]
    await tester.enterText(quantity, '3'); // [OCR 수정]
    await tester.pump(); // [OCR 추가]
    expect(find.text('개당 가격: 4,000원'), findsOneWidget); // [OCR 추가]
    expect(
      // [OCR 수정]
      tester.widget<TextFormField>(total).initialValue, // [OCR 수정]
      '12000', // [OCR 수정]
    ); // [OCR 추가]
    await tap('확인했어요'); // [OCR 추가]
    expect(line.total, 12000); // [OCR 수정]
    expect(line.quantity, 3); // [OCR 수정]
    expect(line.ocrAmountIsUnitPrice, false); // [OCR 수정]
    expect(line.ocrInputAmount, 12000); // [OCR 추가]
    await store.saveReceipt(draft); // [OCR 추가]
    final restored = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(restored.dispose); // [OCR 수정]
    await restored.initialize(); // [OCR 추가]
    final unitSaved = restored.purchaseRows
        .singleWhere((row) => row.purchase!.receiptId == 'unit-snapshot')
        .purchase!; // [OCR 추가]
    expect(unitSaved.total, 10000); // [OCR 추가]
    expect(unitSaved.quantity, 2); // [OCR 추가]
    expect(unitSaved.unitPrice, 5000); // [OCR 추가]
    final totalSaved = restored.purchaseRows
        .singleWhere((row) => row.purchase!.receiptId == draft.id)
        .purchase!; // [OCR 추가]
    expect(totalSaved.total, 12000); // [OCR 추가]
    expect(totalSaved.quantity, 3); // [OCR 추가]
    expect(totalSaved.unitPrice, 4000); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
