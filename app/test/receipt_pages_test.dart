import 'dart:async'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:flutter/services.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:shared_preferences/shared_preferences.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'package:how_much/receipt_pages.dart'; // [OCR 추가]
import 'package:how_much/receipt_review_photo.dart'; // [OCR 추가]
import 'package:how_much/receipt_selection_screen.dart'; // [OCR 추가]
import 'package:how_much/receipt_perspective_screen.dart'; // [OCR 추가]
import 'package:how_much/screens.dart'; // [OCR 추가]
import 'package:how_much/app_store.dart'; // [OCR 추가]
import 'package:how_much/cloud_service.dart'; // [OCR 추가]
import 'receipt_selection_test.dart' show reveal; // [OCR 추가]
import 'receipt_region_test.dart' show loadRegion, regionPhoto; // [OCR 추가]
import 'receipt_tilt_test.dart' show response; // [OCR 추가]
import 'package:how_much/ocr_service.dart'; // [OCR 추가]
import 'package:how_much/receipt_text_recognizer.dart'; // [OCR 추가]

// [OCR 추가] 화면 흐름 시험용 Paddle 응답이다. 실제 사진 인식 성적과 구분한다.
Map<String, dynamic> paddlePageResponse() {
  final lines = <Map<String, dynamic>>[];
  for (var index = 0; index < 3; index++) {
    final text = ['퍼실', '3', '80,940'][index];
    final top = 50.0 + index * 50;
    final value = <String, dynamic>{
      'text': text,
      'bounds': [40.0, top, 160.0, top + 30],
      'points': [
        [40, top],
        [160, top],
        [160, top + 30],
        [40, top + 30],
      ],
      'confidence': 0.9,
      'angle': 0.0,
    };
    lines.add({
      ...value,
      'elements': [value],
    });
  }
  return {'text': '퍼실\n3\n80,940', 'lines': lines};
}

final preparedPages = // [OCR 추가]
    <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가] 모의 OCR은 촬영과 분리한다.

ReceiptPhotoPage page(int index) {
  // [OCR 추가]
  final left = 10.0 + index * 30; // [OCR 추가]
  ReceiptOcrCandidate candidate(
    // [OCR 추가]
    String id, // [OCR 추가]
    String text, // [OCR 추가]
    double x, { // [OCR 추가]
    int? number, // [OCR 추가]
  }) => ReceiptOcrCandidate(
    // [OCR 추가]
    id: id, // [OCR 추가]
    text: text, // [OCR 추가]
    number: number, // [OCR 추가]
    bounds: Rect.fromLTWH(x, 20, 60, 20), // [OCR 추가]
  ); // [OCR 추가]
  final name = candidate('name', '상품 $index', left); // [OCR 추가]
  final quantity = candidate(
    // [OCR 추가]
    'qty', // [OCR 추가]
    '${index + 1}', // [OCR 추가]
    left + 150, // [OCR 추가]
    number: index + 1, // [OCR 추가]
  ); // [OCR 추가]
  final amount = candidate(
    'amount',
    '12000',
    left + 230,
    number: 12000,
  ); // [OCR 추가]
  final result = ReceiptOcrResult(
    // [OCR 추가]
    text: '상품 $index ${index + 1} 12000', // [OCR 추가]
    photoPath: '/photo-$index.png', // [OCR 추가]
    rows: [
      // [OCR 추가]
      ReceiptOcrRow(
        // [OCR 추가]
        id: 'row', // [OCR 추가]
        text: '상품 $index ${index + 1} 12000', // [OCR 추가]
        bounds: Rect.fromLTWH(left, 20, 290, 20), // [OCR 추가]
        tokens: [
          // [OCR 추가]
          for (final c in [name, quantity, amount]) // [OCR 추가]
            ReceiptOcrToken(
              id: c.id,
              text: c.text,
              bounds: c.bounds,
            ), // [OCR 추가]
        ], // [OCR 추가]
      ), // [OCR 추가]
    ], // [OCR 추가]
    products: [name], // [OCR 추가]
    numbers: [quantity, amount], // [OCR 추가]
  ); // [OCR 추가]
  final photo = ReceiptPhotoPage(path: result.photoPath); // [OCR 수정]
  preparedPages[photo] = ReceiptDraft(
    // [OCR 추가]
    id: 'draft-$index', // [OCR 추가]
    store: '마트', // [OCR 추가]
    purchasedOn: '2026-10-07', // [OCR 추가]
    lines: [], // [OCR 추가]
    ocrResult: result, // [OCR 추가]
  ); // [OCR 수정]
  return photo; // [OCR 수정]
} // [OCR 추가]

