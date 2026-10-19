import 'dart:io'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/gestures.dart'; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:shared_preferences/shared_preferences.dart'; // [OCR 추가]
import 'package:how_much/app_store.dart'; // [OCR 추가]
import 'package:how_much/cloud_service.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_review_photo.dart'; // [OCR 추가]
import 'package:how_much/screens.dart'; // [OCR 추가]

void main() {
  // [OCR 추가]
  // [OCR 추가]
  setUp(() => SharedPreferences.setMockInitialValues({})); // [OCR 추가]
  testWidgets('펜 편집 수량 삼각형은 취소 시 복원하고 확인 시 항목을 체크한다', (tester) async {
    // [OCR 추가] 작은 화면에서 버튼 변경·단가 계산·확정 전 원본 보존을 함께 확인한다.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(CloudService(false));
    addTearDown(store.dispose);
    final line = ReceiptLineDraft(
      id: 'arrow',
      title: '스티커',
      quantity: 1,
      total: 4900,
      selected: false,
      ocrAmountIsUnitPrice: true,
      ocrInputAmount: 4900,
    );
    final draft = ReceiptDraft(
      id: 'arrow-review',
      store: '',
      purchasedOn: '2026-10-11',
      lines: [line],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptReviewScreen(store: store, draft: draft),
      ),
    );
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap(find.text('스티커'));
    final up = find.byKey(const ValueKey('receipt-quantity-up-arrow'));
    final down = find.byKey(const ValueKey('receipt-quantity-down-arrow'));
    expect(tester.widget<IconButton>(down).onPressed, isNull);
    await tap(up);
    expect(find.text('개당 가격: 4,900원'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('receipt-quantity-arrow')),
          )
          .controller!
          .text,
      '2',
    );
    expect(line.quantity, 1);
    expect(line.selected, isFalse);
    await tap(find.text('취소'));
    expect(line.quantity, 1);
    expect(line.total, 4900);
    expect(line.selected, isFalse);
    await tap(find.text('스티커'));
    await tap(up);
    // [OCR 추가] 금액 키보드가 열린 작은 화면에서도 확인 버튼까지 스크롤할 수 있다.
    await tap(find.byKey(const ValueKey('receipt-total-arrow-2')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tap(find.text('확인했어요'));
    expect(line.quantity, 2);
    expect(line.total, 9800);
    expect(line.selected, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('검토 체크는 상품명·금액 박스만 숨기며 사진과 목록 스크롤은 분리된다', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    late Directory photos; // [OCR 추가]
    late String path; // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      // [OCR 추가]
      photos = await Directory.systemTemp.createTemp('ocr-review-'); // [OCR 추가]
      path = '${photos.path}/receipt.png'; // [OCR 추가]
      final recorder = ui.PictureRecorder(); // [OCR 추가]
      Canvas(recorder).drawColor(Colors.white, BlendMode.src); // [OCR 추가]
      final picture = recorder.endRecording(); // [OCR 추가]
      final image = await picture.toImage(200, 600); // [OCR 추가]
      final bytes = await image.toByteData(
        // [OCR 추가]
        format: ui.ImageByteFormat.png, // [OCR 추가]
      ); // [OCR 추가]
      await File(path).writeAsBytes(bytes!.buffer.asUint8List()); // [OCR 추가]
      image.dispose(); // [OCR 추가]
      picture.dispose(); // [OCR 추가]
    }); // [OCR 추가]
    addTearDown(() => photos.delete(recursive: true)); // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    final product = ReceiptOcrCandidate(
      // [OCR 추가]
      id: 'name', // [OCR 추가]
      text: '퍼실', // [OCR 추가]
      bounds: const Rect.fromLTWH(10, 10, 50, 20), // [OCR 추가]
    ); // [OCR 추가]
    final amount = ReceiptOcrCandidate(
      // [OCR 추가]
      id: 'price', // [OCR 추가]
      text: '80,940', // [OCR 추가]
      number: 80940, // [OCR 추가]
      bounds: const Rect.fromLTWH(100, 10, 70, 20), // [OCR 추가]
    ); // [OCR 추가]
    final line = ReceiptLineDraft(
      // [OCR 추가]
      id: 'line', // [OCR 추가]
      title: '퍼실', // [OCR 추가]
      quantity: 3, // [OCR 추가]
      total: 80940, // [OCR 추가]
      ocrProduct: product, // [OCR 추가]
      ocrAmount: amount, // [OCR 추가]
    ); // [OCR 추가]
    final draft = ReceiptDraft(
      // [OCR 추가]
      id: 'draft', // [OCR 추가]
      store: '', // [OCR 추가]
      purchasedOn: '2026-10-06', // [OCR 추가]
      lines: [line], // [OCR 추가]
      ocrResult: ReceiptOcrResult(
        // [OCR 추가]
        text: '퍼실 3 80,940', // [OCR 추가]
        photoPath: path, // [OCR 추가]
        rows: [], // [OCR 추가]
        products: [product], // [OCR 추가]
        numbers: [amount], // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 추가]
      MaterialApp(
        // [OCR 추가]
        home: ReceiptReviewScreen(store: store, draft: draft), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    for (var i = 0; i < 10; i++) {
      // [OCR 추가]
      // [OCR 추가]
      await tester.runAsync(() async {
        // [OCR 추가]
        await Future<void>.delayed(
          const Duration(milliseconds: 20),
        ); // [OCR 추가]
      }); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
    } // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(
      // [OCR 추가]
      tester // [OCR 추가]
          .widget<ReceiptReviewPhoto>(
            find.byType(ReceiptReviewPhoto),
          ) // [OCR 추가]
          .regions // [OCR 추가]
          .map((r) => r.id), // [OCR 추가]
      ['name', 'price'], // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      find.byKey(const ValueKey('review-region-name')), // [OCR 추가]
      findsOneWidget, // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      find.byKey(const ValueKey('review-region-price')), // [OCR 추가]
      findsOneWidget, // [OCR 추가]
    ); // [OCR 추가]
    // [OCR 추가] 긴 사진은 가로폭에 맞춰 표시하고, 기본 배율에서도 터치패드 이동을 받아야 한다.
    final viewport = find.byType(ReceiptReviewPhoto); // [OCR 추가]
    expect(
      tester.getSize(find.byType(Image)).width,
      tester.getSize(viewport).width,
    ); // [OCR 추가]
    expect(
      tester.getSize(find.byType(Image)).height,
      greaterThan(tester.getSize(viewport).height),
    ); // [OCR 추가]
    final beforeTrackpad = tester.getTopLeft(find.byType(Image)); // [OCR 추가]
    final trackpadPosition = tester.getCenter(viewport); // [OCR 추가]
    await tester.sendEventToBinding(
      PointerPanZoomStartEvent(pointer: 91, position: trackpadPosition),
    ); // [OCR 추가]
    await tester.sendEventToBinding(
      PointerPanZoomUpdateEvent(
        pointer: 91,
        position: trackpadPosition,
        pan: const Offset(0, -40),
        panDelta: const Offset(0, -40),
      ),
    ); // [OCR 추가]
    await tester.sendEventToBinding(
      PointerPanZoomEndEvent(pointer: 91, position: trackpadPosition),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      tester.getTopLeft(find.byType(Image)).dy,
      lessThan(beforeTrackpad.dy),
    ); // [OCR 추가]
    final trackpadBox = find.byKey(
      const ValueKey('review-region-name'),
    ); // [OCR 추가]
    final beforePinchWidth =
        (tester.getTopRight(trackpadBox) - tester.getTopLeft(trackpadBox))
            .dx; // [OCR 추가]
    await tester.sendEventToBinding(
      PointerPanZoomStartEvent(pointer: 92, position: trackpadPosition),
    ); // [OCR 추가]
    await tester.sendEventToBinding(
      PointerPanZoomUpdateEvent(
        pointer: 92,
        position: trackpadPosition,
        scale: 1.5,
      ),
    ); // [OCR 추가]
    await tester.sendEventToBinding(
      PointerPanZoomEndEvent(pointer: 92, position: trackpadPosition),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      (tester.getTopRight(trackpadBox) - tester.getTopLeft(trackpadBox)).dx,
      closeTo(beforePinchWidth * 1.5, 0.01),
    ); // [OCR 추가]
    final nameBox = find.byKey(
      const ValueKey('review-region-name'),
    ); // [OCR 추가]
    final initialWidth =
        (tester.getTopRight(nameBox) - tester.getTopLeft(nameBox))
            .dx; // [OCR 추가]
    final photoCenter = tester.getCenter(
      find.byType(ReceiptReviewPhoto),
    ); // [OCR 추가]
    final firstFinger = await tester.createGesture(pointer: 1); // [OCR 추가]
    final secondFinger = await tester.createGesture(pointer: 2); // [OCR 추가]
    await firstFinger.down(photoCenter - const Offset(20, 0)); // [OCR 추가]
    await secondFinger.down(photoCenter + const Offset(20, 0)); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await firstFinger.moveTo(photoCenter - const Offset(50, 0)); // [OCR 추가]
    await secondFinger.moveTo(photoCenter + const Offset(50, 0)); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await firstFinger.up(); // [OCR 추가]
    await secondFinger.up(); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      (tester.getTopRight(nameBox) - tester.getTopLeft(nameBox)).dx,
      greaterThan(initialWidth),
    ); // [OCR 추가]
    final photoPosition = tester.getTopLeft(
      // [OCR 추가]
      find.byType(ReceiptReviewPhoto), // [OCR 추가]
    ); // [OCR 추가]
    await tester.scrollUntilVisible(
      // [OCR 추가]
      find.byType(Checkbox), // [OCR 추가]
      200, // [OCR 추가]
      scrollable: find.byType(Scrollable).first, // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      // [OCR 추가]
      tester.getTopLeft(find.byType(ReceiptReviewPhoto)), // [OCR 추가]
      photoPosition, // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.byType(Checkbox)); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(
      // [OCR 추가]
      tester // [OCR 추가]
          .widget<ReceiptReviewPhoto>(
            find.byType(ReceiptReviewPhoto),
          ) // [OCR 추가]
          .regions, // [OCR 추가]
      isEmpty, // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.byType(Checkbox)); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(
      // [OCR 추가]
      tester // [OCR 추가]
          .widget<ReceiptReviewPhoto>(
            find.byType(ReceiptReviewPhoto),
          ) // [OCR 추가]
          .regions, // [OCR 추가]
      hasLength(2), // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('영수증에서 수정')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    for (var i = 0; i < 10; i++) {
      // [OCR 추가]
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
    expect(find.text('1/1 · 퍼실 수량 선택'), findsOneWidget); // [OCR 추가]
    await tester.tap(find.text('금액 선택으로')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('1/1 · 퍼실 금액 선택'), findsOneWidget); // [OCR 추가]
    Navigator.of(tester.element(find.text("수정 적용"))).pop(); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(line.quantity, 3); // [OCR 추가]
    expect(line.total, 80940); // [OCR 추가]
    expect(line.ocrAmount, same(amount)); // [OCR 추가]
    await tester.tap(find.text('영수증에서 수정')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    for (var i = 0; i < 10; i++) {
      // [OCR 추가]
      // [OCR 추가]
      await tester.runAsync(() async {
        // [OCR 추가]
        await Future<void>.delayed(
          const Duration(milliseconds: 20),
        ); // [OCR 추가]
      }); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
    } // [OCR 추가]
    await tester.tap(find.text('수량 직접 입력')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(find.byType(TextFormField), '2'); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('금액 선택으로')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('수정 적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(line.quantity, 2); // [OCR 추가]
    expect(line.total, 80940); // [OCR 추가]
    expect(line.ocrAmount, same(amount)); // [OCR 추가]
    await tester.scrollUntilVisible(
      // [OCR 추가]
      find.text('영수증에서 항목 추가'), // [OCR 추가]
      200, // [OCR 추가]
      scrollable: find.byType(Scrollable).first, // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('영수증에서 항목 추가')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.pump(const Duration(milliseconds: 400)); // [OCR 추가]
    expect(
      find.byKey(const ValueKey('ocr-manual-names')),
      findsOneWidget,
    ); // [OCR 추가]
    Navigator.of(
      // [OCR 추가]
      tester.element(
        find.byKey(const ValueKey('ocr-manual-names')),
      ), // [OCR 추가]
    ).pop(); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(draft.lines, hasLength(1)); // [OCR 추가]
    await tester.tap(find.text('영수증에서 항목 추가')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.pump(const Duration(milliseconds: 400)); // [OCR 추가]
    // [OCR 추가] 선택 화면 자체의 다중 선택은 2·3단계 테스트에서 확인하며 여기서는 결과 추가와 ID 충돌을 검증한다.
    Navigator.of(
      tester.element(find.byKey(const ValueKey('ocr-manual-names'))),
    ).pop(
      // [OCR 수정]
      // [OCR 추가]
      ReceiptDraft(
        // [OCR 추가]
        // [OCR 추가]
        id: draft.id, // [OCR 추가]
        store: '', // [OCR 추가]
        purchasedOn: draft.purchasedOn, // [OCR 추가]
        lines: [
          // [OCR 추가]
          // [OCR 추가]
          ReceiptLineDraft(
            // [OCR 추가]
            id: line.id, // [OCR 추가]
            title: '베지밀', // [OCR 추가]
            total: 33760, // [OCR 추가]
            ocrProduct: product, // [OCR 추가]
            ocrAmount: amount, // [OCR 추가]
          ), // [OCR 추가]
        ], // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(draft.lines, hasLength(2)); // [OCR 추가]
    expect(draft.lines.first, same(line)); // [OCR 추가]
    expect(draft.lines.last.title, '베지밀'); // [OCR 추가]
    expect(
      // [OCR 추가]
      draft.lines.map((line) => line.id).toSet(), // [OCR 추가]
      hasLength(2), // [OCR 추가]
    ); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('일반 품목 추가는 직접 편집창을 열고 취소하면 빈 항목을 남기지 않는다', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    tester.view.physicalSize = const Size(320, 568); // [OCR 추가]
    tester.view.devicePixelRatio = 1; // [OCR 추가]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    final draft = ReceiptDraft(
      // [OCR 추가]
      id: 'draft', // [OCR 추가]
      store: '', // [OCR 추가]
      purchasedOn: '2026-10-06', // [OCR 추가]
      lines: [], // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 추가]
      MaterialApp(
        // [OCR 추가]
        home: ReceiptReviewScreen(store: store, draft: draft), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.scrollUntilVisible(
      // [OCR 추가]
      find.text('품목 추가'), // [OCR 추가]
      200, // [OCR 추가]
      scrollable: find.byType(Scrollable).first, // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('품목 추가')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('확인했어요'), findsOneWidget); // [OCR 추가]
    await tester.tap(find.text('취소')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(draft.lines, isEmpty); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
