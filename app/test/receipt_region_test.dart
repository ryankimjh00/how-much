import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_selection_screen.dart'; // [OCR 추가]
import 'dart:async'; // [OCR 추가]
import 'dart:io'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_region_screen.dart'; // [OCR 추가]
import 'package:how_much/receipt_image.dart'; // [OCR 추가]

Future<String> regionPhoto(
  // [OCR 추가]
  WidgetTester tester, { // [OCR 추가]
  int width = 400, // [OCR 추가]
  int height = 600, // [OCR 추가]
}) async {
  // [OCR 추가]
  // [OCR 수정]
  // [OCR 추가]
  late Directory directory; // [OCR 추가]
  await tester.runAsync(() async {
    // [OCR 추가]
    // [OCR 추가]
    directory = await Directory.systemTemp.createTemp(
      // [OCR 추가]
      'region-test-', // [OCR 추가]
    ); // [OCR 추가]
    final recorder = ui.PictureRecorder(); // [OCR 추가]
    final canvas =
        Canvas(recorder) // [OCR 추가]
          ..drawColor(Colors.white, BlendMode.src); // [OCR 추가]
    canvas.drawRect(
      // [OCR 추가]
      const Rect.fromLTWH(40, 50, 80, 30), // [OCR 추가]
      Paint()..color = Colors.blue, // [OCR 추가]
    ); // [OCR 추가]
    final picture = recorder.endRecording(); // [OCR 추가]
    final image = await picture.toImage(width, height); // [OCR 추가]
    final data = await image.toByteData(
      // [OCR 추가]
      format: ui.ImageByteFormat.png, // [OCR 추가]
    ); // [OCR 추가]
    await File(
      // [OCR 추가]
      '${directory.path}/receipt.png', // [OCR 추가]
    ).writeAsBytes(data!.buffer.asUint8List()); // [OCR 추가]
    image.dispose(); // [OCR 추가]
    picture.dispose(); // [OCR 추가]
  }); // [OCR 추가]
  addTearDown(() => directory.delete(recursive: true)); // [OCR 추가]
  return '${directory.path}/receipt.png'; // [OCR 추가]
} // [OCR 추가]

Future<void> loadRegion(WidgetTester tester) async {
  // [OCR 추가]
  // [OCR 추가]
  for (var i = 0; i < 10; i++) {
    // [OCR 추가]
    // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      await Future<void>.delayed(const Duration(milliseconds: 20)); // [OCR 추가]
    }); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
  } // [OCR 추가]
  await tester.pumpAndSettle(); // [OCR 추가]
} // [OCR 추가]