ReceiptDraft chosen(ReceiptPhotoPage photo) {
  // [OCR 추가]
  final result = preparedPages[photo]!.ocrResult!; // [OCR 추가]
  return ReceiptDraft(
    // [OCR 추가]
    id: preparedPages[photo]!.id, // [OCR 추가]
    store: preparedPages[photo]!.store, // [OCR 추가]
    purchasedOn: preparedPages[photo]!.purchasedOn, // [OCR 추가]
    ocrResult: result, // [OCR 추가]
    lines: [
      // [OCR 추가]
      ReceiptLineDraft(
        // [OCR 추가]
        id: 'same', // [OCR 추가]
        title: '같은 상품', // [OCR 추가]
        quantity: result.numbers.first.number!, // [OCR 추가]
        total: 12000, // [OCR 추가]
        ocrProduct: result.products.first, // [OCR 추가]
        ocrQuantity: result.numbers.first, // [OCR 추가]
        ocrAmount: result.numbers.last, // [OCR 추가]
      ), // [OCR 추가]
    ], // [OCR 추가]
  ); // [OCR 추가]
} // [OCR 추가]

Future<void> choosePage(WidgetTester tester) async {
  // [OCR 추가]
  for (final id in ['name', 'qty', 'amount']) {
    // [OCR 추가]
    final finder = find.byKey(ValueKey('ocr-candidate-$id')); // [OCR 추가]
    await reveal(tester, finder); // [OCR 추가]
    await tester.tap(finder); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
  } // [OCR 추가]
  await tester.tap(find.text('끝까지 자동 선택')); // [OCR 추가]
  await tester.pump(const Duration(milliseconds: 300)); // [OCR 추가]
  await loadRegion(tester); // [OCR 추가]
} // [OCR 추가]

// [OCR 추가] 실제 앨범과 구분한 플랫폼 모의 응답으로 사진 수집·취소·늦은 완료를 검사한다.
void mockReceiptGallery(
  WidgetTester tester,
  Future<List<String>> Function() pick,
) {
  const picker = MethodChannel('plugins.flutter.io/image_picker'); // [OCR 추가]
  const pigeon =
      'dev.flutter.pigeon.image_picker_android.ImagePickerApi.pickImages'; // [OCR 추가]
  final messenger = tester.binding.defaultBinaryMessenger; // [OCR 추가]
  messenger.setMockMethodCallHandler(picker, (_) => pick()); // [OCR 추가]
  messenger.setMockMessageHandler(pigeon, (_) async {
    return const StandardMessageCodec().encodeMessage([await pick()]);
  }); // [OCR 추가]
  addTearDown(() {
    messenger.setMockMethodCallHandler(picker, null);
    messenger.setMockMessageHandler(pigeon, null);
  }); // [OCR 추가]
}

