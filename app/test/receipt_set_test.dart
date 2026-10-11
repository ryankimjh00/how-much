import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:shared_preferences/shared_preferences.dart'; // [OCR 추가]
import 'package:how_much/app_store.dart'; // [OCR 추가]
import 'package:how_much/cloud_service.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/screens.dart'; // [OCR 추가]

// [OCR 추가] 실제 OCR 대신 검토 항목을 사용해 드롭·저장·동기화의 관계 유실을 검사한다.
ReceiptDraft setDraft() => ReceiptDraft(
  id: 'receipt-set',
  store: '마트',
  purchasedOn: '2026-10-01',
  lines: [
    ReceiptLineDraft(id: 'parent', title: '세제', quantity: 3, total: 12000),
    ReceiptLineDraft(id: 'component', title: '증정 세제', quantity: 2, total: 0),
    ReceiptLineDraft(id: 'other', title: '다른 상품', total: 5000),
  ],
); // [OCR 추가]

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({})); // [OCR 추가]
  test('세트 관계·구성품 수량과 금액은 로컬 복원과 동기화 사본에서 유지된다', () async {
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    await store.initialize(); // [OCR 추가]
    final draft = setDraft(); // [OCR 추가]
    draft.lines[1].setParentId = 'parent'; // [OCR 추가]
    await store.saveReceipt(draft); // [OCR 추가]
    final restored = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(restored.dispose); // [OCR 추가]
    await restored.initialize(); // [OCR 추가]
    final component = restored.purchaseRows.singleWhere(
      (row) => row.title == '증정 세제',
    ); // [OCR 추가]
    final parent = restored.purchaseRows.singleWhere(
      (row) => row.title == '세제',
    ); // [OCR 추가]
    expect(component.purchase!.setParentId, parent.id); // [OCR 추가]
    expect(component.purchase!.quantity, 2); // [OCR 추가]
    expect(component.purchase!.total, 0); // [OCR 추가]
    expect(parent.purchase!.quantity, 3); // [OCR 추가]
    expect(parent.purchase!.total, 12000); // [OCR 추가]
    final decoded = AppRow.fromJson(component.toJson()); // [OCR 추가]
    final edited = decoded.copyWith(
      purchase: decoded.purchase!.copyWith(condition: '세트'),
    ); // [OCR 추가]
    expect(edited.purchase!.setParentId, parent.id); // [OCR 추가]
    final synced = reconcileRows([], restored.rows); // [OCR 추가]
    expect(synced.conflicts, isEmpty); // [OCR 추가]
    expect(
      synced.rows
          .singleWhere((row) => row.id == component.id)
          .purchase!
          .setParentId,
      parent.id,
    ); // [OCR 추가]
    final conflict = reconcileRows(
      [component.copyWith(revision: '0000000000000010:remote')],
      [
        component.withSync(
          pending: true,
          baseRevision: '0000000000000005:old',
          group: 'set',
        ),
      ],
    ); // [OCR 추가]
    expect(
      conflict.conflicts.single.entries.single.local.purchase!.setParentId,
      parent.id,
    ); // [OCR 추가]
    expect(
      conflict.conflicts.single.entries.single.remote!.purchase!.setParentId,
      parent.id,
    ); // [OCR 추가]
    expect(restored.pricesFor('증정 세제'), isEmpty); // [OCR 추가]
    expect(
      comparePrices(parent.purchase!, component.purchase!).issue,
      contains('세트'),
    ); // [OCR 추가]
    expect(
      PurchaseData.fromJson(
        {...parent.purchase!.toJson()}..remove('setParentId'),
      ).setParentId,
      isEmpty,
    ); // [OCR 추가]
  }); // [OCR 추가]

  for (final invalid in ['missing', 'self', 'nested', 'excluded']) {
    // [OCR 추가]
    test('잘못된 세트 관계 $invalid 는 부분 저장하지 않는다', () async {
      final store = AppStore(CloudService(false)); // [OCR 추가]
      addTearDown(store.dispose); // [OCR 추가]
      await store.initialize(); // [OCR 추가]
      final draft = setDraft(); // [OCR 추가]
      draft.lines[1].setParentId = 'parent'; // [OCR 추가]
      if (invalid == 'missing') {
        // [OCR 수정]
        draft.lines[1].setParentId = 'absent'; // [OCR 추가]
      } // [OCR 수정]
      if (invalid == 'self') {
        // [OCR 수정]
        draft.lines[1].setParentId = 'component'; // [OCR 추가]
      } // [OCR 수정]
      if (invalid == 'nested') draft.lines[0].setParentId = 'other'; // [OCR 추가]
      if (invalid == 'excluded') draft.lines[0].selected = false; // [OCR 추가]
      await expectLater(
        store.saveReceipt(draft),
        throwsFormatException,
      ); // [OCR 추가]
      expect(store.purchaseRows, isEmpty); // [OCR 추가]
      final restored = AppStore(CloudService(false)); // [OCR 추가]
      addTearDown(restored.dispose); // [OCR 추가]
      await restored.initialize(); // [OCR 추가]
      expect(restored.purchaseRows, isEmpty); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  testWidgets('길게 누른 항목 드롭은 세트 구성품 등록·이동·해제하며 취소 드롭은 그대로다', (tester) async {
    tester.view.physicalSize = const Size(480, 1400); // [OCR 추가]
    tester.view.devicePixelRatio = 1; // [OCR 추가]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    final draft = setDraft(); // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptReviewScreen(store: store, draft: draft),
      ),
    ); // [OCR 추가]
    Future<void> drop(String source, String target) async {
      // [OCR 추가]
      final drag = find.byKey(ValueKey('ocr-set-drag-$source')); // [OCR 추가]
      await tester.ensureVisible(drag); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      final gesture = await tester.startGesture(
        tester.getCenter(drag),
      ); // [OCR 추가]
      await tester.pump(const Duration(milliseconds: 600)); // [OCR 추가]
      await gesture.moveTo(
        tester.getCenter(find.byKey(ValueKey('ocr-set-target-$target'))),
      ); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
      await gesture.up(); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
    } // [OCR 추가]

    await drop('component', 'parent'); // [OCR 추가]
    final component = draft.lines.singleWhere(
      (line) => line.id == 'component',
    ); // [OCR 추가]
    expect(component.setParentId, 'parent'); // [OCR 추가]
    expect(component.quantity, 2); // [OCR 추가]
    expect(component.total, 0); // [OCR 추가]
    final parentCheck = find.descendant(
      of: find.byKey(const ValueKey('ocr-set-target-parent')),
      matching: find.byType(Checkbox),
    ); // [OCR 추가]
    await tester.tap(parentCheck); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(component.selected, isFalse); // [OCR 추가]
    await tester.tap(parentCheck); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(component.selected, isTrue); // [OCR 추가]
    expect(find.textContaining('세제 세트 구성품'), findsOneWidget); // [OCR 추가]
    await drop('parent', 'component'); // [OCR 추가] 중첩·순환 드롭을 거부한다.
    expect(draft.lines.first.setParentId, isEmpty); // [OCR 추가]
    await drop('component', 'other'); // [OCR 추가]
    expect(component.setParentId, 'other'); // [OCR 추가]
    expect(draft.lines.last, same(component)); // [OCR 추가]
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('ocr-set-drag-component'))),
    ); // [OCR 추가]
    await tester.pump(const Duration(milliseconds: 600)); // [OCR 추가]
    await gesture.moveTo(const Offset(460, 50)); // [OCR 추가]
    await gesture.up(); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(component.setParentId, 'other'); // [OCR 추가]
    await tester.tap(
      find.byKey(const ValueKey('ocr-set-unlink-component')),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(component.setParentId, isEmpty); // [OCR 추가]
    await drop('component', 'parent'); // [OCR 추가]
    await tester.tap(find.text('세제')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.byTooltip('항목 삭제')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      draft.lines.where((line) => line.id == 'parent'),
      isEmpty,
    ); // [OCR 추가]
    expect(draft.lines, contains(component)); // [OCR 추가]
    expect(component.setParentId, isEmpty); // [OCR 추가]
    expect(component.quantity, 2); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
