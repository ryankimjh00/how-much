import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:how_much/app_store.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('부분 구매를 완료분과 잔여분으로 나누고 재실행 시 복원한다', () async {
    final store = AppStore(CloudService(false));
    await store.initialize();
    await store.addItem('우유', quantity: 3);
    final item = store.shoppingItems.single;
    expect(item.pending, isTrue);
    final draft = ReceiptDraft(
      id: 'receipt-1',
      store: '행복마트',
      purchasedOn: '2026-09-20',
      lines: [
        ReceiptLineDraft(
          id: 'line-1',
          title: '우유',
          quantity: 2,
          total: 5000,
          itemId: item.id,
        ),
      ],
    );

    await store.saveReceipt(draft);

    expect(store.purchaseRows.single.purchase!.total, 5000);
    expect(
      store.shoppingItems.where((row) => !row.completed).single.quantity,
      1,
    );
    expect(
      store.shoppingItems.where((row) => row.completed).single.quantity,
      2,
    );

    final restored = AppStore(CloudService(false));
    await restored.initialize();
    expect(restored.purchaseRows.single.title, '우유');
    expect(restored.shoppingItems.length, 2);
    expect(restored.rows.every((row) => row.pending), isTrue);
  });

  test('존재하지 않는 구매일은 저장하지 않는다', () async {
    final store = AppStore(CloudService(false));
    await store.initialize();
    final draft = ReceiptDraft(
      id: 'receipt-invalid-date',
      store: '행복마트',
      purchasedOn: '2026-02-31',
      lines: [ReceiptLineDraft(id: 'line-1', title: '우유', total: 2500)],
    );

    await expectLater(
      store.saveReceipt(draft),
      throwsA(isA<FormatException>()),
    );
    expect(store.purchaseRows, isEmpty);
  });

  test('구매 기록 수정 시 0개 묶음을 거부하고 원래 가격을 보존한다', () async {
    final store = AppStore(CloudService(false));
    addTearDown(store.dispose);
    await store.initialize();
    await store.saveReceipt(
      ReceiptDraft(
        id: 'spec-check',
        store: '마트',
        purchasedOn: '2026-09-20',
        lines: [ReceiptLineDraft(id: 'milk', title: '우유', total: 3200)],
      ),
    );
    const spec = ProductSpec(
      identity: '우유',
      volume: 1000,
      unit: 'mL',
      packCount: 0,
      conditionKnown: true,
    );
    expect(spec.isComparable, isFalse);
    await expectLater(
      store.updatePurchase(
        store.purchaseRows.single,
        title: '우유',
        spec: spec,
        condition: '',
        share: false,
      ),
      throwsFormatException,
    );
    expect(store.purchaseRows.single.purchase!.total, 3200);
    expect(store.purchaseRows.single.purchase!.spec, isNull);
  });
}
