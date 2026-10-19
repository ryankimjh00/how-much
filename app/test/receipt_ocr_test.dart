import 'receipt_region_test.dart' show regionPhoto; // [OCR 추가]
import 'package:flutter/services.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // [OCR 추가]
import 'package:how_much/ocr_service.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]

ReceiptOcrRow row(
  // [OCR 추가]
  List<String> texts, { // [OCR 추가]
  double top = 0, // [OCR 추가]
  double spacing = 100, // [OCR 추가]
}) => // [OCR 추가]
ReceiptOcrRow(
  // [OCR 추가]
  id: 'row-$top', // [OCR 추가]
  text: texts.join(' '), // [OCR 추가]
  bounds: Rect.fromLTWH(0, top, 800, 20), // [OCR 추가]
  tokens: [
    // [OCR 추가]
    for (var i = 0; i < texts.length; i++) // [OCR 추가]
      ReceiptOcrToken(
        // [OCR 추가]
        id: 'row-$top-token-$i', // [OCR 추가]
        text: texts[i], // [OCR 추가]
        bounds: Rect.fromLTWH(i * spacing, top, 40, 20), // [OCR 추가]
      ), // [OCR 추가]
  ], // [OCR 추가]
); // [OCR 추가]
ReceiptOcrResult resultFor(List<ReceiptOcrRow> rows) => buildReceiptOcrResult(
  // [OCR 추가]
  text: rows.map((r) => r.text).join('\n'), // [OCR 추가]
  photoPath: '/test/photo.jpg', // [OCR 추가]
  rows: rows, // [OCR 추가]
); // [OCR 추가]
void main() {
  // [OCR 추가]
  TestWidgetsFlutterBinding.ensureInitialized(); // [OCR 추가]
  test('실제 삼선짜장 좌표 회귀: 나뉜 금액과 수량을 포함한 첫 아래 행을 건너뛰지 않는다', () {
    // [OCR 추가]
    // [OCR 추가] 실제 측정 좌표를 재생한다. ML Kit를 새로 호출하는 사진 인식 테스트는 아니다.
    ReceiptOcrRow measured(String id, String text, Rect bounds) =>
        ReceiptOcrRow(
          // [OCR 추가]
          id: id,
          text: text,
          bounds: bounds, // [OCR 추가]
          tokens: [
            ReceiptOcrToken(id: id, text: text, bounds: bounds),
          ], // [OCR 추가]
        ); // [OCR 추가]
    final result = resultFor([
      // [OCR 추가]
      // [OCR 추가] 원본 전체의 글자 높이 중앙값 53px를 재현한다. 행 경계 오차 0.3px의 회귀 조건이다.
      for (var index = 0; index < 5; index++) // [OCR 추가]
        measured(
          'header-$index',
          '머리',
          Rect.fromLTWH(50, 100 + index * 80, 100, 53),
        ), // [OCR 추가]
      measured(
        'name',
        '삼선파장',
        const Rect.fromLTRB(293, 839, 481, 894),
      ), // [OCR 추가]
      measured(
        'code',
        '000001',
        const Rect.fromLTRB(57, 843, 207, 888),
      ), // [OCR 추가]
      measured(
        'left-price',
        '12,000',
        const Rect.fromLTRB(60, 902, 212, 944),
      ), // [OCR 추가]
      measured(
        'quantity',
        '1',
        const Rect.fromLTRB(490, 902, 505, 941),
      ), // [OCR 추가]
      measured(
        'discount',
        '0',
        const Rect.fromLTRB(785, 886, 810, 928),
      ), // [OCR 추가]
      measured(
        'right-price-part',
        '12,',
        const Rect.fromLTRB(991, 870, 1050, 926),
      ), // [OCR 추가]
      measured(
        'right-price-part-2',
        '000',
        const Rect.fromLTRB(1051, 867, 1134, 923),
      ), // [OCR 추가]
      measured(
        'next-code',
        '000007',
        const Rect.fromLTRB(54, 957, 209, 1001),
      ), // [OCR 추가]
      measured(
        'next-name',
        '제로펩시',
        const Rect.fromLTRB(290, 955, 478, 1007),
      ), // [OCR 추가]
      measured(
        'next-price',
        '2,000',
        const Rect.fromLTRB(994, 998, 1130, 1044),
      ), // [OCR 추가]
    ]); // [OCR 추가]
    final product = result.products.firstWhere(
      (item) => item.id == 'name',
    ); // [OCR 추가]
    final candidates = receiptPricesNear(result, product); // [OCR 추가]
    expect(candidates.map((item) => item.id), contains('quantity')); // [OCR 추가]
    expect(
      candidates.map((item) => item.id),
      contains('left-price'),
    ); // [OCR 추가]
    expect(
      candidates.map((item) => item.id),
      isNot(contains('next-price')),
    ); // [OCR 추가]
  }); // [OCR 추가]
  test('숫자 10자리 이상과 영문자 하나인 코드는 분리 인식돼도 상품명에서 제외한다', () {
    // [OCR 추가] 실제 사진 대신 합성 OCR로 코드 제외와 경계값·한글 상품명 보존을 검사한다.
    final result = resultFor([
      row(['1234567890A'], top: 0), // [OCR 추가]
      row(['b12345678901'], top: 30), // [OCR 추가]
      row(['1234567890', 'C'], top: 60), // [OCR 추가]
      row(['123456789D'], top: 90), // [OCR 추가]
      row(['AB1234567890'], top: 120), // [OCR 추가]
      row(['상품1234567890A'], top: 150), // [OCR 추가]
      row(['1L', '850g'], top: 180), // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.products.map((candidate) => candidate.text), [
      '123456789D', 'AB1234567890', '상품1234567890A', '1L', '850g', // [OCR 추가]
    ]); // [OCR 추가]
    expect(
      result.numbers.single.number,
      1234567890,
    ); // [OCR 추가] 숫자 후보와 OCR 원문은 기존대로 보존한다.
    expect(result.text, contains('1234567890A')); // [OCR 추가]
  }); // [OCR 추가]
  test('합성 OCR: 콤마·음수·수량 보존, 용량은 숫자 후보에서 제외', () {
    // [OCR 추가]
    final result = resultFor([
      // [OCR 추가]
      row(['퍼실', '3', '80,940', '-15,000', '1L', '850g']), // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.numbers.map((c) => c.number), [3, 80940, -15000]); // [OCR 추가]
    expect(result.products.map((c) => c.text), [
      // [OCR 추가]
      '퍼실', // [OCR 추가]
      '1L', // [OCR 추가]
      '850g', // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.text, '퍼실 3 80,940 -15,000 1L 850g'); // [OCR 추가]
  }); // [OCR 추가]
  test('교보 실측 표기 9.600을 천 단위로 보존하고 날짜·용량·소수는 바꾸지 않는다', () {
    // [OCR 추가] 실제 OCR에서 나온 표기를 재생하며 새 사진 인식 결과와 구분한다.
    final rows = [
      row(['9.600', '-15.000', '1.5', '2026.10.04', '1.000g']),
    ]; // [OCR 추가]
    final result = resultFor(rows); // [OCR 추가]
    expect(result.numbers.map((candidate) => candidate.number), [
      9600,
      -15000,
    ]); // [OCR 추가]
    expect(
      result.numbers.first.bounds,
      rows.first.tokens.first.bounds,
    ); // [OCR 추가]
    expect(
      result.rows.first.tokens.first.text,
      '9.600',
    ); // [OCR 추가] 원문을 덮어쓰지 않는다.
    expect(
      receiptSelectionAmount('9.600'),
      9600,
    ); // [OCR 추가] 부분 OCR과 선택 값에도 같은 규칙을 적용한다.
    for (final input in ['1.5', '1.25', '2026.10.04', '1.000g']) {
      expect(receiptSelectionAmount(input), isNull); // [OCR 추가]
    }
  });
  test('십만·백만 금액의 천 단위 점도 모두 콤마로 통일한다', () {
    // [OCR 추가] OCR 숫자 후보와 부분 인식 입력이 같은 값을 사용하고 원문은 보존한다.
    final values = {
      '100.000': 100000,
      '123.456': 123456,
      '1.234.567': 1234567,
      '9.999.999': 9999999,
    }; // [OCR 추가]
    for (final entry in values.entries) {
      final result = resultFor([
        row([entry.key]),
      ]); // [OCR 추가]
      expect(result.numbers.single.number, entry.value); // [OCR 추가]
      expect(
        result.numbers.single.text,
        entry.key.replaceAll('.', ','),
      ); // [OCR 추가]
      expect(receiptSelectionAmount(entry.key), entry.value); // [OCR 추가]
      expect(result.rows.single.tokens.single.text, entry.key); // [OCR 추가]
    }
  });
  test('합성 OCR: 가까운 콤마·부호 조각 결합, 원본 단어와 좌표 유지', () {
    // [OCR 추가]
    final result = resultFor([
      // [OCR 추가]
      row(['-', '12', ',', '000'], spacing: 42), // [OCR 추가]
      row(['1', '5000'], top: 40), // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.numbers.map((c) => c.number), [-12000, 1, 5000]); // [OCR 추가]
    expect(
      // [OCR 추가]
      result.numbers.first.bounds, // [OCR 추가]
      const Rect.fromLTWH(0, 0, 166, 20), // [OCR 추가]
    ); // [OCR 추가]
    expect(result.rows.first.tokens.map((t) => t.text), [
      // [OCR 추가]
      '-', // [OCR 추가]
      '12', // [OCR 추가]
      ',', // [OCR 추가]
      '000', // [OCR 추가]
    ]); // [OCR 추가]
  }); // [OCR 추가]
  test('합성 OCR: 같은 이름·숫자도 위치별 ID로 구분, 원본 불변', () {
    // [OCR 추가]
    final rows = [
      // [OCR 추가]
      row(['퍼실', '1']), // [OCR 추가]
      row(['퍼실', '1'], top: 40), // [OCR 추가]
    ]; // [OCR 추가]
    final result = resultFor(rows); // [OCR 추가]
    expect(result.products.map((c) => c.id).toSet(), hasLength(2)); // [OCR 추가]
    expect(result.numbers.map((c) => c.id).toSet(), hasLength(2)); // [OCR 추가]
    expect(result.numbers.map((c) => c.bounds.top), [0, 40]); // [OCR 추가]
    rows.clear(); // [OCR 추가]
    expect(result.rows, hasLength(2)); // [OCR 추가]
    expect(() => result.numbers.clear(), throwsUnsupportedError); // [OCR 추가]
  }); // [OCR 추가]
  test('합성 OCR: 다른 줄과 멀리 떨어진 숫자는 결합하지 않는다', () {
    // [OCR 추가]
    final result = resultFor([
      // [OCR 추가]
      row(['12,', '000']), // [OCR 추가]
      row(['-'], top: 40), // [OCR 추가]
      row(['15000'], top: 80), // [OCR 추가]
    ]); // [OCR 추가]
    expect(result.numbers.map((c) => c.number), [0, 15000]); // [OCR 추가]
    expect(result.rows.first.tokens.first.text, '12,'); // [OCR 추가]
  }); // [OCR 추가]
  test('합성 ML Kit: 단어 좌표를 줄 전체 박스로 바꾸지 않는다', () {
    // [OCR 추가]
    // [OCR 추가]
    final bounds = [
      // [OCR 추가]
      const Rect.fromLTWH(10, 20, 40, 20), // [OCR 추가]
      const Rect.fromLTWH(150, 20, 20, 20), // [OCR 추가]
      const Rect.fromLTWH(250, 20, 80, 20), // [OCR 추가]
    ]; // [OCR 추가]
    final texts = ['퍼실', '3', '80,940']; // [OCR 추가]
    final recognized = RecognizedText(
      // [OCR 추가]
      text: texts.join(' '), // [OCR 추가]
      blocks: [
        // [OCR 추가]
        TextBlock(
          // [OCR 추가]
          text: texts.join(' '), // [OCR 추가]
          boundingBox: const Rect.fromLTWH(10, 20, 320, 20), // [OCR 추가]
          recognizedLanguages: [], // [OCR 추가]
          cornerPoints: [], // [OCR 추가]
          lines: [
            // [OCR 추가]
            TextLine(
              // [OCR 추가]
              text: texts.join(' '), // [OCR 추가]
              boundingBox: const Rect.fromLTWH(10, 20, 320, 20), // [OCR 추가]
              recognizedLanguages: [], // [OCR 추가]
              cornerPoints: [], // [OCR 추가]
              confidence: null, // [OCR 추가]
              angle: null, // [OCR 추가]
              elements: [
                // [OCR 추가]
                // [OCR 추가]
                for (var index = 0; index < texts.length; index++) // [OCR 추가]
                  TextElement(
                    // [OCR 추가]
                    text: texts[index], // [OCR 추가]
                    symbols: [], // [OCR 추가]
                    boundingBox: bounds[index], // [OCR 추가]
                    recognizedLanguages: [], // [OCR 추가]
                    cornerPoints: [], // [OCR 추가]
                    confidence: null, // [OCR 추가]
                    angle: null, // [OCR 추가]
                  ), // [OCR 추가]
              ], // [OCR 추가]
            ), // [OCR 추가]
          ], // [OCR 추가]
        ), // [OCR 추가]
      ], // [OCR 추가]
    ); // [OCR 추가]
    final result = receiptOcrFromRecognizedText(
      // [OCR 추가]
      recognized, // [OCR 추가]
      '/test/photo.jpg', // [OCR 추가]
    ); // [OCR 추가]
    expect(result.products.single.bounds, bounds[0]); // [OCR 추가]
    expect(
      // [OCR 추가]
      result.numbers.map((candidate) => candidate.bounds), // [OCR 추가]
      bounds.skip(1), // [OCR 추가]
    ); // [OCR 추가]
    expect(result.numbers.map((candidate) => candidate.number), [
      // [OCR 추가]
      3, // [OCR 추가]
      80940, // [OCR 추가]
    ]); // [OCR 추가]
  }); // [OCR 추가]
  test('합성 ML Kit: 단어가 없는 줄은 원문·줄 좌표 보존', () {
    // [OCR 추가]
    const bounds = Rect.fromLTWH(50, 60, 100, 20); // [OCR 추가]
    final recognized = RecognizedText(
      // [OCR 추가]
      text: '12,000', // [OCR 추가]
      blocks: [
        // [OCR 추가]
        TextBlock(
          // [OCR 추가]
          text: '12,000', // [OCR 추가]
          boundingBox: bounds, // [OCR 추가]
          recognizedLanguages: [], // [OCR 추가]
          cornerPoints: [], // [OCR 추가]
          lines: [
            // [OCR 추가]
            TextLine(
              // [OCR 추가]
              text: '12,000', // [OCR 추가]
              elements: [], // [OCR 추가]
              boundingBox: bounds, // [OCR 추가]
              recognizedLanguages: [], // [OCR 추가]
              cornerPoints: [], // [OCR 추가]
              confidence: null, // [OCR 추가]
              angle: null, // [OCR 추가]
            ), // [OCR 추가]
          ], // [OCR 추가]
        ), // [OCR 추가]
      ], // [OCR 추가]
    ); // [OCR 추가]
    final result = receiptOcrFromRecognizedText(
      // [OCR 추가]
      recognized, // [OCR 추가]
      '/test/photo.jpg', // [OCR 추가]
    ); // [OCR 추가]
    expect(result.numbers.single.number, 12000); // [OCR 추가]
    expect(result.numbers.single.bounds, bounds); // [OCR 추가]
    expect(
      // [OCR 추가]
      result.rows.single.tokens.single.id, // [OCR 추가]
      'block-0-line-0-fallback', // [OCR 추가]
    ); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('모의 네이티브 응답: 기존 초안 반환·좌표 결과 연결·실패 시 인식기 정리', (tester) async {
    // [OCR 수정]
    // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    const channel = MethodChannel('google_mlkit_text_recognizer'); // [OCR 추가]
    final messenger = // [OCR 추가]
        TestDefaultBinaryMessengerBinding // [OCR 추가]
            .instance // [OCR 추가]
            .defaultBinaryMessenger; // [OCR 추가]
    var closeCount = 0; // [OCR 추가]
    var fail = false; // [OCR 추가]
    messenger.setMockMethodCallHandler(channel, (call) async {
      // [OCR 추가]
      if (call.method == 'vision#closeTextRecognizer') {
        // [OCR 추가]
        closeCount++; // [OCR 추가]
        return null; // [OCR 추가]
      } // [OCR 추가]
      if (fail) throw PlatformException(code: 'ocr-failed'); // [OCR 추가]
      return {'text': '마트\n퍼실 80,940', 'blocks': []}; // [OCR 추가]
    }); // [OCR 추가]
    addTearDown(
      // [OCR 추가]
      () => messenger.setMockMethodCallHandler(channel, null), // [OCR 추가]
    ); // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 수정]
      // [OCR 추가]
      final service = OcrService(engine: 'mlkit'); // [OCR 추가]
      final draft = await service.recognizePath(path); // [OCR 추가]
      expect(
        // [OCR 수정]
        // [OCR 추가]
        draft.lines.any(
          // [OCR 수정]
          // [OCR 추가]
          (line) => line.title == '퍼실' && line.total == 80940, // [OCR 추가]
        ), // [OCR 추가]
        isTrue, // [OCR 추가]
      ); // [OCR 추가]
      expect(draft.ocrResult!.text, '마트\n퍼실 80,940'); // [OCR 추가]
      expect(draft.ocrResult!.photoPath, path); // [OCR 추가]
      expect(closeCount, 1); // [OCR 추가]
      fail = true; // [OCR 추가]
      await expectLater(
        // [OCR 수정]
        // [OCR 추가]
        service.recognizePath(path), // [OCR 추가]
        throwsA(isA<PlatformException>()), // [OCR 추가]
      ); // [OCR 추가]
      expect(closeCount, 2); // [OCR 추가]
    }); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('문자열 초안이 비어도 좌표 후보를 반환하고 빈 OCR만 거부한다', (tester) async {
    // [OCR 수정]
    // [OCR 수정]
    final path = await regionPhoto(tester); // [OCR 추가]
    const channel = MethodChannel('google_mlkit_text_recognizer'); // [OCR 수정]
    final messenger = TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger; // [OCR 수정]
    var empty = false; // [OCR 수정]
    var closeCount = 0; // [OCR 수정]
    Map<String, dynamic> part(String text, double left, double right) => {
      // [OCR 수정]
      'text': text, // [OCR 수정]
      'rect': {
        'left': left,
        'top': 0.0,
        'right': right,
        'bottom': 20.0,
      }, // [OCR 수정]
      'recognizedLanguages': <String>[],
      'points': [],
      'symbols': [], // [OCR 수정]
    }; // [OCR 수정]
    messenger.setMockMethodCallHandler(channel, (call) async {
      // [OCR 수정]
      if (call.method == 'vision#closeTextRecognizer') {
        // [OCR 수정]
        closeCount++; // [OCR 수정]
        return null; // [OCR 수정]
      } // [OCR 수정]
      if (empty) return {'text': '', 'blocks': []}; // [OCR 수정]
      final line = {
        // [OCR 수정]
        ...part('카드케이스 12,000', 0, 180), // [OCR 수정]
        'elements': [
          part('카드케이스', 0, 90),
          part('12,000', 100, 180),
        ], // [OCR 수정]
      }; // [OCR 수정]
      return {
        // [OCR 수정]
        'text': '카드케이스 12,000', // [OCR 수정]
        'blocks': [
          {
            ...part('카드케이스 12,000', 0, 180),
            'lines': [line],
          },
        ], // [OCR 수정]
      }; // [OCR 수정]
    }); // [OCR 수정]
    addTearDown(
      () => messenger.setMockMethodCallHandler(channel, null),
    ); // [OCR 수정]
    await tester.runAsync(() async {
      // [OCR 수정]
      // [OCR 추가]
      final service = OcrService(engine: 'mlkit'); // [OCR 수정]
      final draft = await service.recognizePath(path); // [OCR 수정]
      expect(draft.lines, isEmpty); // [OCR 수정]
      expect(draft.ocrResult!.products.single.text, '카드케이스'); // [OCR 수정]
      expect(draft.ocrResult!.numbers.single.number, 12000); // [OCR 수정]
      empty = true; // [OCR 수정]
      await expectLater(
        // [OCR 수정]
        service.recognizePath(path), // [OCR 수정]
        throwsFormatException, // [OCR 수정]
      ); // [OCR 수정]
      expect(closeCount, 2); // [OCR 수정]
      final manual = await service.recognizePath(
        // [OCR 수정]
        // [OCR 추가]
        path, // [OCR 추가]
        allowManualRegions: true, // [OCR 추가]
      ); // [OCR 추가]
      expect(manual.ocrResult!.text, isEmpty); // [OCR 추가]
      expect(manual.ocrResult!.photoPath, path); // [OCR 추가]
      expect(manual.ocrResult!.products, isEmpty); // [OCR 추가]
      expect(closeCount, 3); // [OCR 추가]
    }); // [OCR 추가]
  }); // [OCR 수정]

  test('fresh 숫자 정규화: 콤마 공백·전각 콤마·마이너스를 읽고 원문·좌표·위치별 ID는 보존한다', () {
    // [OCR 수정]
    // [OCR 추가]
    for (final text in [
      // [OCR 수정]
      '12, 000', // [OCR 수정]
      '12 , 000', // [OCR 수정]
      '12，000', // [OCR 수정]
      '1, 234, 567', // [OCR 수정]
      '−15,000', // [OCR 수정]
      '－15,000', // [OCR 수정]
      '–15,000', // [OCR 수정]
      '￦12，000원', // [OCR 수정]
    ]) {
      // [OCR 수정]
      // [OCR 추가]
      final rawRows = [
        // [OCR 수정]
        row([text]), // [OCR 수정]
        row([text], top: 40), // [OCR 수정]
      ]; // [OCR 추가]
      final result = resultFor(rawRows); // [OCR 추가]
      final expected =
          text.contains('15') // [OCR 수정]
          ? -15000 // [OCR 수정]
          : text.startsWith('1,') // [OCR 수정]
          ? 1234567 // [OCR 수정]
          : 12000; // [OCR 추가]
      expect(result.numbers.map((candidate) => candidate.number), [
        // [OCR 수정]
        expected, // [OCR 수정]
        expected, // [OCR 수정]
      ]); // [OCR 추가]
      expect(
        // [OCR 수정]
        result.numbers.map((candidate) => candidate.id).toSet(), // [OCR 수정]
        hasLength(2), // [OCR 수정]
      ); // [OCR 추가]
      expect(
        // [OCR 수정]
        result.numbers.first.bounds, // [OCR 수정]
        rawRows.first.tokens.first.bounds, // [OCR 수정]
      ); // [OCR 추가]
      expect(result.rows.first.tokens.first.text, text); // [OCR 추가]
      expect(result.text, '$text\n$text'); // [OCR 추가]
    } // [OCR 추가]
    final capacities = resultFor([
      // [OCR 수정]
      row(['1L', '850g', '1, 000ml', '12 000', '표시 , 상품']), // [OCR 수정]
    ]); // [OCR 추가]
    expect(capacities.numbers, isEmpty); // [OCR 추가]
    expect(capacities.products.map((candidate) => candidate.text), [
      // [OCR 수정]
      '1L', // [OCR 수정]
      '850g', // [OCR 수정]
      '1, 000ml', // [OCR 수정]
      '표시 , 상품', // [OCR 수정]
    ]); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
