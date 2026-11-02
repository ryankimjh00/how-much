import 'dart:io'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/services.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_product_regions.dart'; // [OCR 추가]
import 'package:how_much/ocr_service.dart'; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto; // [OCR 추가]

ReceiptOcrRow row(String id, String text, ui.Rect bounds) => ReceiptOcrRow(
  // [OCR 추가]
  id: id, // [OCR 추가]
  text: text, // [OCR 추가]
  bounds: bounds, // [OCR 추가]
  tokens: [ReceiptOcrToken(id: id, text: text, bounds: bounds)], // [OCR 추가]
); // [OCR 추가]
ReceiptOcrResult result(List<ReceiptOcrRow> rows) => buildReceiptOcrResult(
  // [OCR 추가]
  text: rows.map((row) => row.text).join('\n'), // [OCR 추가]
  photoPath: '/test.jpg', // [OCR 추가]
  rows: rows, // [OCR 추가]
); // [OCR 추가]
void main() {
  // [OCR 추가]
  // [OCR 추가]
  test('실제 측정 좌표의 스녀·섬유유연제 영역을 합치고 다음 행·숫자는 보존한다', () {
    // [OCR 추가]
    // [OCR 추가]
    final original = result([
      // [OCR 추가]
      // [OCR 추가]
      row(
        // [OCR 추가]
        'first', // [OCR 추가]
        '스녀', // [OCR 추가]
        const ui.Rect.fromLTRB(104, 589, 168, 616), // [OCR 추가]
      ), // [OCR 추가]
      row(
        // [OCR 추가]
        'second', // [OCR 추가]
        '섬으 유연제 를', // [OCR 추가]
        const ui.Rect.fromLTRB(222, 589, 432, 629), // [OCR 추가]
      ), // [OCR 추가]
      row(
        // [OCR 추가]
        'next', // [OCR 추가]
        '닥터버를얼티케어칫솔', // [OCR 추가]
        const ui.Rect.fromLTRB(89, 615, 456, 663), // [OCR 추가]
      ), // [OCR 추가]
      row(
        // [OCR 추가]
        'unit', // [OCR 추가]
        '18,980', // [OCR 추가]
        const ui.Rect.fromLTRB(483, 594, 579, 628), // [OCR 추가]
      ), // [OCR 추가]
      row(
        // [OCR 추가]
        'price', // [OCR 추가]
        '37,960', // [OCR 추가]
        const ui.Rect.fromLTRB(711, 586, 812, 631), // [OCR 추가]
      ), // [OCR 추가]
    ]); // [OCR 추가]
    final merged = mergeReceiptProductRegions(original); // [OCR 추가]
    expect(merged.products, hasLength(2)); // [OCR 추가]
    expect(
      // [OCR 추가]
      merged.products.first.bounds, // [OCR 추가]
      const ui.Rect.fromLTRB(104, 589, 432, 629), // [OCR 추가]
    ); // [OCR 추가]
    expect(merged.products.first.text, '스녀 섬으 유연제 를'); // [OCR 추가]
    expect(merged.products.first.id, 'first'); // [OCR 추가]
    expect(merged.products.first.isMergedName, isTrue); // [OCR 추가]
    expect(merged.products.last.id, 'next'); // [OCR 추가]
    expect(merged.numbers, original.numbers); // [OCR 추가]
    expect(merged.rows, original.rows); // [OCR 추가]
    expect(original.products, hasLength(3)); // [OCR 추가]
  }); // [OCR 추가]
  test('숫자·콤마·부호가 중간에 있으면 변환 성공 여부와 관계없이 이름을 합치지 않는다', () {
    // [OCR 추가]
    // [OCR 추가]
    for (final value in [
      // [OCR 추가]
      '2', // [OCR 추가]
      '15,000', // [OCR 추가]
      '-15,000', // [OCR 추가]
      '+15,000', // [OCR 추가]
      '−15,000', // [OCR 추가]
      '12,00', // [OCR 추가]
      '12，000', // [OCR 추가]
      '12，00', // [OCR 추가]
      '－15,000', // [OCR 추가]
      '￦12，000원', // [OCR 추가]
      ',', // [OCR 추가]
      '-', // [OCR 추가]
    ]) {
      // [OCR 추가]
      // [OCR 추가]
      final merged = mergeReceiptProductRegions(
        // [OCR 추가]
        result([
          // [OCR 추가]
          // [OCR 추가]
          row('a', '앞이름', const ui.Rect.fromLTWH(100, 100, 80, 30)), // [OCR 추가]
          row(
            // [OCR 추가]
            'barrier', // [OCR 추가]
            value, // [OCR 추가]
            const ui.Rect.fromLTWH(190, 100, 20, 30), // [OCR 추가]
          ), // [OCR 추가]
          row('b', '뒤이름', const ui.Rect.fromLTWH(220, 100, 80, 30)), // [OCR 추가]
        ]), // [OCR 추가]
      ); // [OCR 추가]
      expect(merged.products.map((candidate) => candidate.text), [
        // [OCR 추가]
        '앞이름', // [OCR 추가]
        '뒤이름', // [OCR 추가]
      ], reason: value); // [OCR 추가]
      expect(
        // [OCR 추가]
        merged.products.every(
          (candidate) => !candidate.isMergedName,
        ), // [OCR 추가]
        isTrue, // [OCR 추가]
        reason: value, // [OCR 추가]
      ); // [OCR 추가]
    } // [OCR 추가]
  }); // [OCR 추가]
  test('연쇄 겹침은 첫 행 기준을 유지하고 다른 열·이웃 행으로 번지지 않는다', () {
    // [OCR 추가]
    // [OCR 추가]
    final merged = mergeReceiptProductRegions(
      // [OCR 추가]
      result([
        // [OCR 추가]
        // [OCR 추가]
        row('a', '가상품', const ui.Rect.fromLTWH(100, 100, 100, 30)), // [OCR 추가]
        row(
          // [OCR 추가]
          'col', // [OCR 추가]
          '다른열', // [OCR 추가]
          const ui.Rect.fromLTWH(400, 100, 100, 30), // [OCR 추가]
        ), // [OCR 추가]
        row(
          // [OCR 추가]
          'part', // [OCR 추가]
          '가상품 일부', // [OCR 추가]
          const ui.Rect.fromLTWH(110, 108, 100, 30), // [OCR 추가]
        ), // [OCR 추가]
        row('b', '나상품', const ui.Rect.fromLTWH(100, 116, 100, 30)), // [OCR 추가]
        row('c', '다상품', const ui.Rect.fromLTWH(100, 142, 100, 30)), // [OCR 추가]
      ]), // [OCR 추가]
    ); // [OCR 추가]
    expect(merged.products.map((candidate) => candidate.text), [
      // [OCR 추가]
      '가상품 일부', // [OCR 추가]
      '다른열', // [OCR 추가]
      '나상품', // [OCR 추가]
      '다상품', // [OCR 추가]
    ]); // [OCR 추가]
  }); // [OCR 추가]
  test('재인식 실패·빈값·숫자만인 값은 기존 이름을 보존하고 성공한 영역만 교체한다', () async {
    // [OCR 추가]
    // [OCR 추가]
    final rows = <ReceiptOcrRow>[]; // [OCR 추가]
    for (var i = 0; i < 4; i++) {
      // [OCR 추가]
      rows.add(
        // [OCR 추가]
        row(
          'name-$i',
          '이름$i',
          ui.Rect.fromLTWH(100, i * 100.0, 100, 30),
        ), // [OCR 추가]
      ); // [OCR 추가]
      rows.add(
        // [OCR 추가]
        row(
          'part-$i',
          '추가$i',
          ui.Rect.fromLTWH(220, i * 100.0, 80, 30),
        ), // [OCR 추가]
      ); // [OCR 추가]
    } // [OCR 추가]
    final merged = mergeReceiptProductRegions(result(rows)); // [OCR 추가]
    final calls = <ui.Rect>[]; // [OCR 추가]
    final reread = await rereadMergedProductNames(merged, (bounds) async {
      // [OCR 추가]
      // [OCR 추가]
      calls.add(bounds); // [OCR 추가]
      switch (calls.length) {
        // [OCR 추가]
        case 1: // [OCR 추가]
          throw StateError('인식 실패'); // [OCR 추가]
        case 2: // [OCR 추가]
          return ''; // [OCR 추가]
        case 3: // [OCR 추가]
          return '1234'; // [OCR 추가]
        default: // [OCR 추가]
          return '  스너글\n섬유유연제  '; // [OCR 추가]
      } // [OCR 추가]
    }); // [OCR 추가]
    expect(calls, hasLength(4)); // [OCR 추가]
    expect(
      // [OCR 추가]
      reread.products.take(3).map((candidate) => candidate.text), // [OCR 추가]
      merged.products.take(3).map((candidate) => candidate.text), // [OCR 추가]
    ); // [OCR 추가]
    expect(reread.products.last.text, '스너글 섬유유연제'); // [OCR 추가]
    expect(
      // [OCR 추가]
      reread.products.last.bounds, // [OCR 추가]
      merged.products.last.bounds, // [OCR 추가]
    ); // [OCR 추가]
    expect(reread.products.last.id, merged.products.last.id); // [OCR 추가]
    expect(merged.products.last.text, '이름3 추가3'); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('모의 네이티브: 합친 영역만 원본 크기로 다시 읽고 실패도 인식기·임시 파일을 정리한다', (
    // [OCR 추가]
    tester, // [OCR 추가]
  ) async {
    // [OCR 추가]
    // [OCR 추가]
    final path = await regionPhoto(
      // [OCR 추가]
      tester, // [OCR 추가]
      width: 1200, // [OCR 추가]
      height: 800, // [OCR 추가]
    ); // [OCR 추가]
    const channel = MethodChannel('google_mlkit_text_recognizer'); // [OCR 추가]
    final messenger =
        TestDefaultBinaryMessengerBinding // [OCR 추가]
            .instance // [OCR 추가]
            .defaultBinaryMessenger; // [OCR 추가]
    var closes = 0; // [OCR 추가]
    var fail = false; // [OCR 추가]
    final croppedPaths = <String>[]; // [OCR 추가]
    Map<String, Object> part(String text, ui.Rect bounds) => {
      // [OCR 추가]
      'text': text, // [OCR 추가]
      'rect': {
        // [OCR 추가]
        'left': bounds.left, // [OCR 추가]
        'top': bounds.top, // [OCR 추가]
        'right': bounds.right, // [OCR 추가]
        'bottom': bounds.bottom, // [OCR 추가]
      }, // [OCR 추가]
      'recognizedLanguages': <String>[], // [OCR 추가]
      'points': [], // [OCR 추가]
      'symbols': [], // [OCR 추가]
    }; // [OCR 추가]
    messenger.setMockMethodCallHandler(channel, (call) async {
      // [OCR 추가]
      // [OCR 추가]
      if (call.method == 'vision#closeTextRecognizer') {
        // [OCR 추가]
        closes++; // [OCR 추가]
        return null; // [OCR 추가]
      } // [OCR 추가]
      final args = call.arguments as Map; // [OCR 추가]
      final imagePath = // [OCR 추가]
          (args['imageData'] as Map)['path'] as String; // [OCR 추가]
      final codec = await ui.instantiateImageCodec(
        // [OCR 수정]
        await File(imagePath).readAsBytes(), // [OCR 수정]
      ); // [OCR 수정]
      final frame = await codec.getNextFrame(); // [OCR 수정]
      final width = frame.image.width; // [OCR 수정]
      final height = frame.image.height; // [OCR 수정]
      frame.image.dispose(); // [OCR 수정]
      codec.dispose(); // [OCR 수정]
      if (width == 328 && height == 40) {
        // [OCR 수정]
        croppedPaths.add(imagePath); // [OCR 수정]
        if (fail) throw PlatformException(code: 'region-failed'); // [OCR 추가]
        return {'text': '스너글 섬유유연제', 'blocks': []}; // [OCR 추가]
      } // [OCR 추가]
      expect(width, 1600); // [OCR 추가]
      expect(height, 1067); // [OCR 추가]
      final pieces = [
        // [OCR 추가]
        part('스녀', const ui.Rect.fromLTRB(104, 589, 168, 616)), // [OCR 추가]
        part(
          '섬으 유연제 를',
          const ui.Rect.fromLTRB(222, 589, 432, 629),
        ), // [OCR 추가]
        part('37,960', const ui.Rect.fromLTRB(711, 586, 812, 631)), // [OCR 추가]
      ]; // [OCR 추가]
      final bounds = const ui.Rect.fromLTRB(104, 586, 812, 631); // [OCR 추가]
      return {
        // [OCR 추가]
        'text': '스녀 섬으 유연제 를 37,960', // [OCR 추가]
        'blocks': [
          // [OCR 추가]
          {
            // [OCR 추가]
            ...part('스녀 섬으 유연제 를 37,960', bounds), // [OCR 추가]
            'lines': [
              // [OCR 추가]
              {
                ...part('스녀 섬으 유연제 를 37,960', bounds),
                'elements': pieces,
              }, // [OCR 추가]
            ], // [OCR 추가]
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
      final before = await File(path).readAsBytes(); // [OCR 추가]
      final draft = await OcrService().recognizePath(path); // [OCR 추가]
      expect(draft.ocrResult!.products.single.text, '스너글 섬유유연제'); // [OCR 추가]
      expect(draft.ocrResult!.numbers.single.number, 37960); // [OCR 추가]
      expect(closes, 1); // [OCR 수정] 전체·병합 재인식을 한 세션으로 처리한다. // [OCR 추가]
      expect(croppedPaths, hasLength(1)); // [OCR 추가]
      expect(await File(croppedPaths.single).exists(), isFalse); // [OCR 추가]
      expect(await File(path).readAsBytes(), before); // [OCR 추가]
      fail = true; // [OCR 추가]
      final fallback = await OcrService().recognizePath(path); // [OCR 추가]
      expect(
        // [OCR 추가]
        fallback.ocrResult!.products.single.text, // [OCR 추가]
        '스녀 섬으 유연제 를', // [OCR 추가]
      ); // [OCR 추가]
      expect(closes, 2); // [OCR 수정] 두 사진은 별도 세션으로 각각 해제한다. // [OCR 추가]
      expect(await File(croppedPaths.last).exists(), isFalse); // [OCR 추가]
    }); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
