import 'dart:io'; // [OCR 추가]
import 'package:flutter/services.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/ocr_service.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto; // [OCR 추가]

ReceiptOcrRow textRow(
  String id,
  String text,
  Rect bounds, {
  double? angle,
}) => // [OCR 추가]
ReceiptOcrRow(
  // [OCR 추가]
  id: id, // [OCR 추가]
  text: text, // [OCR 추가]
  bounds: bounds, // [OCR 추가]
  tokens: [
    // [OCR 추가]
    ReceiptOcrToken(
      id: id,
      text: text,
      bounds: bounds,
      angle: angle,
    ), // [OCR 추가]
  ], // [OCR 추가]
); // [OCR 추가]
ReceiptOcrResult recognizeRows(List<ReceiptOcrRow> rows) => // [OCR 추가]
buildReceiptOcrResult(
  // [OCR 추가]
  text: rows.map((row) => row.text).join('\n'), // [OCR 추가]
  photoPath: '/receipt.png', // [OCR 추가]
  rows: rows, // [OCR 추가]
); // [OCR 추가]
void main() {
  // [OCR 추가]
  // [OCR 추가]
  TestWidgetsFlutterBinding.ensureInitialized(); // [OCR 추가]
  test('세로 회전한 이름·숫자는 제외하고 가로 기울기와 원본 좌표·각도는 보존한다', () {
    // [OCR 추가]
    // [OCR 추가]
    final rows = [
      // [OCR 추가]
      // [OCR 추가]
      textRow(
        // [OCR 추가]
        'vertical-name', // [OCR 추가]
        '상품명', // [OCR 추가]
        const Rect.fromLTWH(10, 10, 80, 20), // [OCR 추가]
        angle: 90, // [OCR 추가]
      ), // [OCR 추가]
      textRow(
        // [OCR 추가]
        'vertical-number', // [OCR 추가]
        '12000', // [OCR 추가]
        const Rect.fromLTWH(10, 40, 80, 20), // [OCR 추가]
        angle: -90, // [OCR 추가]
      ), // [OCR 추가]
      textRow(
        // [OCR 추가]
        'name', // [OCR 추가]
        '퍼실', // [OCR 추가]
        const Rect.fromLTWH(100, 10, 80, 20), // [OCR 추가]
        angle: 8, // [OCR 추가]
      ), // [OCR 추가]
      textRow(
        // [OCR 추가]
        'amount', // [OCR 추가]
        '26,980', // [OCR 추가]
        const Rect.fromLTWH(220, 10, 80, 20), // [OCR 추가]
        angle: -8, // [OCR 추가]
      ), // [OCR 추가]
      textRow(
        // [OCR 추가]
        'upside', // [OCR 추가]
        '우유', // [OCR 추가]
        const Rect.fromLTWH(100, 50, 80, 20), // [OCR 추가]
        angle: 180, // [OCR 추가]
      ), // [OCR 추가]
    ]; // [OCR 추가]
    final result = recognizeRows(rows); // [OCR 추가]
    expect(result.products.map((candidate) => candidate.text), [
      // [OCR 추가]
      '퍼실', // [OCR 추가]
      '우유', // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.numbers.single.number, 26980); // [OCR 추가]
    expect(result.rows, rows); // [OCR 추가]
    expect(result.rows.first.tokens.single.angle, 90); // [OCR 추가]
    expect(
      // [OCR 추가]
      result.rows.first.tokens.single.bounds, // [OCR 추가]
      rows.first.bounds, // [OCR 추가]
    ); // [OCR 추가]
    expect(result.text, contains('상품명\n12000')); // [OCR 추가]
  }); // [OCR 추가]
  test('세로로 긴 여러 글자는 제외하고 좁은 숫자·한 글자 이름은 유지한다', () {
    // [OCR 추가]
    // [OCR 추가]
    final rows = [
      // [OCR 추가]
      // [OCR 추가]
      textRow(
        // [OCR 추가]
        'vertical', // [OCR 추가]
        '세로품명', // [OCR 추가]
        const Rect.fromLTWH(10, 10, 20, 80), // [OCR 추가]
      ), // [OCR 추가]
      textRow(
        // [OCR 추가]
        'upright', // [OCR 추가]
        '면세', // [OCR 추가]
        const Rect.fromLTWH(50, 10, 20, 48), // [OCR 추가]
        angle: 0, // [OCR 추가]
      ), // [OCR 추가]
      textRow('quantity', '1', const Rect.fromLTWH(100, 10, 8, 20)), // [OCR 추가]
      textRow('narrow', '11', const Rect.fromLTWH(130, 10, 12, 20)), // [OCR 추가]
      textRow('short', '쌀', const Rect.fromLTWH(180, 10, 16, 20)), // [OCR 추가]
      textRow('name', '퍼실', const Rect.fromLTWH(210, 10, 60, 20)), // [OCR 추가]
      textRow(
        // [OCR 추가]
        'vertical-number', // [OCR 추가]
        '12000', // [OCR 추가]
        const Rect.fromLTWH(280, 10, 12, 80), // [OCR 추가]
      ), // [OCR 추가] // [OCR 추가]
    ]; // [OCR 추가]
    final result = recognizeRows(rows); // [OCR 추가]
    expect(result.products.map((candidate) => candidate.text), [
      // [OCR 추가]
      '쌀', // [OCR 추가]
      '퍼실', // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.numbers.map((candidate) => candidate.number), [
      // [OCR 추가]
      1, // [OCR 추가]
      11, // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.rows, hasLength(7)); // [OCR 추가]
  }); // [OCR 추가]
  test('한 글자씩 떨어진 촘촘한 세로 열은 제외하고 가로 글자·수량 열·떨어진 상품명은 유지한다', () {
    // [OCR 추가]
    // [OCR 추가]
    final rows = [
      // [OCR 추가]
      // [OCR 추가]
      for (var i = 0; i < 3; i++) // [OCR 추가]
        textRow(
          // [OCR 추가]
          'vertical-$i', // [OCR 추가]
          ['부', '가', '세'][i], // [OCR 추가]
          Rect.fromLTWH(10, 100 + i * 24, 20, 20), // [OCR 추가]
        ), // [OCR 추가]
      for (var i = 0; i < 3; i++) // [OCR 추가]
        textRow(
          // [OCR 추가]
          'horizontal-$i', // [OCR 추가]
          ['상', '품', '명'][i], // [OCR 추가]
          Rect.fromLTWH(100 + i * 30, 100, 20, 20), // [OCR 추가]
        ), // [OCR 추가]
      for (var i = 0; i < 3; i++) // [OCR 추가]
        textRow(
          // [OCR 추가]
          'quantity-$i', // [OCR 추가]
          '1', // [OCR 추가]
          Rect.fromLTWH(300, 100 + i * 24, 8, 20), // [OCR 추가]
        ), // [OCR 추가]
      for (var i = 0; i < 3; i++) // [OCR 추가]
        textRow(
          // [OCR 추가]
          'product-$i', // [OCR 추가]
          ['쌀', '물', '차'][i], // [OCR 추가]
          Rect.fromLTWH(10, 300 + i * 50, 20, 20), // [OCR 추가]
        ), // [OCR 추가]
    ]; // [OCR 추가]
    final result = recognizeRows(rows); // [OCR 추가]
    expect(result.products.map((candidate) => candidate.text), [
      // [OCR 추가]
      '상', // [OCR 추가]
      '품', // [OCR 추가]
      '명', // [OCR 추가]
      '쌀', // [OCR 추가]
      '물', // [OCR 추가]
      '차', // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.numbers.map((candidate) => candidate.number), [
      // [OCR 추가]
      1, // [OCR 추가]
      1, // [OCR 추가]
      1, // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.rows, hasLength(12)); // [OCR 추가]
    expect(receiptHorizontalText(result), isNot(contains('부'))); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('모의 ML Kit: 줄 각도 fallback을 보존하고 부분 OCR도 세로 글씨만 읽히면 빈 결과를 반환한다', (
    // [OCR 추가]
    tester, // [OCR 추가]
  ) async {
    // [OCR 추가]
    // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    const channel = MethodChannel('google_mlkit_text_recognizer'); // [OCR 추가]
    final messenger =
        TestDefaultBinaryMessengerBinding // [OCR 추가]
            .instance // [OCR 추가]
            .defaultBinaryMessenger; // [OCR 추가]
    var verticalOnly = false; // [OCR 추가]
    var closes = 0; // [OCR 추가]
    Map<String, dynamic> line(String text, double angle) => {
      // [OCR 추가]
      // [OCR 추가]
      'text': text, // [OCR 추가]
      'rect': {
        'left': 0.0,
        'top': 0.0,
        'right': 80.0,
        'bottom': 20.0,
      }, // [OCR 추가]
      'recognizedLanguages': <String>[], // [OCR 추가]
      'points': [], // [OCR 추가]
      'angle': angle, // [OCR 추가]
      'elements': [], // [OCR 추가]
    }; // [OCR 추가]
    messenger.setMockMethodCallHandler(channel, (call) async {
      // [OCR 추가]
      // [OCR 추가]
      if (call.method == 'vision#closeTextRecognizer') {
        // [OCR 추가]
        closes++; // [OCR 추가]
        return null; // [OCR 추가]
      } // [OCR 추가]
      final lines = [
        // [OCR 추가]
        line('할인', 90), // [OCR 추가]
        if (!verticalOnly) line('2', 0), // [OCR 추가]
      ]; // [OCR 추가]
      return {
        // [OCR 추가]
        'text': verticalOnly ? '할인' : '할인\n2', // [OCR 추가]
        'blocks': [
          // [OCR 추가]
          {
            // [OCR 추가]
            'text': '할인\n2', // [OCR 추가]
            'rect': {
              'left': 0.0,
              'top': 0.0,
              'right': 80.0,
              'bottom': 20.0,
            }, // [OCR 추가]
            'recognizedLanguages': <String>[], // [OCR 추가]
            'points': [], // [OCR 추가]
            'lines': lines, // [OCR 추가]
          }, // [OCR 추가]
        ], // [OCR 추가]
      }; // [OCR 추가]
    }); // [OCR 추가]
    addTearDown(
      // [OCR 추가]
      () => messenger.setMockMethodCallHandler(channel, null), // [OCR 추가]
    ); // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      // [OCR 추가]
      final service = OcrService(); // [OCR 추가]
      final result = await service.recognizePath(path); // [OCR 추가]
      expect(result.ocrResult!.text, '할인\n2'); // [OCR 추가]
      expect(result.ocrResult!.products, isEmpty); // [OCR 추가]
      expect(result.ocrResult!.numbers.single.number, 2); // [OCR 추가]
      expect(result.ocrResult!.rows.first.tokens.single.angle, 90); // [OCR 추가]
      final bytes = await File(path).readAsBytes(); // [OCR 추가]
      expect(
        // [OCR 추가]
        await service.recognizeRegion(
          // [OCR 추가]
          bytes, // [OCR 추가]
          const Rect.fromLTWH(40, 50, 80, 30), // [OCR 추가]
        ), // [OCR 추가]
        '2', // [OCR 추가]
      ); // [OCR 추가]
      verticalOnly = true; // [OCR 추가]
      expect(
        // [OCR 추가]
        await service.recognizeRegion(
          // [OCR 추가]
          bytes, // [OCR 추가]
          const Rect.fromLTWH(40, 50, 80, 30), // [OCR 추가]
        ), // [OCR 추가]
        isEmpty, // [OCR 추가]
      ); // [OCR 추가]
      expect(closes, 3); // [OCR 추가]
    }); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
