import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_selection_screen.dart'; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto, loadRegion; // [OCR 추가]

void main() {
  for (final cancel in [false, true]) {
    testWidgets('교보 포스트잇 수량 영역 적용은 금액 박스를 보이고 취소는 수량 단계 유지: $cancel', (
      tester,
    ) async {
      // [OCR 추가] 교보 실측 표기·좌표를 1/5로 재생한다. 실제 새 사진 OCR 인식률과 구분한다.
      tester.view.physicalSize = const Size(390, 844); // [OCR 추가]
      tester.view.devicePixelRatio = 1; // [OCR 추가]
      addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
      addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
      final path = await regionPhoto(
        tester,
        width: 600,
        height: 800,
      ); // [OCR 추가]
      ReceiptOcrRow row(String id, String text, Rect bounds) => ReceiptOcrRow(
        id: id,
        text: text,
        bounds: bounds, // [OCR 추가]
        tokens: [
          ReceiptOcrToken(id: id, text: text, bounds: bounds),
        ], // [OCR 추가]
      ); // [OCR 추가]
      final rows = [
        row(
          'first',
          '포스트잇/670-5AN-5/알뜰팩',
          const Rect.fromLTRB(110.8, 449.8, 298.2, 464.6),
        ), // [OCR 추가]
        row(
          'quantity',
          '1',
          const Rect.fromLTRB(332.6, 471.6, 335.8, 485),
        ), // [OCR 추가]
        row(
          'amount',
          '9.600',
          const Rect.fromLTRB(392, 472.4, 427.8, 486.6),
        ), // [OCR 추가]
        row(
          'second',
          '[JR] 스티커미니/101-F00D.01',
          const Rect.fromLTRB(103.2, 490.2, 313, 507.2),
        ), // [OCR 추가]
      ]; // [OCR 추가]
      final source = buildReceiptOcrResult(
        text: rows.map((row) => row.text).join('\n'),
        photoPath: path,
        rows: rows,
      ); // [OCR 추가]
      final draft = ReceiptDraft(
        id: 'kyobo',
        store: '교보',
        purchasedOn: '2026-10-04',
        lines: [],
        ocrResult: source,
      ); // [OCR 추가]
      await tester.pumpWidget(
        MaterialApp(home: ReceiptSelectionScreen(draft: draft)),
      ); // [OCR 추가]
      await loadRegion(tester); // [OCR 추가]
      expect(
        find.byKey(const ValueKey('ocr-box-amount')),
        findsOneWidget,
      ); // [OCR 추가]
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('ocr-candidate-first')),
        100,
        scrollable: find.byType(Scrollable).last,
      ); // [OCR 수정]
      await tester.tap(
        find.byKey(const ValueKey('ocr-candidate-first')),
      ); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      await tester.tap(find.text('수량 영역 지정·수정')); // [OCR 추가]
      await loadRegion(tester); // [OCR 추가]
      if (cancel) {
        await tester.binding.handlePopRoute(); // [OCR 추가]
      } else {
        await tester.tapAt(
          tester.getTopLeft(find.byKey(const ValueKey('region-photo'))) +
              const Offset(100, 100),
        ); // [OCR 추가]
        await tester.pump(); // [OCR 추가]
        await tester.enterText(
          find.byKey(const ValueKey('region-value')),
          '1',
        ); // [OCR 추가]
        await tester.tap(find.text('적용')); // [OCR 추가]
      }
      await tester.pumpAndSettle(); // [OCR 추가]
      if (cancel) {
        expect(find.text('수량 영역 지정·수정'), findsOneWidget); // [OCR 추가]
      } else {
        expect(find.text('금액 영역 지정·수정'), findsOneWidget); // [OCR 추가]
        expect(
          find.byKey(const ValueKey('ocr-box-amount')),
          findsOneWidget,
        ); // [OCR 추가]
        expect(
          source.numbers.singleWhere((number) => number.id == 'amount').number,
          9600,
        ); // [OCR 추가]
        final amountButton = find.byKey(
          const ValueKey('ocr-candidate-amount'),
        ); // [OCR 수정]
        await tester.scrollUntilVisible(
          amountButton,
          100,
          scrollable: find.byType(Scrollable).last,
        ); // [OCR 수정]
        await tester.pumpAndSettle(); // [OCR 수정]
        await tester.tap(amountButton); // [OCR 수정]
        await tester.pumpAndSettle(); // [OCR 추가]
        expect(find.text('선택한 금액: 9,600원'), findsOneWidget); // [OCR 추가]
      }
      expect(source.rows[2].tokens.single.text, '9.600'); // [OCR 추가]
      expect(draft.lines, isEmpty); // [OCR 추가] 검토 확정 전 원본 초안은 수정하지 않는다.
      expect(tester.takeException(), isNull); // [OCR 추가]
    });
  }
}
