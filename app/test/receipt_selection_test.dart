import 'dart:io'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/services.dart'; // [OCR 추가]
import 'package:flutter/rendering.dart'; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/app_theme.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_selection_screen.dart'; // [OCR 추가]

ReceiptOcrCandidate candidate(
  // [OCR 추가]
  String id, // [OCR 추가]
  String text, // [OCR 추가]
  double left, // [OCR 추가]
  double top, { // [OCR 추가]
  double width = 60, // [OCR 추가]
  int? number, // [OCR 추가]
}) => ReceiptOcrCandidate(
  // [OCR 추가]
  id: id, // [OCR 추가]
  text: text, // [OCR 추가]
  bounds: Rect.fromLTWH(left, top, width, 20), // [OCR 추가]
  number: number, // [OCR 추가]
); // [OCR 추가]
ReceiptOcrResult source(
  // [OCR 추가]
  List<ReceiptOcrCandidate> products, // [OCR 추가]
  List<ReceiptOcrCandidate> numbers, // [OCR 추가]
) => ReceiptOcrResult(
  // [OCR 추가]
  text: '합성 OCR', // [OCR 추가]
  photoPath: '/missing-stage2.jpg', // [OCR 추가]
  products: products, // [OCR 추가]
  numbers: numbers, // [OCR 추가]
  rows: [
    // [OCR 추가]
    for (final item in [...products, ...numbers]) // [OCR 추가]
      ReceiptOcrRow(
        // [OCR 추가]
        id: item.id, // [OCR 추가]
        text: item.text, // [OCR 추가]
        bounds: item.bounds, // [OCR 추가]
        tokens: [
          // [OCR 추가]
          ReceiptOcrToken(
            id: item.id,
            text: item.text,
            bounds: item.bounds,
          ), // [OCR 추가]
        ], // [OCR 추가]
      ), // [OCR 추가]
  ], // [OCR 추가]
); // [OCR 추가]
ReceiptDraft draftFor(ReceiptOcrResult result) => ReceiptDraft(
  // [OCR 추가]
  id: 'stage2', // [OCR 추가]
  store: '마트', // [OCR 추가]
  purchasedOn: '2026-10-06', // [OCR 추가]
  lines: [ReceiptLineDraft(id: 'old', title: '기존 항목', total: 10)], // [OCR 추가]
  ocrResult: result, // [OCR 추가]
); // [OCR 추가]
// [OCR 수정] 단계별 안내가 늘어 후보가 화면 밖에 생성되는 경우에도 실제 목록을 스크롤한다.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  // [OCR 추가]
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).last,
  ); // [OCR 추가]
  await tester.pumpAndSettle(); // [OCR 수정]
} // [OCR 추가]

// [OCR 추가] 수동 기능 회귀는 기본 자동을 끈 뒤 기존 다중 선택 흐름을 검사한다.
Future<void> enterRequiredQuantity(WidgetTester tester) async {
  // [OCR 수정]
  // [OCR 수정] 기본 1개로 진행 가능하며 화살표 입력은 키보드를 열지 않는다.
  expect(
    tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
    isNotNull,
  ); // [OCR 수정]
  await reveal(
    tester,
    find.byKey(const ValueKey('ocr-quantity-up')),
  ); // [OCR 수정]
  expect(find.text('1개'), findsOneWidget); // [OCR 추가]
  await tester.tap(find.byKey(const ValueKey('ocr-quantity-up'))); // [OCR 추가]
  await tester.pumpAndSettle(); // [OCR 추가]
  expect(find.text('2개'), findsOneWidget); // [OCR 추가]
  expect(find.byType(TextFormField), findsNothing); // [OCR 추가]
  await tester.tap(find.byKey(const ValueKey('ocr-quantity-down'))); // [OCR 추가]
  await tester.pumpAndSettle(); // [OCR 추가]
  expect(
    tester
        .widget<IconButton>(find.byKey(const ValueKey('ocr-quantity-down')))
        .onPressed,
    isNull,
  ); // [OCR 추가]
} // [OCR 수정]

