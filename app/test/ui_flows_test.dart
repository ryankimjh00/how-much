import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_much/app.dart';
import 'package:how_much/app_store.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/models.dart';
import 'package:how_much/screens.dart';

void main() {
  Future<AppStore> createStore() async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(CloudService(false));
    await store.initialize();
    addTearDown(store.dispose);
    return store;
  }

  testWidgets('작은 화면에서 상품 수정과 키보드가 겹치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await createStore();
    await store.addItem('우유');
    await tester.pumpWidget(HowMuchApp(store: store));
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('우유 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('이대로 저장할게요'));
    await tester.pumpAndSettle();
    expect(store.shoppingItems.single.title, '우유');
  });

  testWidgets('메모 수정창을 닫으며 키보드가 사라져도 입력 상태 오류가 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final store = await createStore();
    await tester.pumpWidget(
      MaterialApp(
        home: MemoImportScreen(
          store: store,
          initialLines: [MemoLineDraft(title: '우유')],
        ),
      ),
    );
    await tester.tap(find.byTooltip('품목 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '저지방 우유');
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pump();
    await tester.tap(find.text('적용'));
    await tester.pump(const Duration(milliseconds: 50));
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('저지방 우유'), findsOneWidget);
  });

  testWidgets('메모 검토에서 선택한 상품만 장보기에 저장한다', (tester) async {
    final store = await createStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemoImportScreen(
                  store: store,
                  initialLines: [
                    MemoLineDraft(title: '우유', quantity: 2, selected: true),
                    MemoLineDraft(title: '계란'),
                  ],
                ),
              ),
            ),
            child: const Text('메모 열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('메모 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1개를 장보기 목록에 담기'));
    await tester.pumpAndSettle();
    expect(store.shoppingItems.single.title, '우유');
    expect(store.shoppingItems.single.quantity, 2);
    expect(store.purchaseRows, isEmpty);
  });

  testWidgets('영수증 검토·저장 후 구매 기록과 가격 비교를 연다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await createStore();
    final draft = ReceiptDraft(
      id: 'ui-receipt',
      store: '모니마트',
      purchasedOn: '2026-09-21',
      lines: [
        ReceiptLineDraft(id: 'milk', title: '서울우유', total: 3200),
        ReceiptLineDraft(id: 'eggs', title: '계란', total: 3500),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptReviewScreen(store: store, draft: draft),
      ),
    );
    expect(find.text('6,700원'), findsOneWidget);
    await tester.tap(find.text('서울우유'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('receipt-total-milk-1')), // [OCR 수정]
      '3000',
    );
    await tester.tap(find.text('확인했어요'));
    await tester.pumpAndSettle();
    expect(find.text('6,500원'), findsOneWidget);
    // 루트 경로를 닫지 않도록 저장 화면을 새 경로에서 연다.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReceiptReviewScreen(store: store, draft: draft),
              ),
            ),
            child: const Text('영수증 열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('영수증 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('구매 기록에 남길게요'));
    await tester.pumpAndSettle();
    expect(store.purchaseRows, hasLength(2));

    await tester.pumpWidget(HowMuchApp(store: store));
    await tester.tap(find.text('구매 기록'));
    await tester.pumpAndSettle();
    expect(find.text('모니마트'), findsOneWidget);
    await tester.tap(find.text('모니마트'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('서울우유'));
    await tester.pumpAndSettle();
    expect(find.text('가격 비교'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