void main() {
  for (final cancelCorrection in [false, true]) {
    testWidgets(
      '앨범 한 장은 즉시 보정·선택으로 진행하고 취소 시 한 장 모드를 유지한다: $cancelCorrection',
      (tester) async {
        // [OCR 추가] 사진 파일과 모의 OCR 응답으로 단일 경로 복원·취소를 확인한다. 실사진 인식률 검증은 아니다.
        final path = await regionPhoto(tester, width: 900, height: 1800);
        final store = AppStore(CloudService(false));
        addTearDown(store.dispose);
        mockReceiptGallery(tester, () async => [path]);
        const channel = ReceiptTextRecognizer
            .channel; // [OCR 수정] 기본 Paddle 경로의 화면 흐름을 검증한다.
        var reads = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'close') return null; // [OCR 수정]
            reads++;
            return paddlePageResponse(); // [OCR 수정]
          },
        ); // [OCR 추가]
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(home: ReceiptCaptureScreen(store: store)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('앨범'));
        await loadRegion(tester);
        expect(find.byType(ReceiptPerspectiveScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('receipt-finish-parts')),
          findsNothing,
        );
        expect(reads, 0); // [OCR 추가] 보정 결정 전에는 OCR을 시작하지 않는다.
        if (cancelCorrection) {
          await tester.tap(
            find.byType(BackButton),
          ); // [OCR 추가] 보정 화면은 기본 AppBar 뒤로 버튼을 사용한다.
          await tester.pumpAndSettle();
          expect(find.byType(ReceiptSelectionScreen), findsNothing);
          expect(reads, 0);
        } else {
          await tester.tap(find.text('원본 사용'));
          await loadRegion(tester);
          expect(find.byType(ReceiptSelectionScreen), findsOneWidget);
          expect(reads, greaterThan(0));
          await tester.tap(find.byTooltip('뒤로'));
          await tester.pumpAndSettle();
        } // [OCR 추가]
        expect(find.byType(ReceiptCaptureScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('receipt-finish-parts')),
          findsNothing,
        );
        expect(find.byType(ReceiptReviewScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final existingPhotos in [false, true]) {
    testWidgets('여러 장 추가는 유지하고 한 장 전환은 이전 목록과 분리한다: $existingPhotos', (
      tester,
    ) async {
      // [OCR 수정] 모드 전환 뒤 한 장을 선택하면 이전 여러 장 목록에 섞지 않는다.
      final path = await regionPhoto(tester, width: 900, height: 1800);
      final store = AppStore(CloudService(false));
      addTearDown(store.dispose);
      var picks = 0;
      mockReceiptGallery(tester, () async {
        picks++;
        if (existingPhotos && picks == 1) return ['/first.jpg', '/second.jpg'];
        return [path];
      }); // [OCR 추가]
      await tester.pumpWidget(
        MaterialApp(home: ReceiptCaptureScreen(store: store)),
      );
      await tester.pumpAndSettle();
      if (existingPhotos) {
        await tester.tap(find.text('앨범'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('한 장'));
      } else {
        await tester.tap(find.text('여러 장 찍기'));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('앨범'));
      // [OCR 추가] 실제 파일 로딩 중의 진행 표시를 기다릴 때는 비동기 작업도 진행한다.
      await loadRegion(tester);
      if (existingPhotos) {
        expect(find.byType(ReceiptPerspectiveScreen), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('여러 장 찍기'));
        await tester.pumpAndSettle();
        expect(find.text('촬영 완료 (0장)'), findsOneWidget);
      } else {
        expect(find.text('촬영 완료 (1장)'), findsOneWidget);
        expect(find.byType(ReceiptPerspectiveScreen), findsNothing);
      }
      expect(find.byType(ReceiptSelectionScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('새 영수증은 여러 장 목록을 비우고 다음 사진부터 새로 모은다', (tester) async {
    // [OCR 추가] 이전 영수증의 사진이 새 영수증 장수에 포함되는 실패를 검사한다.
    final store = AppStore(CloudService(false));
    addTearDown(store.dispose);
    var picks = 0;
    mockReceiptGallery(
      tester,
      () async => picks++ == 0 ? ['/first.jpg', '/second.jpg'] : ['/new.jpg'],
    );
    await tester.pumpWidget(
      MaterialApp(home: ReceiptCaptureScreen(store: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('앨범'));
    await tester.pumpAndSettle();
    expect(find.text('촬영 완료 (2장)'), findsOneWidget);
    await tester.tap(find.text('새 영수증'));
    await tester.pumpAndSettle();
    expect(find.text('촬영 완료 (0장)'), findsOneWidget);
    expect(find.byTooltip('사진 제거'), findsNothing);
    await tester.tap(find.text('앨범'));
    await tester.pumpAndSettle();
    expect(find.text('촬영 완료 (1장)'), findsOneWidget);
    expect(find.byTooltip('사진 제거'), findsOneWidget);
    expect(find.byType(ReceiptPerspectiveScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('기본 앨범에서 여러 장 추가·취소·재추가해도 OCR 없이 최대 10장을 모은다', (tester) async {
    // [OCR 추가] 작은 화면에서도 여러 장 모드를 먼저 누르지 않고 앨범을 연다.
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore(CloudService(false));
    addTearDown(store.dispose);
    final batches = [
      ['/first.jpg', '/second.jpg'],
      <String>[],
      [for (var i = 0; i < 12; i++) '/extra-$i.jpg'],
    ]; // [OCR 추가]
    var picks = 0; // [OCR 추가]
    mockReceiptGallery(tester, () async => batches[picks++]);
    const ocr =
        ReceiptTextRecognizer.channel; // [OCR 수정] 사진 수집 중 Paddle도 호출하지 않는다.
    var reads = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(ocr, (
      _,
    ) async {
      reads++;
      throw StateError('사진을 모으는 동안 OCR을 호출하면 안 된다.');
    }); // [OCR 추가]
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ocr,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReceiptCaptureScreen(store: store)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-finish-parts')), findsNothing);
    for (final count in [2, 2, 10]) {
      await tester.tap(find.text('앨범'));
      await tester.pumpAndSettle();
      expect(find.text('촬영 완료 ($count장)'), findsOneWidget);
      expect(find.byType(ReceiptSelectionScreen), findsNothing);
      expect(reads, 0);
    } // [OCR 추가]
    // [OCR 추가] 미리보기는 축소 디코딩과 지연 렌더링을 사용하므로 현재 보이는 파일을 확인한다.
    Iterable<String> visiblePhotos() => tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .map(
          (provider) =>
              provider is ResizeImage ? provider.imageProvider : provider,
        ) // [OCR 추가]
        .whereType<FileImage>()
        .map((provider) => provider.file.path);
    expect(visiblePhotos().take(2), batches.first); // [OCR 추가]
    await tester.drag(find.byType(ListView), const Offset(-1600, 0));
    await tester.pumpAndSettle();
    expect(visiblePhotos().last, '/extra-7.jpg'); // [OCR 추가]
    final album = find.ancestor(
      of: find.text('앨범'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(album).onTap, isNull); // [OCR 추가]
    expect(picks, 3);
    expect(tester.takeException(), isNull);
  });
  testWidgets('앨범 최초 취소는 한 장 모드를 유지하고 화면 종료 후 선택 결과는 버린다', (tester) async {
    // [OCR 추가] 선택기 취소와 늦게 완료된 사진을 구분해 기존 세션 보호를 확인한다.
    final store = AppStore(CloudService(false));
    addTearDown(store.dispose);
    final pending = Completer<List<String>>();
    var picks = 0;
    mockReceiptGallery(tester, () {
      picks++;
      return picks == 1 ? Future.value(<String>[]) : pending.future;
    }); // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(home: ReceiptCaptureScreen(store: store)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('앨범'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('receipt-finish-parts')), findsNothing);
    expect(find.byType(ReceiptSelectionScreen), findsNothing);
    await tester.tap(find.text('앨범'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(['/late-first.jpg', '/late-second.jpg']);
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptCaptureScreen), findsNothing);
    expect(find.byType(ReceiptSelectionScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('장별 보정 취소는 완료한 장을 유지하고 OCR 캐시·다음 장을 추가하지 않는다', (tester) async {
    // [OCR 추가]
    final photos = [page(0), page(1), page(2)]; // [OCR 추가]
    final first = chosen(photos.first); // [OCR 추가]
    final selections = <ReceiptPhotoPage, ReceiptDraft>{
      photos.first: first,
    }; // [OCR 추가]
    final recognizedPages = <ReceiptPhotoPage, ReceiptDraft>{
      photos.first: preparedPages[photos.first]!,
    }; // [OCR 추가]
    final reads = <ReceiptPhotoPage>[]; // [OCR 추가]
    ReceiptDraft? completed; // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            // [OCR 추가]
            onPressed: () async {
              // [OCR 추가]
              completed = await selectReceiptPages(
                context,
                photos,
                selections: selections,
                recognizedPages: recognizedPages, // [OCR 추가]
                recognize: (photo) async {
                  reads.add(photo);
                  return null;
                },
                isCurrent: () => true,
              ); // [OCR 추가]
            }, // [OCR 추가]
            child: const Text('시작'), // [OCR 추가]
          ),
        ),
      ),
    ); // [OCR 추가]
    await tester.tap(find.text('시작')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(completed, isNull); // [OCR 추가]
    expect(reads, [photos[1]]); // [OCR 추가]
    expect(selections, {photos.first: first}); // [OCR 추가]
    expect(recognizedPages.keys, [photos.first]); // [OCR 추가]
    expect(find.byType(ReceiptSelectionScreen), findsNothing); // [OCR 추가]
  }); // [OCR 추가]

  // [OCR 추가]
  setUp(() {
    // [OCR 추가]
    SharedPreferences.setMockInitialValues({}); // [OCR 추가]
    preparedPages.clear(); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('앨범에서 여러 장을 고를 때 파일 경로만 모으고 ML Kit를 호출하지 않는다', (tester) async {
    // [OCR 추가]
    const picker = MethodChannel('plugins.flutter.io/image_picker'); // [OCR 추가]
    const ocr = MethodChannel('google_mlkit_text_recognizer'); // [OCR 추가]
    const paths = ['/not-read-first.jpg', '/not-read-second.jpg']; // [OCR 추가]
    var reads = 0; // [OCR 추가]
    final messenger = tester.binding.defaultBinaryMessenger; // [OCR 추가]
    messenger.setMockMethodCallHandler(
      picker,
      (call) async => paths,
    ); // [OCR 추가]
    messenger.setMockMethodCallHandler(ocr, (call) async {
      reads++;
      throw StateError('촬영 단계 OCR 호출');
    }); // [OCR 추가]
    const pigeon =
        'dev.flutter.pigeon.image_picker_android.ImagePickerApi.pickImages'; // [OCR 추가]
    messenger.setMockMessageHandler(
      pigeon,
      (_) async => const StandardMessageCodec().encodeMessage([paths]),
    ); // [OCR 추가]
    addTearDown(() {
      messenger.setMockMethodCallHandler(picker, null);
      messenger.setMockMethodCallHandler(ocr, null);
      messenger.setMockMessageHandler(pigeon, null);
    }); // [OCR 추가]
    final photos = await OcrService(
      engine: 'mlkit',
    ).pickReceiptPages(limit: 10); // [OCR 추가]
    expect(photos.map((photo) => photo.path), paths); // [OCR 추가]
    expect(reads, 0); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('OCR 도중 세션 변경 시 늦게 온 결과는 캐시나 선택 화면에 반영하지 않는다', (tester) async {
    // [OCR 추가]
    final photo = page(0); // [OCR 추가]
    var current = true; // [OCR 추가]
    final pending = Completer<ReceiptDraft>(); // [OCR 추가]
    final recognized = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
    final selections = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
    ReceiptDraft? completed; // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              // [OCR 추가]
              onPressed: () async => completed = await selectReceiptPages(
                context,
                [photo], // [OCR 추가]
                recognizedPages: recognized,
                selections: selections,
                recognize: (_) => pending.future,
                isCurrent: () => current,
              ), // [OCR 추가]
              child: const Text('시작'),
            ),
          ),
        ),
      ),
    ); // [OCR 추가]
    await tester.tap(find.text('시작')); // [OCR 추가]
    await tester.pump(); // [OCR 추가]
    current = false; // [OCR 추가]
    pending.complete(preparedPages[photo]!); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(completed, isNull); // [OCR 추가]
    expect(recognized, isEmpty); // [OCR 추가]
    expect(selections, isEmpty); // [OCR 추가]
    expect(find.byType(ReceiptSelectionScreen), findsNothing); // [OCR 추가]
  }); // [OCR 추가]
  test('여러 장 중복 상품과 세트 관계는 독립 기록으로 저장·복원하고 사진 필드는 전송하지 않는다', () async {
    // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    await store.initialize(); // [OCR 추가]
    final combined = combineReceiptPages([
      chosen(page(0)),
      chosen(page(1)),
    ]); // [OCR 추가]
    combined.lines.last.setParentId = combined.lines.first.id; // [OCR 추가]
    await store.saveReceipt(combined); // [OCR 추가]
    final restored = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(restored.dispose); // [OCR 추가]
    await restored.initialize(); // [OCR 추가]
    expect(restored.purchaseRows, hasLength(2)); // [OCR 추가]
    final child = restored.purchaseRows.singleWhere(
      (row) => row.purchase!.quantity == 2,
    ); // [OCR 추가]
    final parent = restored.purchaseRows.singleWhere(
      (row) => row.purchase!.quantity == 1,
    ); // [OCR 추가]
    expect(child.purchase!.setParentId, parent.id); // [OCR 추가]
    expect(child.purchase!.total, 12000); // [OCR 추가]
    expect(
      child.purchase!.toJson().keys,
      isNot(contains('receiptPhotoIndex')),
    ); // [OCR 추가]
    expect(
      child.purchase!.toJson().keys,
      isNot(contains('ocrPages')),
    ); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('여러 장 모드는 작은 촬영 화면에만 표시하고 메모의 한 장 흐름을 유지한다', (tester) async {
    // [OCR 추가]
    await tester.binding.setSurfaceSize(const Size(320, 640)); // [OCR 추가]
    addTearDown(() => tester.binding.setSurfaceSize(null)); // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(home: ReceiptCaptureScreen(store: store)),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(find.text('여러 장 찍기')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('촬영 완료 (0장)'), findsOneWidget); // [OCR 추가]
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('receipt-finish-parts')),
          )
          .onPressed,
      isNull,
    ); // [OCR 추가]
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptCaptureScreen(
          key: const ValueKey('memo'),
          store: store,
          memo: true,
        ),
      ),
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('여러 장 찍기'), findsNothing); // [OCR 추가]
    expect(tester.takeException(), isNull); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('각 장의 서비스는 기존 보정 사진·좌표와 원래 초안을 함께 유지한다', (tester) async {
    // [OCR 추가]
    final path = await regionPhoto(tester, width: 300, height: 800); // [OCR 추가]
    const channel = MethodChannel('google_mlkit_text_recognizer'); // [OCR 추가]
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel, // [OCR 추가]
      (call) async => call.method == 'vision#startTextRecognizer'
          ? response(corrected: true)
          : null,
    ); // [OCR 추가]
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    ); // [OCR 추가]
    await tester.runAsync(() async {
      // [OCR 추가]
      final draft = await OcrService(engine: 'mlkit').recognizePath(
        // [OCR 추가]
        path, // [OCR 추가]
        allowManualRegions: true, // [OCR 추가]
      ); // [OCR 수정]
      final codec = await ui.instantiateImageCodec(
        // [OCR 추가]
        draft.ocrResult!.photoBytes!, // [OCR 추가]
      ); // [OCR 추가]
      final image = (await codec.getNextFrame()).image; // [OCR 추가]
      expect(
        ui.Size(image.width.toDouble(), image.height.toDouble()), // [OCR 추가]
        const ui.Size(600, 1600), // [OCR 추가]
      ); // [OCR 추가]
      image.dispose(); // [OCR 추가]
      codec.dispose(); // [OCR 수정]
      expect(draft.ocrResult!.photoBytes, isNotEmpty); // [OCR 추가]
      expect(
        // [OCR 추가]
        draft.ocrResult!.numbers.any(
          (candidate) => candidate.number == 80940,
        ), // [OCR 추가]
        isTrue,
      ); // [OCR 추가]
    }); // [OCR 추가]
  }); // [OCR 추가]
  test('합칠 때 반복 이름·후보 ID를 독립 항목으로 보존하고 사진 좌표는 이동하지 않는다', () {
    // [OCR 추가]
    final photos = [page(0), page(1)]; // [OCR 추가]
    final selections = photos.map(chosen).toList(); // [OCR 추가]
    selections[1].lines.single.selected = false; // [OCR 추가]
    final combined = combineReceiptPages(selections); // [OCR 추가]
    expect(
      combined.lines.map((line) => line.id).toSet(),
      hasLength(2),
    ); // [OCR 추가]
    expect(combined.lines.map((line) => line.receiptPhotoIndex), [
      0,
      1,
    ]); // [OCR 추가]
    expect(combined.lines.map((line) => line.quantity), [1, 2]); // [OCR 추가]
    expect(combined.lines.last.selected, isFalse); // [OCR 추가]
    expect(
      // [OCR 추가]
      combined.lines.first.ocrProduct, // [OCR 추가]
      same(preparedPages[photos[0]]!.ocrResult!.products.first), // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      combined.lines.last.ocrProduct, // [OCR 추가]
      same(preparedPages[photos[1]]!.ocrResult!.products.first), // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      combined.ocrForPage(1), // [OCR 추가]
      same(preparedPages[photos[1]]!.ocrResult!), // [OCR 추가]
    ); // [OCR 추가]
    expect(combined.ocrForPage(2), isNull); // [OCR 추가]
    expect(selections.first.lines.single.id, 'same'); // [OCR 추가]
    expect(selections.last.lines.single.receiptPhotoIndex, 0); // [OCR 추가]
    final reordered = combineReceiptPages(
      selections.reversed.toList(),
    ); // [OCR 추가]
    expect(reordered.lines.map((line) => line.quantity), [2, 1]); // [OCR 추가]
    expect(
      // [OCR 추가]
      reordered.ocrForPage(0), // [OCR 추가]
      same(preparedPages[photos[1]]!.ocrResult!), // [OCR 추가]
    ); // [OCR 추가]
    expect(reordered.lines.first.receiptPhotoIndex, 0); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('장마다 첫 상품·수량·금액을 새로 선택하고 마지막 장 뒤에만 검토한다', (tester) async {
    // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    final photos = [page(0), page(1)]; // [OCR 추가]
    final recognizedPages = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
    final selections = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
    ReceiptDraft? completed; // [OCR 추가]
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
              onPressed: () async {
                // [OCR 추가]
                completed = await selectReceiptPages(
                  // [OCR 추가]
                  context, // [OCR 추가]
                  photos, // [OCR 추가]
                  selections: selections, // [OCR 추가]
                  recognizedPages: recognizedPages, // [OCR 추가]
                  recognize: (photo) async => preparedPages[photo]!, // [OCR 추가]
                  isCurrent: () => true, // [OCR 추가]
                ); // [OCR 추가]
                if (completed != null && context.mounted) {
                  // [OCR 추가]
                  await Navigator.push(
                    // [OCR 추가]
                    context, // [OCR 추가]
                    MaterialPageRoute(
                      // [OCR 추가]
                      builder:
                          (_) => // [OCR 추가]
                          ReceiptReviewScreen(
                            store: store,
                            draft: completed!,
                          ), // [OCR 추가]
                    ), // [OCR 추가]
                  ); // [OCR 추가]
                }
              }, // [OCR 추가]
              child: const Text('시작'), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('시작')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('영수증 항목 선택 (1/2장)'), findsOneWidget); // [OCR 추가]
    await choosePage(tester); // [OCR 추가]
    expect(find.text('영수증 항목 선택 (2/2장)'), findsOneWidget); // [OCR 추가]
    expect(find.byType(ReceiptReviewScreen), findsNothing); // [OCR 추가]
    expect(completed, isNull); // [OCR 추가]
    expect(selections, hasLength(1)); // [OCR 추가]
    expect(
      // [OCR 추가]
      tester // [OCR 추가]
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '끝까지 자동 선택'),
          ) // [OCR 추가]
          .onPressed, // [OCR 추가]
      isNull, // [OCR 추가]
    ); // [OCR 추가]
    await choosePage(tester); // [OCR 추가]
    expect(find.byType(ReceiptReviewScreen), findsOneWidget); // [OCR 추가]
    expect(completed!.lines.map((line) => line.title), [
      '상품 0',
      '상품 1',
    ]); // [OCR 추가]
    expect(completed!.lines.map((line) => line.quantity), [1, 2]); // [OCR 추가]
    expect(completed!.ocrPages, hasLength(2)); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('다음 장 취소 시 이전 장 선택 보존, 재개와 건너뛰기 후에만 통합 초안 반환', (tester) async {
    // [OCR 추가]
    final photos = [page(0), page(1)]; // [OCR 추가]
    final recognizedPages = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
    final selections = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
    var reads = 0; // [OCR 추가]
    ReceiptDraft? completed; // [OCR 추가]
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
              onPressed: () async => completed = await selectReceiptPages(
                // [OCR 추가]
                context, // [OCR 추가]
                photos, // [OCR 추가]
                selections: selections, // [OCR 추가]
                recognizedPages: recognizedPages, // [OCR 추가]
                recognize: (photo) async {
                  reads++;
                  return preparedPages[photo]!;
                }, // [OCR 추가]
                isCurrent: () => true, // [OCR 추가]
              ), // [OCR 추가]
              child: const Text('시작'), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('시작')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await choosePage(tester); // [OCR 추가]
    await tester.tap(find.byTooltip('뒤로')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(completed, isNull); // [OCR 추가]
    expect(selections, hasLength(1)); // [OCR 추가]
    expect(reads, 2); // [OCR 추가] 장별 선택 화면을 열 때만 읽는다. // [OCR 추가]
    expect(preparedPages[photos.first]!.lines, isEmpty); // [OCR 추가]
    await tester.tap(find.text('시작')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(find.text('영수증 항목 선택 (2/2장)'), findsOneWidget); // [OCR 추가]
    expect(reads, 2); // [OCR 추가] 취소 후 재개는 이미 읽은 장을 재인식하지 않는다. // [OCR 추가]
    await tester.tap(find.text('이 장 건너뛰기')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(completed!.lines, hasLength(1)); // [OCR 추가]
    expect(completed!.ocrPages, hasLength(2)); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('검토 사진별 박스 분리, 다른 장 항목 수정은 원래 사진을 열고 취소는 항목 보존', (tester) async {
    // [OCR 추가]
    final store = AppStore(CloudService(false)); // [OCR 추가]
    addTearDown(store.dispose); // [OCR 추가]
    final photos = [page(0), page(1)]; // [OCR 추가]
    final combined = combineReceiptPages(
      photos.map(chosen).toList(),
    ); // [OCR 추가]
    await tester.pumpWidget(
      // [OCR 추가]
      MaterialApp(
        // [OCR 추가]
        home: ReceiptReviewScreen(store: store, draft: combined), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    ReceiptReviewPhoto shown() => // [OCR 추가]
    tester.widget<ReceiptReviewPhoto>(
      find.byType(ReceiptReviewPhoto),
    ); // [OCR 추가]
    expect(shown().path, '/photo-0.png'); // [OCR 추가]
    expect(shown().regions.map((c) => c.bounds.left), [10, 240]); // [OCR 추가]
    await tester.tap(
      find.byKey(const ValueKey('receipt-next-photo')),
    ); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    expect(shown().path, '/photo-1.png'); // [OCR 추가]
    expect(shown().regions.map((c) => c.bounds.left), [40, 270]); // [OCR 추가]
    final edit = find.text('영수증에서 수정').first; // [OCR 추가]
    await tester.drag(find.byType(ListView), const Offset(0, -450)); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await Scrollable.ensureVisible(
      tester.element(edit),
      alignment: .5,
    ); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    await tester.tap(edit); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    final selection = tester.widget<ReceiptSelectionScreen>(
      // [OCR 추가]
      find.byType(ReceiptSelectionScreen), // [OCR 추가]
    ); // [OCR 추가]
    expect(
      // [OCR 추가]
      selection.draft.ocrResult, // [OCR 추가]
      same(preparedPages[photos[0]]!.ocrResult!), // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.byTooltip('뒤로')); // [OCR 추가]
    await loadRegion(tester); // [OCR 추가]
    expect(shown().path, '/photo-0.png'); // [OCR 추가]
    expect(combined.lines.first.quantity, 1); // [OCR 추가]
    expect(combined.lines.last.quantity, 2); // [OCR 추가]
    expect(
      // [OCR 추가]
      combined.lines.first.ocrProduct, // [OCR 추가]
      same(preparedPages[photos[0]]!.ocrResult!.products.first), // [OCR 추가]
    ); // [OCR 추가]
  }); // [OCR 추가]
  testWidgets('처리 중 계정/세션이 바뀌면 장 선택을 반영하거나 검토를 열지 않는다', (tester) async {
    // [OCR 추가]
    var current = true; // [OCR 추가]
    final recognizedPages = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
    final selections = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
    ReceiptDraft? completed; // [OCR 추가]
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
              onPressed: () async => completed = await selectReceiptPages(
                // [OCR 추가]
                context, // [OCR 추가]
                [page(0)], // [OCR 추가]
                selections: selections, // [OCR 추가]
                recognizedPages: recognizedPages, // [OCR 추가]
                recognize: (photo) async => preparedPages[photo]!, // [OCR 추가]
                isCurrent: () => current, // [OCR 추가]
              ), // [OCR 추가]
              child: const Text('시작'), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    await tester.tap(find.text('시작')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    current = false; // [OCR 추가]
    await tester.tap(find.text('이 장 건너뛰기')); // [OCR 추가]
    await tester.pumpAndSettle(); // [OCR 추가]
    expect(completed, isNull); // [OCR 추가]
    expect(selections, isEmpty); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
