import 'dart:typed_data'; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:shared_preferences/shared_preferences.dart'; // [OCR 추가]
import 'package:how_much/app_store.dart'; // [OCR 추가]
import 'package:how_much/cloud_service.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_region_retry.dart'; // [OCR 추가]
import 'package:how_much/receipt_region_screen.dart'; // [OCR 추가]
import 'package:how_much/screens.dart'; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto, loadRegion; // [OCR 추가]

void main() {
  test('날짜는 시간을 제외해 정규화하고 월일 넘침·미래·날짜 없는 글자는 거절한다', () {
    // [OCR 추가] 문자열 파서의 자동 날짜 보정이 잘못된 구매일로 저장되지 않게 한다.
    expect(
      receiptRegionDate('[판매] 2024.2.29 13:54:37'),
      '2024-02-29',
    ); // [OCR 추가]
    expect(receiptRegionDate('2024 / 1 / 2'), '2024-01-02'); // [OCR 추가]
    for (final text in [
      '2023-02-29',
      '2024-13-01',
      '2024-04-31',
      '2099-01-01',
      '1544-1900',
      '20240229',
    ]) {
      expect(receiptRegionDate(text), isNull); // [OCR 추가]
    }
  });

  test('날짜 재인식은 잘못된 날짜를 넘기고 첫 유효 날짜에서 중단한다', () async {
    // [OCR 추가] 모의 OCR 응답이며 실제 사진 인식률을 검증하지 않는다.
    var calls = 0; // [OCR 추가]
    final replies = [
      '구매 영수증',
      '2023-02-29',
      '2024.2.29 14:00',
      '2024-03-01',
    ]; // [OCR 추가]
    final read = await readReceiptRegionRepeatedly(
      photoBytes: Uint8List(0), // [OCR 추가]
      photoSize: const Size(400, 600), // [OCR 추가]
      bounds: const Rect.fromLTWH(40, 50, 180, 30), // [OCR 추가]
      date: true, // [OCR 추가]
      recognize: (_, _) async => replies[calls++], // [OCR 추가]
      isCurrent: () => true, // [OCR 추가]
    ); // [OCR 추가]
    expect(calls, 3); // [OCR 추가]
    expect(read!.candidates.single.text, '2024-02-29'); // [OCR 추가]
    expect(read.successes, 1); // [OCR 추가]
  });

  testWidgets('검토 날짜 영역은 적용 후 복원되며 취소·잘못된 입력은 날짜를 바꾸지 않는다', (tester) async {
    // [OCR 추가] 검토 화면과 영역 편집을 연결해 취소 시 데이터 손실과 잘못된 날짜 적용을 검사한다.
    SharedPreferences.setMockInitialValues({}); // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    const bounds = Rect.fromLTWH(40, 50, 180, 30); // [OCR 추가]
    final draft = ReceiptDraft(
      id: 'date-test',
      store: '매장',
      purchasedOn: '2024-01-01',
      lines: [], // [OCR 추가]
      ocrResult: ReceiptOcrResult(
        text: '2024-02-29 13:54',
        photoPath: path,
        products: [],
        numbers: [], // [OCR 추가]
        rows: [
          ReceiptOcrRow(
            id: 'date',
            text: '2024-02-29 13:54',
            bounds: bounds,
            tokens: [],
          ),
        ], // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptReviewScreen(store: store, draft: draft),
      ),
    ); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    final edit = find.byKey(const ValueKey('receipt-date-region')); // [OCR 추가]
    await tester.ensureVisible(edit); // [OCR 추가]
    await tester.tap(edit); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    expect(
      tester
          .widget<ReceiptRegionScreen>(find.byType(ReceiptRegionScreen))
          .initialBounds,
      bounds,
    ); // [OCR 추가]
    final input = find.byKey(const ValueKey('region-value')); // [OCR 추가]
    await tester.enterText(input, '2023-02-29'); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(find.text('구매일은 오늘까지의 실제 날짜로 입력해주세요.'), findsOneWidget); // [OCR 추가]
    await tester.enterText(input, '2024.2.29'); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      find.widgetWithText(TextField, '2024-02-29'),
      findsOneWidget,
    ); // [OCR 추가]
    expect(draft.purchasedOn, '2024-01-01'); // [OCR 추가] 저장 전에는 원본 초안도 변경하지 않는다.
    await tester.tap(edit); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    final restored = tester.widget<ReceiptRegionScreen>(
      find.byType(ReceiptRegionScreen),
    ); // [OCR 추가]
    expect(restored.initialBounds, bounds); // [OCR 추가]
    expect(restored.initialText, '2024-02-29'); // [OCR 추가]
    await tester.enterText(input, '2024-03-01'); // [OCR 추가]
    Navigator.of(
      tester.element(find.byType(ReceiptRegionScreen)),
    ).pop(); // [OCR 추가] 시스템 뒤로 가기와 동일하게 결과 없이 취소한다.
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      find.widgetWithText(TextField, '2024-02-29'),
      findsOneWidget,
    ); // [OCR 추가]
  });
}