Future<void> useManualSelection(WidgetTester tester) async {
  // [OCR 수정]
  // [OCR 추가]
  await reveal(
    tester,
    find.byKey(const ValueKey('ocr-manual-names')),
  ); // [OCR 추가]
  await tester.tap(find.byKey(const ValueKey('ocr-manual-names'))); // [OCR 추가]
  await tester.pumpAndSettle(); // [OCR 추가]
} // [OCR 추가]

void main() {
  // [OCR 추가]
  testWidgets('합성 사진: 박스·버튼 동기화, 이름 수정 취소·적용, 화면 취소 시 원본 유지', (tester) async {
    // [OCR 추가]
    tester.view.physicalSize = const Size(390, 844); // [OCR 추가]
    tester.view.devicePixelRatio = 1; // [OCR 추가]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
    late Directory directory; // [OCR 추가]
    late String path; // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      final font =
          FontLoader('NotoSansKR') // [OCR 추가]
            ..addFont(
              // [OCR 추가]
              rootBundle.load(
                'assets/fonts/NotoSansKR-Regular.ttf',
              ), // [OCR 추가]
            ); // [OCR 추가]
      await font.load(); // [OCR 추가]
      final titleFont =
          FontLoader('Jua') // [OCR 추가]
            ..addFont(
              rootBundle.load('assets/fonts/Jua-Regular.ttf'),
            ); // [OCR 추가]
      await titleFont.load(); // [OCR 추가]
      directory = await Directory.systemTemp.createTemp(
        // [OCR 추가]
        'ocr-stage2-test-', // [OCR 추가]
      ); // [OCR 추가]
      path = '${directory.path}/receipt.png'; // [OCR 추가]
      final recorder = ui.PictureRecorder(); // [OCR 추가]
      final canvas = Canvas(recorder); // [OCR 추가]
      canvas.drawColor(Colors.white, BlendMode.src); // [OCR 추가]
      for (final entry in [
        // [OCR 추가]
        ('퍼실', const Offset(100, 100)), // [OCR 추가]
        ('80,940', const Offset(300, 100)), // [OCR 추가]
      ]) {
        // [OCR 추가]
        final painter = TextPainter(
          // [OCR 추가]
          text: TextSpan(
            // [OCR 추가]
            text: entry.$1, // [OCR 추가]
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
            ), // [OCR 추가]
          ), // [OCR 추가]
          textDirection: TextDirection.ltr, // [OCR 추가]
        )..layout(); // [OCR 추가]
        painter.paint(canvas, entry.$2); // [OCR 추가]
      } // [OCR 추가]
      final picture = recorder.endRecording(); // [OCR 추가]
      final image = await picture.toImage(600, 400); // [OCR 추가]
      final bytes = await image.toByteData(
        // [OCR 추가]
        format: ui.ImageByteFormat.png, // [OCR 추가]
      ); // [OCR 추가]
      await File(path).writeAsBytes(bytes!.buffer.asUint8List()); // [OCR 추가]
      image.dispose(); // [OCR 추가]
      picture.dispose(); // [OCR 추가]
    }); // [OCR 추가]
    addTearDown(() => directory.delete(recursive: true)); // [OCR 추가]
    final initial = source(
      // [OCR 추가]
      [candidate('name', '퍼실', 100, 100)], // [OCR 추가]
      [
        // [OCR 수정]
        candidate('price', '80940', 300, 100, number: 80940), // [OCR 추가]
        candidate('quantity', '1', 200, 100, width: 8, number: 1), // [OCR 수정]
        candidate('code', '000007', 30, 100, number: 7), // [OCR 추가]
      ], // [OCR 수정]
    ); // [OCR 추가]
    final draft = draftFor(
      // [OCR 추가]
      ReceiptOcrResult(
        // [OCR 추가]
        text: initial.text, // [OCR 추가]
        photoPath: path, // [OCR 추가]
        rows: [
          // [OCR 수정]
          ...initial.rows, // [OCR 추가]
          ReceiptOcrRow(
            // [OCR 추가]
            id: 'symbol-row',
            text: '*',
            bounds: const Rect.fromLTWH(100, 180, 20, 20), // [OCR 추가]
            tokens: const [
              ReceiptOcrToken(
                id: 'symbol',
                text: '*',
                bounds: Rect.fromLTWH(100, 180, 20, 20),
              ),
            ], // [OCR 추가]
          ), // [OCR 추가]
        ], // [OCR 수정]
        products: initial.products, // [OCR 추가]
        numbers: initial.numbers, // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    ReceiptDraft? selected; // [OCR 추가]
    final boundary = GlobalKey(); // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 추가]
      RepaintBoundary(
        // [OCR 추가]
        key: boundary, // [OCR 추가]
        child: MaterialApp(
          // [OCR 추가]
          theme: buildAppTheme(), // [OCR 추가]
          home: Builder(
            // [OCR 추가]
            builder: (context) => TextButton(
              // [OCR 추가]
              onPressed: () async {
                // [OCR 추가]
                selected = await Navigator.push<ReceiptDraft>(
                  // [OCR 추가]
                  context, // [OCR 추가]
                  MaterialPageRoute(
                    // [OCR 추가]
                    builder: (_) =>
                        ReceiptSelectionScreen(draft: draft), // [OCR 추가]
                  ), // [OCR 추가]
                ); // [OCR 추가]
              }, // [OCR 추가]
              child: const Text('열기'), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    // [OCR 추가] 파일 읽기와 이미지 디코더는 실제 비동기 영역에서 시작해야 완료 응답을 받을 수 있다.
    await tester.runAsync(() async {
      // [OCR 추가]
      await tester.tap(find.text('열기')); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      await Future<void>.delayed(const Duration(milliseconds: 100)); // [OCR 추가]
    }); // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      await Future<void>.delayed(const Duration(milliseconds: 100)); // [OCR 추가]
    }); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      // [OCR 추가]
      find.text('사진을 열지 못했어요. 아래 후보 버튼으로 선택할 수 있어요.'), // [OCR 추가]
      findsNothing, // [OCR 추가]
    ); // [OCR 추가]
    expect(find.text('사진을 준비하고 있어요.'), findsNothing); // [OCR 수정]
    // [OCR 추가] 모의 OCR 원문: 숫자·상품코드·분류되지 않은 기호도 첫 사진에 표시한다.
    for (final id in ['name', 'price', 'quantity', 'code', 'symbol']) {
      // [OCR 추가]
      expect(find.byKey(ValueKey('ocr-box-$id')), findsOneWidget); // [OCR 추가]
    } // [OCR 추가]
    // [OCR 추가] 초기 전체 OCR에서도 좁은 1의 사방에 4px 여백을 두되 원본 좌표는 보존한다.
    final quantityBox = find.byKey(
      const ValueKey('ocr-box-quantity'),
    ); // [OCR 추가]
    expect(
      tester.getSize(quantityBox).width,
      closeTo(8 * .65 + 8, .1),
    ); // [OCR 추가]
    expect(
      tester.getSize(quantityBox).height,
      closeTo(20 * .65 + 8, .1),
    ); // [OCR 추가]
    expect(
      tester.getSize(find.byKey(const ValueKey('ocr-box-price'))).width,
      closeTo(60 * .65, .1),
    ); // [OCR 추가]
    await useManualSelection(tester); // [OCR 추가] // [OCR 추가]
    // [OCR 추가] 실제 글자 왼쪽 바깥 여백을 눌러도 같은 원문 후보를 선택한다.
    await tester.tapAt(
      tester.getTopLeft(quantityBox) + const Offset(1, 10),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      find.byKey(const ValueKey('ocr-candidate-quantity')),
      findsOneWidget,
    ); // [OCR 추가]
    await tester.tap(quantityBox); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    // [OCR 추가] 숫자 원문도 사용자 판단으로 이름에 선택 가능하며 취소·적용 시 범위 오류가 없다.
    await tester.longPress(
      find.byKey(const ValueKey('ocr-box-price')),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      find.byKey(const ValueKey('ocr-edit-value')),
      '숫자 이름',
    ); // [OCR 추가]
    await tester.tap(find.text('취소')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      find.byKey(const ValueKey('ocr-candidate-price')),
      findsNothing,
    ); // [OCR 추가]
    await tester.longPress(
      find.byKey(const ValueKey('ocr-box-price')),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      find.byKey(const ValueKey('ocr-edit-value')),
      '숫자 이름',
    ); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.byKey(const ValueKey('ocr-box-price'))); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      find.byKey(const ValueKey('ocr-box-code')),
      findsNothing,
    ); // [OCR 추가]
    await tester.tap(find.byKey(const ValueKey('ocr-box-price'))); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-box-name')), // [OCR 추가]
      findsOneWidget, // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      tester
          .getSize(find.byKey(const ValueKey('ocr-box-name')))
          .width, // [OCR 추가]
      closeTo(39, .1), // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.byKey(const ValueKey('ocr-box-name'))); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    final button = tester.widget<OutlinedButton>(
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-candidate-name')), // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      button.style!.backgroundColor!.resolve({}), // [OCR 추가]
      AppColors.secondary, // [OCR 추가]
    ); // [OCR 추가]
    await tester.longPress(
      find.byKey(const ValueKey('ocr-box-name')),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-edit-value')), // [OCR 추가]
      '퍼실 수정', // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('취소')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('퍼실 수정'), findsNothing); // [OCR 추가]
    await tester.longPress(
      find.byKey(const ValueKey('ocr-candidate-name')),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-edit-value')), // [OCR 추가]
      '퍼실 수정', // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ocr-candidate-name')),
        matching: find.text('퍼실 수정'),
      ),
      findsOneWidget,
    ); // [OCR 수정] // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      final image = // [OCR 추가]
          await (boundary.currentContext!
                      .findRenderObject() // [OCR 추가]
                  as RenderRepaintBoundary) // [OCR 추가]
              .toImage(); // [OCR 추가]
      final bytes = await image.toByteData(
        // [OCR 추가]
        format: ui.ImageByteFormat.png, // [OCR 추가]
      ); // [OCR 추가]
      await File(
        // [OCR 추가]
        '/tmp/receipt-selection-stage2.png', // [OCR 추가]
      ).writeAsBytes(bytes!.buffer.asUint8List()); // [OCR 추가]
      image.dispose(); // [OCR 추가]
    }); // [OCR 추가]
    await tester.tap(find.byTooltip('뒤로')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(selected, isNull); // [OCR 추가]
    expect(draft.lines.single.title, '기존 항목'); // [OCR 추가]
    expect(draft.ocrResult!.products.single.text, '퍼실'); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
  test('이름 길이가 달라도 왼쪽 시작점이 같은 아래 행만 좁힌다', () {
    // [OCR 추가]
    final first = candidate('first', '퍼실', 100, 100); // [OCR 추가]
    final long = candidate(
      // [OCR 추가]
      'long', // [OCR 추가]
      '아주 긴 상품명', // [OCR 추가]
      105, // [OCR 추가]
      140, // [OCR 추가]
      width: 230, // [OCR 추가]
    ); // [OCR 추가]
    final sameRow = candidate('same-row', '옆 상품', 100, 100); // [OCR 추가]
    final otherColumn = candidate('other-column', '다른 열', 300, 140); // [OCR 추가]
    final above = candidate('above', '위 상품', 100, 60); // [OCR 추가]
    expect(
      // [OCR 추가]
      receiptProductsBelow([
        // [OCR 추가]
        above, // [OCR 추가]
        first, // [OCR 추가]
        long, // [OCR 추가]
        sameRow, // [OCR 추가]
        otherColumn, // [OCR 추가]
      ], first).map((item) => item.id), // [OCR 추가]
      ['first', 'long'], // [OCR 추가]
    ); // [OCR 추가]
  }); // [OCR 추가]
  test('금액은 오른쪽 우선, 같은 행과 아래 두 실제 행만 한 목록으로 정렬', () {
    // [OCR 추가]
    final product = candidate('product', '퍼실', 100, 100); // [OCR 추가]
    final numbers = [
      // [OCR 추가]
      candidate('left', '1', 20, 100, number: 1), // [OCR 추가]
      candidate('right-below', '2000', 300, 180, number: 2000), // [OCR 추가]
      candidate('right-same', '80940', 300, 100, number: 80940), // [OCR 추가]
      candidate('second-below', '3000', 300, 300, number: 3000), // [OCR 추가]
      candidate('third-below', '4000', 300, 400, number: 4000), // [OCR 추가]
      candidate('above', '5000', 300, 50, number: 5000), // [OCR 추가]
      candidate('discount', '-15000', 400, 100, number: -15000), // [OCR 추가]
    ]; // [OCR 추가]
    expect(
      // [OCR 추가]
      receiptPricesNear(
        // [OCR 추가]
        source([product], numbers), // [OCR 추가]
        product, // [OCR 추가]
      ).map((item) => item.id), // [OCR 추가]
      ['right-same', 'right-below', 'second-below', 'left'], // [OCR 추가]
    ); // [OCR 추가]
    expect(receiptSelectionAmount('80,940'), 80940); // [OCR 추가]
    expect(receiptSelectionAmount('-15,000'), isNull); // [OCR 추가]
    expect(receiptSelectionAmount('1L'), isNull); // [OCR 추가]
    expect(receiptSelectionAmount('12,00'), isNull); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('회귀: 세 상품명을 모두 고르기 전 숫자 단계로 이동하지 않고 세 항목을 검토로 전달한다', (
    tester,
  ) async {
    // [OCR 수정]
    tester.view.physicalSize = const Size(320, 568); // [OCR 수정]
    tester.view.devicePixelRatio = 1; // [OCR 수정]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 수정]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 수정]
    final result = source(
      [
        // [OCR 수정]
        candidate('persil', '퍼실', 100, 100), // [OCR 수정]
        candidate('milk', '베지밀', 100, 140), // [OCR 수정]
        candidate('bleach', '유한락스', 100, 180), // [OCR 수정]
      ],
      [
        // [OCR 수정]
        candidate('price1', '80940', 300, 100, number: 80940), // [OCR 수정]
        candidate('price2', '33760', 300, 140, number: 33760), // [OCR 수정]
        candidate('price3', '8880', 300, 180, number: 8880), // [OCR 수정]
      ],
    ); // [OCR 수정]
    ReceiptDraft? selected; // [OCR 수정]
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              // [OCR 수정]
              selected = await Navigator.push<ReceiptDraft>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ReceiptSelectionScreen(draft: draftFor(result)),
                ),
              ); // [OCR 수정]
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ); // [OCR 수정]
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle(); // [OCR 수정]
    await useManualSelection(tester); // [OCR 추가]
    final names = ['persil', 'milk', 'bleach']; // [OCR 수정]
    for (var index = 0; index < names.length; index++) {
      // [OCR 수정]
      final finder = find.byKey(
        ValueKey('ocr-candidate-${names[index]}'),
      ); // [OCR 수정]
      await reveal(tester, finder);
      await tester.tap(finder);
      await tester.pump(); // [OCR 수정]
      expect(find.text('선택한 상품명 ${index + 1}개'), findsOneWidget); // [OCR 수정]
      expect(
        find.text('상품명 선택 완료 (${index + 1}개)'),
        findsOneWidget,
      ); // [OCR 수정]
      expect(find.text('입력할 금액은 어디에 해당하나요?'), findsNothing); // [OCR 수정]
      expect(selected, isNull); // [OCR 수정]
    } // [OCR 수정]
    await tester.tap(find.text('상품명 선택 완료 (3개)'));
    await tester.pump(); // [OCR 수정]
    await reveal(tester, find.byKey(const ValueKey('ocr-unit-price-toggle')));
    await tester.tap(find.byKey(const ValueKey('ocr-unit-price-toggle')));
    await tester.pump(); // [OCR 수정]
    for (var index = 0; index < 3; index++) {
      // [OCR 수정]
      final finder = find.byKey(
        ValueKey('ocr-candidate-price${index + 1}'),
      ); // [OCR 수정]
      await reveal(tester, finder);
      await tester.tap(finder);
      await tester.pump(); // [OCR 수정]
      expect(
        find.text('수량은 선택 사항이에요. 생략하면 1개로 기록해요.'),
        findsNothing,
      ); // [OCR 수정]
      expect(selected, isNull); // [OCR 수정]
      final action = index == 2 ? '수량 확인' : '다음 상품 금액'; // [OCR 수정]
      await tester.tap(find.text(action));
      await tester.pumpAndSettle(); // [OCR 수정]
    } // [OCR 수정]
    for (var index = 0; index < 3; index++) {
      // [OCR 수정]
      expect(selected, isNull); // [OCR 수정]
      await enterRequiredQuantity(tester); // [OCR 수정]
      final action = index == 2 ? '선택한 항목 검토' : '다음 상품 수량'; // [OCR 수정]
      await tester.tap(find.text(action)); // [OCR 수정]
      await tester.pumpAndSettle(); // [OCR 수정]
    } // [OCR 수정]
    expect(selected!.lines.map((line) => line.title), [
      '퍼실',
      '베지밀',
      '유한락스',
    ]); // [OCR 수정]
    expect(selected!.lines.map((line) => line.total), [
      80940,
      33760,
      8880,
    ]); // [OCR 수정]
    expect(tester.takeException(), isNull); // [OCR 수정]
  }); // [OCR 수정]
  testWidgets('상품명 여러 개 선택 후 상품별 금액 연결, 원본 초안 유지', (tester) async {
    // [OCR 추가]
    final result = source(
      // [OCR 추가]
      [
        candidate('persil', '퍼실', 100, 100),
        candidate('milk', '베지밀', 100, 140),
      ], // [OCR 추가]
      [
        // [OCR 추가]
        candidate('price1', '80940', 300, 100, number: 80940), // [OCR 추가]
        candidate('price2', '33760', 300, 140, number: 33760), // [OCR 추가]
      ], // [OCR 추가]
    ); // [OCR 추가]
    final draft = draftFor(result); // [OCR 추가]
    ReceiptDraft? selected; // [OCR 추가]
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
              selected = await Navigator.push<ReceiptDraft>(
                // [OCR 추가]
                context, // [OCR 추가]
                MaterialPageRoute(
                  // [OCR 추가]
                  builder: (_) =>
                      ReceiptSelectionScreen(draft: draft), // [OCR 추가]
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
    await useManualSelection(tester); // [OCR 추가]
    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-persil')),
    ); // [OCR 수정]
    await tester.tap(
      find.byKey(const ValueKey('ocr-candidate-persil')),
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(find.text('선택한 상품명 1개'), findsOneWidget); // [OCR 수정]
    expect(find.text('상품명 선택 완료 (1개)'), findsOneWidget); // [OCR 수정]
    expect(find.text('입력할 금액은 어디에 해당하나요?'), findsNothing); // [OCR 수정]
    expect(
      find.byKey(const ValueKey('ocr-candidate-milk')),
      findsOneWidget,
    ); // [OCR 수정]

    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-milk')),
    ); // [OCR 수정]
    await tester.tap(
      find.byKey(const ValueKey('ocr-candidate-milk')),
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(find.text('선택한 상품명 2개'), findsOneWidget); // [OCR 수정]
    await tester.tap(find.text('상품명 선택 완료 (2개)')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.tap(
      find.byKey(const ValueKey('ocr-unit-price-toggle')),
    ); // [OCR 수정]
    await tester.pump(); // [OCR 수정]
    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-price1')),
    ); // [OCR 수정]
    await tester.tap(
      find.byKey(const ValueKey('ocr-candidate-price1')),
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.tap(find.text('다음 상품 금액')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-price2')),
    ); // [OCR 수정]
    await tester.tap(
      find.byKey(const ValueKey('ocr-candidate-price2')),
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.tap(find.text('수량 확인')); // [OCR 수정]
    await tester.pump(); // [OCR 수정]
    await enterRequiredQuantity(tester); // [OCR 수정]
    await tester.tap(find.text('다음 상품 수량')); // [OCR 수정]
    await tester.pump(); // [OCR 수정]
    await enterRequiredQuantity(tester); // [OCR 수정]
    await tester.tap(find.text('선택한 항목 검토')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(selected!.lines.map((line) => line.title), [
      // [OCR 추가]
      '퍼실', // [OCR 추가]
      '베지밀', // [OCR 추가]
    ]); // [OCR 추가]
    expect(selected!.lines.map((line) => line.total), [
      // [OCR 추가]
      80940, // [OCR 추가]
      33760, // [OCR 추가]
    ]); // [OCR 추가]
    expect(draft.lines.single.title, '기존 항목'); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('작은 화면·키보드: 금액 수정 취소와 상품별 같은 후보의 독립 수정', (tester) async {
    // [OCR 추가]
    tester.view.physicalSize = const Size(320, 568); // [OCR 추가]
    tester.view.devicePixelRatio = 1; // [OCR 추가]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
    final result = source(
      // [OCR 추가]
      [
        // [OCR 추가]
        candidate('first', '퍼실', 100, 100), // [OCR 추가]
        candidate('second', '베지밀', 100, 140), // [OCR 추가]
      ], // [OCR 추가]
      [candidate('shared', '12000', 300, 140, number: 12000)], // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 추가]
      MaterialApp(
        // [OCR 추가]
        theme: buildAppTheme(), // [OCR 추가]
        home: ReceiptSelectionScreen(draft: draftFor(result)), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await useManualSelection(tester); // [OCR 추가]
    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-first')),
    ); // [OCR 수정]
    await tester.tap(
      find.byKey(const ValueKey('ocr-candidate-first')),
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-second')),
    ); // [OCR 수정]
    await tester.tap(
      find.byKey(const ValueKey('ocr-candidate-second')),
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(find.text('선택한 상품명 2개'), findsOneWidget); // [OCR 수정]
    await tester.tap(find.text('상품명 선택 완료 (2개)')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.tap(
      find.byKey(const ValueKey('ocr-unit-price-toggle')),
    ); // [OCR 수정]
    await tester.pump(); // [OCR 수정]
    await reveal(
      tester,
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-candidate-shared')), // [OCR 추가]
    ); // [OCR 추가]
    await tester.longPress(
      find.byKey(const ValueKey('ocr-candidate-shared')),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    tester.view.viewInsets = const FakeViewPadding(bottom: 220); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.enterText(
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-edit-value')), // [OCR 추가]
      '9000', // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('취소')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    tester.view.resetViewInsets(); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(find.text('12,000원'), findsOneWidget); // [OCR 추가]
    await reveal(
      tester,
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-candidate-shared')), // [OCR 추가]
    ); // [OCR 추가]
    await tester.longPress(
      find.byKey(const ValueKey('ocr-candidate-shared')),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-edit-value')), // [OCR 추가]
      '9000', // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('9,000원'), findsOneWidget); // [OCR 추가]
    await reveal(
      tester,
      // [OCR 추가]
      find.byKey(const ValueKey('ocr-candidate-shared')), // [OCR 추가]
    ); // [OCR 추가]
    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-shared')),
    ); // [OCR 수정]
    await tester.tap(
      find.byKey(const ValueKey('ocr-candidate-shared')),
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.tap(find.text('다음 상품 금액')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(find.text('12,000원'), findsOneWidget); // [OCR 추가]
    expect(result.numbers.single.number, 12000); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]

  testWidgets('원·통화 기호가 있는 금액도 길게 누른 수정창에서 그대로 적용하고 취소할 수 있다', (tester) async {
    // [OCR 수정]
    // [OCR 추가]
    final product = ReceiptOcrCandidate(
      // [OCR 수정]
      id: 'name', // [OCR 수정]
      text: '우유', // [OCR 수정]
      bounds: const Rect.fromLTWH(10, 10, 50, 20), // [OCR 수정]
    ); // [OCR 추가]
    final price = ReceiptOcrCandidate(
      // [OCR 수정]
      id: 'price', // [OCR 수정]
      text: '￦12,000원', // [OCR 수정]
      number: 12000, // [OCR 수정]
      bounds: const Rect.fromLTWH(100, 10, 80, 20), // [OCR 수정]
    ); // [OCR 추가]
    final draft = ReceiptDraft(
      // [OCR 수정]
      id: 'currency', // [OCR 수정]
      store: '', // [OCR 수정]
      purchasedOn: '2026-10-06', // [OCR 수정]
      lines: [], // [OCR 수정]
      ocrResult: ReceiptOcrResult(
        // [OCR 수정]
        text: '우유 ￦12,000원', // [OCR 수정]
        photoPath: '/missing/currency.png', // [OCR 수정]
        rows: [
          // [OCR 수정]
          ReceiptOcrRow(
            // [OCR 수정]
            id: 'row', // [OCR 수정]
            text: '우유 ￦12,000원', // [OCR 수정]
            bounds: const Rect.fromLTWH(10, 10, 170, 20), // [OCR 수정]
            tokens: [
              // [OCR 수정]
              ReceiptOcrToken(
                // [OCR 수정]
                id: 'name', // [OCR 수정]
                text: product.text, // [OCR 수정]
                bounds: product.bounds, // [OCR 수정]
              ), // [OCR 수정]
              ReceiptOcrToken(
                // [OCR 수정]
                id: 'price', // [OCR 수정]
                text: price.text, // [OCR 수정]
                bounds: price.bounds, // [OCR 수정]
              ), // [OCR 수정]
            ], // [OCR 수정]
          ), // [OCR 수정]
        ], // [OCR 수정]
        products: [product], // [OCR 수정]
        numbers: [price], // [OCR 수정]
      ), // [OCR 수정]
    ); // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 수정]
      MaterialApp(home: ReceiptSelectionScreen(draft: draft)), // [OCR 수정]
    ); // [OCR 추가]
    for (var i = 0; i < 5; i++) {
      // [OCR 수정]
      // [OCR 추가]
      await tester.runAsync(() async {
        // [OCR 수정]
        await Future<void>.delayed(
          const Duration(milliseconds: 20),
        ); // [OCR 수정]
      }); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
    } // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await useManualSelection(tester); // [OCR 추가]
    // [OCR 수정] 방식 버튼 아래 후보가 가려지지 않도록 스크롤한다.
    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-name')),
    ); // [OCR 수정]
    await tester.tap(
      // [OCR 수정]
      find.byKey(const ValueKey('ocr-candidate-name')), // [OCR 수정]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('상품명 선택 완료 (1개)')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    final candidate = find.byKey(
      // [OCR 수정]
      const ValueKey('ocr-candidate-price'), // [OCR 수정]
    ); // [OCR 추가]
    await tester.scrollUntilVisible(
      // [OCR 수정]
      candidate, // [OCR 수정]
      100, // [OCR 수정]
      scrollable: find.byType(Scrollable).last, // [OCR 수정]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.longPress(candidate); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(
      // [OCR 수정]
      tester // [OCR 수정]
          .widget<TextFormField>(
            find.byKey(const ValueKey('ocr-edit-value')),
          ) // [OCR 수정]
          .controller! // [OCR 수정]
          .text, // [OCR 수정]
      '12,000', // [OCR 수정]
    ); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.byType(AlertDialog), findsNothing); // [OCR 추가]
    await tester.longPress(candidate); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.enterText(
      // [OCR 수정]
      find.byKey(const ValueKey('ocr-edit-value')), // [OCR 수정]
      '8000', // [OCR 수정]
    ); // [OCR 추가]
    await tester.tap(find.text('취소')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('12,000원'), findsOneWidget); // [OCR 수정]
    expect(draft.ocrResult!.numbers.single.text, '￦12,000원'); // [OCR 추가]
    expect(draft.ocrResult!.numbers.single.number, 12000); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