void main() {
  testWidgets('공통 사진 읽기는 바이트를 우선하고 파일·손상 오류를 숨기지 않는다', (tester) async {
    // [OCR 추가] 보정 사진 바이트가 있으면 원본 파일을 다시 읽거나 크기를 바꾸지 않아야 한다.
    final path = await regionPhoto(tester, width: 320, height: 700);
    await tester.runAsync(() async {
      final bytes = await File(path).readAsBytes();
      final fromFile = await loadReceiptPhoto(path);
      expect(fromFile.bytes, bytes);
      expect(fromFile.size, const Size(320, 700));
      // [OCR 추가] 파일을 일부러 손상시켜도 전달된 사진 바이트가 우선인지 확인한다.
      // 바이트가 없으면 손상·파일 없음 오류를 숨기지 않아야 화면이 실패를 안내할 수 있다.
      await File(path).writeAsBytes([0, 1, 2]);
      final fromBytes = await loadReceiptPhoto(path, photoBytes: bytes);
      expect(fromBytes.bytes, same(bytes));
      expect(fromBytes.size, fromFile.size);
      await expectLater(loadReceiptPhoto(path), throwsA(isA<Exception>()));
      await File(path).delete();
      await expectLater(
        loadReceiptPhoto(path),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
  // [OCR 추가]
  // [OCR 추가]
  testWidgets('재인식 실패는 이전 숫자를 비우고 영역 이동 중 늦은 응답을 무시한다', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    final responses = <Completer<String>>[]; // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 추가]
      MaterialApp(
        // [OCR 추가]
        home: ReceiptRegionScreen(
          // [OCR 추가]
          photoPath: path, // [OCR 추가]
          label: '수량', // [OCR 추가]
          numeric: true, // [OCR 추가]
          quantity: true, // [OCR 추가]
          initialBounds: const Rect.fromLTWH(40, 50, 80, 30), // [OCR 추가]
          initialText: '1', // [OCR 추가]
          recognize: (_, _) {
            // [OCR 추가]
            final pending = Completer<String>(); // [OCR 추가]
            responses.add(pending); // [OCR 추가]
            return pending.future; // [OCR 추가]
          }, // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    final field = find.byKey(const ValueKey('region-value')); // [OCR 추가]
    String value() => // [OCR 추가]
        tester.widget<TextFormField>(field).controller!.text; // [OCR 추가]
    await tester.tap(find.text('영역 다시 읽기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    expect(value(), isEmpty); // [OCR 추가]
    for (var i = 0; i < 5; i++) {
      // [OCR 수정]
      responses.last.completeError(StateError('부분 OCR 실패')); // [OCR 수정]
      await tester.pump(); // [OCR 수정]
    } // [OCR 수정]
    await tester.pumpAndSettle(); // [OCR 수정]
    expect(value(), isEmpty); // [OCR 추가]
    expect(
      // [OCR 추가]
      find.text('5회 인식 · 읽지 못했어요. 다시 읽거나 직접 입력해주세요.'), // [OCR 추가]
      findsOneWidget, // [OCR 추가]
    ); // [OCR 추가]
    await tester.enterText(field, '1'); // [OCR 추가]
    await tester.tap(find.text('영역 다시 읽기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.drag(
      // [OCR 추가]
      find.byKey(const ValueKey('region-box')), // [OCR 추가]
      const Offset(0, 60), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    responses.last.complete('99'); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(value(), isEmpty); // [OCR 추가]
    await tester.tap(find.text('영역 다시 읽기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    for (var i = 0; i < 1; i++) {
      // [OCR 수정]
      responses.last.complete('2'); // [OCR 수정]
      await tester.pump(); // [OCR 수정]
    } // [OCR 수정]
    await tester.pumpAndSettle(); // [OCR 수정]
    expect(responses.length, 7); // [OCR 추가] 이동한 옛 응답 뒤에는 추가 호출하지 않는다.
    expect(value(), '2'); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('빈 값·실패·잘못된 수량은 성공에서 제외하고 첫 성공 값과 좌표를 적용한다', (tester) async {
    // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    final bounds = <Rect>[]; // [OCR 추가]
    ReceiptRegionValue? saved; // [OCR 추가]
    final values = ['', '0', '1000', '2', '3', '4']; // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            // [OCR 추가]
            body: TextButton(
              onPressed: () async {
                // [OCR 추가]
                saved = await Navigator.push<ReceiptRegionValue>(
                  context,
                  MaterialPageRoute(
                    // [OCR 추가]
                    builder: (_) => ReceiptRegionScreen(
                      // [OCR 추가]
                      photoPath: path,
                      label: '수량',
                      numeric: true,
                      quantity: true, // [OCR 추가]
                      initialBounds: const Rect.fromLTWH(40, 50, 80, 30),
                      initialText: '1', // [OCR 추가]
                      recognize: (_, rect) async {
                        // [OCR 추가]
                        bounds.add(rect); // [OCR 추가]
                        if (bounds.length == 2) {
                          // [OCR 추가]
                          throw StateError('OCR 실패'); // [OCR 추가]
                        } // [OCR 추가]
                        return values[bounds.length - 1]; // [OCR 추가]
                      }, // [OCR 추가]
                    ), // [OCR 추가]
                  ),
                ); // [OCR 추가]
              },
              child: const Text('열기'),
            ), // [OCR 추가]
          ),
        ),
      ),
    ); // [OCR 추가]
    await tester.tap(find.text('열기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    await tester.tap(find.text('영역 다시 읽기')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(bounds.length, 4); // [OCR 추가]
    expect(bounds.toSet().length, 4); // [OCR 추가]
    for (var i = 0; i < 1; i++) {
      // [OCR 추가]
      expect(
        find.byKey(ValueKey('region-candidate-$i')),
        findsOneWidget,
      ); // [OCR 추가]
    } // [OCR 추가]
    expect(find.text('4회 인식 · 성공 1회'), findsOneWidget); // [OCR 추가]
    await tester.tap(
      find.byKey(const ValueKey('region-candidate-0')),
    ); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(saved!.text, '2'); // [OCR 추가]
    expect(saved!.bounds, bounds[3]); // [OCR 추가]
  }); // [OCR 추가]

  testWidgets('5회 실패 후 다음 5회를 재시도하며 사진 경계를 벗어나지 않는다', (tester) async {
    // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    final bounds = <Rect>[]; // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptRegionScreen(
          // [OCR 추가]
          photoPath: path,
          label: '금액',
          numeric: true, // [OCR 추가]
          initialBounds: const Rect.fromLTWH(0, 0, 2, 2),
          initialText: '12000', // [OCR 추가]
          recognize: (_, rect) async {
            bounds.add(rect);
            return '';
          }, // [OCR 추가]
        ),
      ),
    ); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    for (var round = 1; round <= 2; round++) {
      // [OCR 추가]
      await tester.tap(find.text('영역 다시 읽기')); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      expect(bounds.length, round * 5); // [OCR 추가]
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('region-value')))
            .controller!
            .text,
        isEmpty,
      ); // [OCR 추가]
      expect(
        find.text('${round * 5}회 인식 · 읽지 못했어요. 다시 읽거나 직접 입력해주세요.'),
        findsOneWidget,
      ); // [OCR 추가]
      expect(
        find.byKey(const ValueKey('region-candidate-0')),
        findsNothing,
      ); // [OCR 추가]
    } // [OCR 추가]
    expect(bounds.take(5).toList(), isNot(bounds.skip(5).toList())); // [OCR 추가]
    for (final rect in bounds) {
      // [OCR 추가]
      expect(rect.left, greaterThanOrEqualTo(0)); // [OCR 추가]
      expect(rect.top, greaterThanOrEqualTo(0)); // [OCR 추가]
      expect(rect.right, lessThanOrEqualTo(400)); // [OCR 추가]
      expect(rect.bottom, lessThanOrEqualTo(600)); // [OCR 추가]
      expect(rect.width, greaterThanOrEqualTo(2)); // [OCR 추가]
      expect(rect.height, greaterThanOrEqualTo(2)); // [OCR 추가]
    } // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]

  testWidgets('반복된 숫자는 표기가 달라도 한 후보로 모으고 첫 성공 직후 중단한다', (tester) async {
    // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    var calls = 0; // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptRegionScreen(
          // [OCR 추가]
          photoPath: path,
          label: '금액',
          numeric: true, // [OCR 추가]
          initialBounds: const Rect.fromLTWH(40, 50, 80, 30), // [OCR 추가]
          recognize: (_, _) async {
            // [OCR 추가]
            calls++; // [OCR 추가]
            return calls.isEven ? '12,000원' : '12000'; // [OCR 추가]
          }, // [OCR 추가]
        ),
      ),
    ); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    await tester.tap(find.text('영역 다시 읽기')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(calls, 1); // [OCR 추가]
    expect(find.text('12000 (1회)'), findsOneWidget); // [OCR 추가]
    expect(
      find.byKey(const ValueKey('region-candidate-1')),
      findsNothing,
    ); // [OCR 추가]
    expect(find.text('1회 인식 · 성공 1회'), findsOneWidget); // [OCR 추가]
  }); // [OCR 추가]

  testWidgets('영역 화면을 닫으면 늦은 인식 결과와 남은 재시도를 버린다', (tester) async {
    // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    final response = Completer<String>(); // [OCR 추가]
    var calls = 0; // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptRegionScreen(
          // [OCR 추가]
          photoPath: path,
          label: '상품명', // [OCR 추가]
          initialBounds: const Rect.fromLTWH(40, 50, 80, 30), // [OCR 추가]
          recognize: (_, _) {
            calls++;
            return response.future;
          }, // [OCR 추가]
        ),
      ),
    ); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    await tester.tap(find.text('영역 다시 읽기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await tester.pumpWidget(const MaterialApp(home: SizedBox())); // [OCR 추가]
    response.complete('퍼실'); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(calls, 1); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]

  testWidgets('확대·이동 후 박스 이동·크기 조절은 원본 좌표로 적용되고 다시 열면 복원한다', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    tester.view.physicalSize = const Size(600, 900); // [OCR 추가]
    tester.view.devicePixelRatio = 1; // [OCR 추가]
    addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
    addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    ReceiptRegionValue? saved; // [OCR 추가]
    Rect? readBounds; // [OCR 추가]
    Future<void> open(BuildContext context) async {
      // [OCR 추가]
      // [OCR 추가]
      final result = await Navigator.push<ReceiptRegionValue>(
        // [OCR 추가]
        context, // [OCR 추가]
        MaterialPageRoute(
          // [OCR 추가]
          builder: (_) => ReceiptRegionScreen(
            // [OCR 추가]
            photoPath: path, // [OCR 추가]
            label: '금액', // [OCR 추가]
            numeric: true, // [OCR 추가]
            initialBounds:
                saved?.bounds ??
                const Rect.fromLTWH(40, 50, 80, 30), // [OCR 추가]
            initialText: saved?.text ?? '12000', // [OCR 추가]
            recognize: (_, bounds) async {
              // [OCR 추가]
              readBounds ??= bounds; // [OCR 수정] 후보는 처음 성공한 실제 좌표를 보관한다.
              return '12,000원'; // [OCR 추가]
            }, // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ); // [OCR 추가]
      if (result != null) saved = result; // [OCR 추가]
    } // [OCR 추가]

    await tester.pumpWidget(
      // [OCR 추가]
      MaterialApp(
        // [OCR 추가]
        home: Builder(
          // [OCR 추가]
          builder: (context) => Scaffold(
            // [OCR 추가]
            body: TextButton(
              // [OCR 추가]
              onPressed: () => open(context), // [OCR 추가]
              child: const Text('열기'), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('열기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    final viewer = tester.widget<InteractiveViewer>(
      // [OCR 추가]
      find.byKey(const ValueKey('region-photo')), // [OCR 추가]
    ); // [OCR 추가]
    viewer.transformationController!.value = Matrix4.diagonal3Values(
      // [OCR 추가]
      2, // [OCR 추가]
      2, // [OCR 추가]
      1, // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    final box = find.byKey(const ValueKey('region-box')); // [OCR 추가]
    await tester.drag(
      // [OCR 추가]
      box, // [OCR 추가]
      const Offset(60, 30), // [OCR 추가]
      touchSlopX: 0, // [OCR 추가]
      touchSlopY: 0, // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.drag(
      // [OCR 추가]
      find.byKey(const ValueKey('region-handle-3')), // [OCR 추가]
      const Offset(60, 30), // [OCR 추가]
      touchSlopX: 0, // [OCR 추가]
      touchSlopY: 0, // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('영역 다시 읽기')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(readBounds!.left, closeTo(60, .01)); // [OCR 추가]
    expect(readBounds!.top, closeTo(60, .01)); // [OCR 추가]
    expect(readBounds!.width, closeTo(100, .01)); // [OCR 추가]
    expect(readBounds!.height, closeTo(40, .01)); // [OCR 추가]
    await tester.tap(find.text('적용')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(saved!.bounds, readBounds); // [OCR 추가]
    expect(saved!.text, '12,000'); // [OCR 추가]
    await tester.tap(find.text('열기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    expect(
      // [OCR 추가]
      tester // [OCR 추가]
          .widget<TextFormField>(
            find.byKey(const ValueKey('region-value')),
          ) // [OCR 추가]
          .controller! // [OCR 추가]
          .text, // [OCR 추가]
      '12,000', // [OCR 추가]
    ); // [OCR 추가]
    await tester.drag(box, const Offset(60, 30)); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    Navigator.of(tester.element(find.text('금액 영역'))).pop(); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(saved!.bounds, readBounds); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
  for (var corner = 0; corner < 4; corner++) {
    // [OCR 추가]
    testWidgets('작은 수량 박스의 모서리 $corner는 다른 손잡이와 겹치지 않고 해당 변만 조절한다', (
      tester,
    ) async {
      // [OCR 추가]
      tester.view.physicalSize = const Size(360, 640); // [OCR 추가]
      tester.view.devicePixelRatio = 1; // [OCR 추가]
      addTearDown(tester.view.resetPhysicalSize); // [OCR 추가]
      addTearDown(tester.view.resetDevicePixelRatio); // [OCR 추가]
      final path = await regionPhoto(tester); // [OCR 추가]
      const initial = Rect.fromLTWH(100, 100, 6, 12); // [OCR 추가]
      Rect? readBounds; // [OCR 추가]
      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptRegionScreen(
            // [OCR 추가]
            photoPath: path,
            label: '수량',
            numeric: true,
            quantity: true, // [OCR 추가]
            initialBounds: initial,
            initialText: '1', // [OCR 추가]
            recognize: (_, bounds) async {
              readBounds ??= bounds;
              return '2';
            }, // [OCR 추가]
          ),
        ),
      ); // [OCR 추가]
      await loadRegion(tester); // [OCR 추가]
      await tester.drag(
        find.byKey(ValueKey('region-handle-$corner')), // [OCR 추가]
        Offset(corner.isEven ? -27 : 27, corner < 2 ? -27 : 27), // [OCR 추가]
        touchSlopX: 0,
        touchSlopY: 0,
      ); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      await tester.tap(find.text('영역 다시 읽기')); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      final bounds = readBounds!; // [OCR 추가]
      if (corner.isEven) {
        // [OCR 추가]
        expect(bounds.left, lessThan(initial.left)); // [OCR 추가]
        expect(bounds.right, closeTo(initial.right, .01)); // [OCR 추가]
      } else {
        // [OCR 추가]
        expect(bounds.left, closeTo(initial.left, .01)); // [OCR 추가]
        expect(bounds.right, greaterThan(initial.right)); // [OCR 추가]
      } // [OCR 추가]
      if (corner < 2) {
        // [OCR 추가]
        expect(bounds.top, lessThan(initial.top)); // [OCR 추가]
        expect(bounds.bottom, closeTo(initial.bottom, .01)); // [OCR 추가]
      } else {
        // [OCR 추가]
        expect(bounds.top, closeTo(initial.top, .01)); // [OCR 추가]
        expect(bounds.bottom, greaterThan(initial.bottom)); // [OCR 추가]
      } // [OCR 추가]
      expect(tester.takeException(), isNull); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  // [OCR 추가] 긴 사진의 아래쪽으로 이동한 뒤에도 보이는 손잡이가 터치를 받아야 한다.
  for (final zoom in [1.0, 2.0]) {
    for (var corner = 0; corner < 4; corner++) {
      testWidgets('긴 사진 이동·확대 $zoom 배 후 손잡이 $corner로 크기를 조절한다', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final path = await regionPhoto(tester, height: 1600);
        const initial = Rect.fromLTWH(100, 900, 20, 20);
        Rect? readBounds;
        await tester.pumpWidget(
          MaterialApp(
            home: ReceiptRegionScreen(
              photoPath: path,
              label: '수량',
              numeric: true,
              quantity: true,
              initialBounds: initial,
              initialText: '1',
              recognize: (_, bounds) async {
                readBounds ??= bounds;
                return '2';
              },
            ),
          ),
        );
        await loadRegion(tester);
        final viewer = tester.widget<InteractiveViewer>(
          find.byKey(const ValueKey('region-photo')),
        );
        viewer.transformationController!.value = Matrix4.diagonal3Values(
          zoom,
          zoom,
          1,
        )..setTranslationRaw(0.0, 110.0 - initial.top * .9 * zoom, 0.0);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(ValueKey('region-handle-$corner')),
          Offset(corner.isEven ? -50 : 50, corner < 2 ? -40 : 40),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('영역 다시 읽기'));
        await tester.pumpAndSettle();
        expect(
          corner.isEven ? readBounds!.right : readBounds!.left,
          closeTo(corner.isEven ? initial.right : initial.left, .01),
        );
        expect(
          corner < 2 ? readBounds!.bottom : readBounds!.top,
          closeTo(corner < 2 ? initial.bottom : initial.top, .01),
        );
        expect(readBounds!.width, greaterThan(initial.width));
        expect(readBounds!.height, greaterThan(initial.height));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('부분 사진은 확대 없이 원본 픽셀과 크기를 유지한다', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      // [OCR 추가]
      final bytes = await File(path).readAsBytes(); // [OCR 추가]
      final cropped = await cropReceiptRegion(
        // [OCR 추가]
        bytes, // [OCR 추가]
        const Rect.fromLTWH(40, 50, 80, 30), // [OCR 추가]
      ); // [OCR 추가]
      final codec = await ui.instantiateImageCodec(cropped); // [OCR 추가]
      final image = (await codec.getNextFrame()).image; // [OCR 추가]
      expect(image.width, 80); // [OCR 추가]
      expect(image.height, 30); // [OCR 추가]
      final pixels = await image.toByteData(); // [OCR 추가]
      expect(pixels!.getUint8(2), 243); // [OCR 추가]
      image.dispose(); // [OCR 추가]
      codec.dispose(); // [OCR 추가]
      await expectLater(
        // [OCR 추가]
        cropReceiptRegion(
          bytes,
          const Rect.fromLTWH(900, 900, 20, 20),
        ), // [OCR 추가]
        throwsFormatException, // [OCR 추가]
      ); // [OCR 추가]
    }); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('후보가 없어도 상품명·금액·수량 영역을 직접 지정해 검토에 좌표와 값을 전달한다', (tester) async {
    // [OCR 추가]
    // [OCR 추가]
    final path = await regionPhoto(tester); // [OCR 추가]
    ReceiptDraft? returned; // [OCR 추가]
    final draft = ReceiptDraft(
      // [OCR 추가]
      id: 'empty-candidates', // [OCR 추가]
      store: '', // [OCR 추가]
      purchasedOn: '2026-10-06', // [OCR 추가]
      lines: [], // [OCR 추가]
      ocrResult: ReceiptOcrResult(
        // [OCR 추가]
        text: '?', // [OCR 추가]
        photoPath: path, // [OCR 추가]
        rows: [], // [OCR 추가]
        products: [], // [OCR 추가]
        numbers: [], // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 추가]
      MaterialApp(
        // [OCR 추가]
        home: Builder(
          // [OCR 추가]
          builder: (context) => Scaffold(
            // [OCR 추가]
            body: TextButton(
              // [OCR 추가]
              child: const Text('열기'), // [OCR 추가]
              onPressed: () async {
                // [OCR 추가]
                returned = await Navigator.push<ReceiptDraft>(
                  // [OCR 추가]
                  context, // [OCR 추가]
                  MaterialPageRoute(
                    // [OCR 추가]
                    builder: (_) =>
                        ReceiptSelectionScreen(draft: draft), // [OCR 추가]
                  ), // [OCR 추가]
                ); // [OCR 추가]
              }, // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('열기')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    await tester.tap(
      // [OCR 수정]
      find.byKey(const ValueKey('ocr-manual-names')), // [OCR 수정]
    ); // [OCR 추가] 수동 영역 추가 회귀는 자동 입력을 끈다.
    await tester.pumpAndSettle(); // [OCR 추가]

    Future<void> tap(Finder finder) async {
      // [OCR 추가]
      // [OCR 추가]
      await tester.scrollUntilVisible(
        // [OCR 추가]
        finder, // [OCR 추가]
        100, // [OCR 추가]
        scrollable: find.byType(Scrollable).last, // [OCR 추가]
      ); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      await tester.tap(finder); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
    } // [OCR 추가]

    Future<void> region(String label, String value) async {
      // [OCR 추가]
      // [OCR 추가]
      await tester.scrollUntilVisible(
        // [OCR 추가]
        find.text(label), // [OCR 추가]
        100, // [OCR 추가]
        scrollable: find.byType(Scrollable).last, // [OCR 추가]
      ); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      await tester.tap(find.text(label)); // [OCR 추가]
      await tester.pump(); // [OCR 추가]
      await loadRegion(tester); // [OCR 추가]
      await tester.tapAt(
        // [OCR 추가]
        tester.getTopLeft(
              find.byKey(const ValueKey('region-photo')),
            ) + // [OCR 추가]
            const Offset(100, 100), // [OCR 추가]
      ); // [OCR 추가]
      await tester.pumpAndSettle(); // [OCR 추가]
      await tester.enterText(
        // [OCR 추가]
        find.byKey(const ValueKey('region-value')), // [OCR 추가]
        value, // [OCR 추가]
      ); // [OCR 추가]
      await tap(find.text('적용')); // [OCR 추가]
    } // [OCR 추가]

    await region('상품명 영역 지정', '스너글'); // [OCR 추가]
    expect(find.text('선택한 상품명 1개'), findsOneWidget); // [OCR 추가]
    await tester.tap(find.text('상품명 선택 완료 (1개)')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await region('금액 영역 지정·수정', '15000'); // [OCR 추가]
    await tester.tap(find.text('수량 확인')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await region('수량 영역 지정·수정', '3'); // [OCR 추가]
    await tester.tap(find.text('선택한 항목 검토')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    final line = returned!.lines.single; // [OCR 추가]
    expect(line.title, '스너글'); // [OCR 추가]
    expect(line.quantity, 3); // [OCR 추가]
    expect(line.total, 15000); // [OCR 추가]
    expect(line.unitPrice, 5000); // [OCR 추가]
    expect(line.ocrProduct, isNotNull); // [OCR 추가]
    expect(line.ocrAmount, isNotNull); // [OCR 추가]
    expect(line.ocrQuantity, isNotNull); // [OCR 추가]
    expect(draft.lines, isEmpty); // [OCR 추가]
    expect(draft.ocrResult!.products, isEmpty); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
