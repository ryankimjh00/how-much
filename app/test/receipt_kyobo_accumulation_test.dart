import 'dart:convert'; // [OCR 추가]
import 'dart:io'; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:how_much/models.dart'; // [OCR 추가]
import 'package:how_much/receipt_selection_screen.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_column_scan.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto, loadRegion; // [OCR 추가]
import 'receipt_selection_test.dart' show reveal; // [OCR 추가]

// [OCR 추가] 실제 ML Kit가 반환했던 좌표와 열 응답을 재생한다. 새 사진 인식 결과와 구분한다.
const recordedPath = '../docs/ocr-debug/kyobo-accumulation-20261008';

Rect recordedBounds(List<dynamic> values) => Rect.fromLTRB(
  (values[0] as num).toDouble(),
  (values[1] as num).toDouble(),
  (values[2] as num).toDouble(),
  (values[3] as num).toDouble(),
); // [OCR 추가]

ReceiptOcrResult recordedSource(String mode) {
  final file = mode == 'original'
      ? 'source.json'
      : 'corrected-source.json'; // [OCR 추가]
  final data =
      jsonDecode(File('$recordedPath/$file').readAsStringSync())
          as Map<String, dynamic>; // [OCR 추가]
  return fixture.source(
    [
      for (final value in data['products'])
        ReceiptOcrCandidate(
          id: value['id'],
          text: value['text'],
          bounds: recordedBounds(value['bounds']),
        ),
    ],
    [
      for (final value in data['numbers'])
        ReceiptOcrCandidate(
          id: value['id'],
          text: '${value['value']}',
          number: value['value'],
          bounds: recordedBounds(value['bounds']),
        ),
    ],
  ); // [OCR 추가]
}

List<List<ReceiptOcrCandidate>> recordedScans(String mode) {
  final rows = File('$recordedPath/$mode.tsv').readAsLinesSync(); // [OCR 추가]
  final boundsPattern = RegExp(r'^(.*):Rect.fromLTRB\(([^)]+)\)$'); // [OCR 추가]
  return [
    for (final row in rows.where((row) => row.startsWith('SCAN\t')))
      [
        for (final (index, text) in row.split('\t')[2].split(' | ').indexed)
          if (boundsPattern.firstMatch(text) case final match?)
            ReceiptOcrCandidate(
              id: 'scan-$index',
              text: match.group(1)!,
              bounds: recordedBounds(
                match.group(2)!.split(',').map(double.parse).toList(),
              ),
            ),
      ],
  ]; // [OCR 추가]
}

void main() {
  test('실기기 표시 좌표 재생: 가로 틈이 작은 두 1은 표시만 합친다', () {
    // [OCR 추가] 실기기 접근성 박스에서 사방 11.25px(4dp)의 표시 여백을 뺀 좌표다.
    // [OCR 추가] 화면 픽셀의 반올림을 포함하며 ML Kit 원본 응답을 직접 수집한 자료는 아니다.
    const first = ReceiptOcrCandidate(
      id: 'phone-first',
      text: '1',
      number: 1,
      bounds: Rect.fromLTRB(702.25, 879.25, 712.75, 915.75),
    );
    const duplicate = ReceiptOcrCandidate(
      id: 'phone-duplicate',
      text: '1',
      bounds: Rect.fromLTRB(694.25, 884.25, 700.75, 910.75),
    );
    const nextRow = ReceiptOcrCandidate(
      id: 'next-row',
      text: '1',
      number: 1,
      bounds: Rect.fromLTRB(694.25, 981.25, 700.75, 1007.75),
    );
    const nextColumn = ReceiptOcrCandidate(
      id: 'next-column',
      text: '1',
      number: 1,
      bounds: Rect.fromLTRB(730, 884.25, 736.5, 910.75),
    );
    const conflict = ReceiptOcrCandidate(
      id: 'conflict',
      text: '2',
      number: 2,
      bounds: Rect.fromLTRB(694.25, 884.25, 700.75, 910.75),
    );
    final candidates = [first, duplicate, nextRow, nextColumn, conflict];
    expect(first.bounds.overlaps(duplicate.bounds), isFalse);
    expect(receiptCandidatesWithoutDuplicateNumbers(candidates), [
      first,
      nextRow,
      nextColumn,
      conflict,
    ]);
    expect(
      receiptCandidatesWithoutDuplicateNumbers(
        candidates,
        selectedId: duplicate.id,
      ),
      [duplicate, nextRow, nextColumn, conflict],
    );
    expect(
      receiptNumbersWithCandidates([], candidates),
      hasLength(4),
    ); // [OCR 수정] 자동 연결도 같은 중복을 하나로 센다.
    expect(candidates, hasLength(5)); // [OCR 수정] 원문에는 다른 위치의 후보를 그대로 보존한다.
  });
  testWidgets('가로 틈이 있는 중복 1도 초기 박스와 수량 버튼은 하나다', (tester) async {
    // [OCR 추가] 실기기에서 확인한 가로 틈/높이 관계의 합성 후보다. 새 사진 OCR과 구분한다.
    final path = await regionPhoto(tester, width: 300, height: 400);
    final name = fixture.name('phone-name', '101 스티커', 50);
    const first = ReceiptOcrCandidate(
      id: 'phone-first',
      text: '1',
      number: 1,
      bounds: Rect.fromLTWH(180, 80, 2.1, 7.3),
    );
    const duplicate = ReceiptOcrCandidate(
      id: 'phone-duplicate',
      text: '1',
      number: 1,
      bounds: Rect.fromLTWH(178.4, 81, 1.3, 5.3),
    );
    final next = fixture.number('next-row', 1, 120, quantity: true);
    final base = fixture.source([name], [first, duplicate, next]);
    final source = ReceiptOcrResult(
      text: base.text,
      photoPath: path,
      rows: base.rows,
      products: base.products,
      numbers: base.numbers,
    );
    final draft = ReceiptDraft(
      id: 'phone-gap',
      store: '교보문고',
      purchasedOn: '2026-10-08',
      lines: [],
      ocrResult: source,
    );
    await tester.pumpWidget(
      MaterialApp(home: ReceiptSelectionScreen(draft: draft)),
    );
    await loadRegion(tester);
    expect(find.byKey(const ValueKey('ocr-box-phone-first')), findsOneWidget);
    expect(find.byKey(const ValueKey('ocr-box-phone-duplicate')), findsNothing);
    expect(find.byKey(const ValueKey('ocr-box-next-row')), findsOneWidget);
    await reveal(tester, find.byKey(ValueKey('ocr-candidate-${name.id}')));
    await tester.tap(find.byKey(ValueKey('ocr-candidate-${name.id}')));
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-phone-first')),
    );
    expect(find.byKey(const ValueKey('ocr-box-phone-duplicate')), findsNothing);
    expect(
      find.byKey(const ValueKey('ocr-candidate-phone-duplicate')),
      findsNothing,
    );
    expect(source.numbers, hasLength(3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('교보 101 실측 좌표 재생: 처음 박스와 수량 버튼은 겹친 1을 하나만 표시한다', (tester) async {
    // [OCR 추가] 과거 실제 OCR 좌표를 1/10로 표시한다. 이번 실기기의 OCR 응답을 재현했다고 주장하지 않는다.
    final recorded = recordedSource('original');
    final path = await regionPhoto(tester, width: 300, height: 400);
    ReceiptOcrCandidate scaled(ReceiptOcrCandidate candidate) =>
        ReceiptOcrCandidate(
          id: candidate.id,
          text: candidate.text,
          number: candidate.number,
          bounds: Rect.fromLTRB(
            candidate.bounds.left / 10,
            candidate.bounds.top / 10,
            candidate.bounds.right / 10,
            candidate.bounds.bottom / 10,
          ),
        ); // [OCR 추가]
    final base = fixture.source(
      recorded.products.map(scaled).toList(),
      recorded.numbers.map(scaled).toList(),
    );
    final source = ReceiptOcrResult(
      text: base.text,
      photoPath: path,
      rows: base.rows,
      products: base.products,
      numbers: base.numbers,
    ); // [OCR 추가]
    final draft = ReceiptDraft(
      id: 'kyobo-boxes',
      store: '교보문고',
      purchasedOn: '2026-10-08',
      lines: [],
      ocrResult: source,
    ); // [OCR 추가]
    const firstId = 'block-18-line-0-element-0';
    const duplicateId = 'block-19-line-0-element-0';
    const nextId = 'block-20-line-1-element-1';
    await tester.pumpWidget(
      MaterialApp(home: ReceiptSelectionScreen(draft: draft)),
    );
    await loadRegion(tester);
    expect(find.byKey(const ValueKey('ocr-box-$firstId')), findsOneWidget);
    expect(find.byKey(const ValueKey('ocr-box-$duplicateId')), findsNothing);
    expect(
      find.byKey(const ValueKey('ocr-box-$nextId')),
      findsOneWidget,
    ); // [OCR 추가] 다음 상품의 1은 별개다.
    final nameId = source.products
        .firstWhere((name) => name.text.contains('101'))
        .id;
    final name = find.byKey(ValueKey('ocr-candidate-$nameId'));
    await reveal(tester, name);
    await tester.tap(name);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ocr-box-$firstId')), findsOneWidget);
    expect(find.byKey(const ValueKey('ocr-box-$duplicateId')), findsNothing);
    await reveal(
      tester,
      find.byKey(const ValueKey('ocr-candidate-$firstId')),
    ); // [OCR 추가]
    expect(
      find.byKey(const ValueKey('ocr-candidate-$firstId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ocr-candidate-$duplicateId')),
      findsNothing,
    );
    expect(
      source.numbers.where(
        (number) => number.id == firstId || number.id == duplicateId,
      ),
      hasLength(2),
    );
    expect(tester.takeException(), isNull); // [OCR 추가] 원문 후보는 수정하지 않는다.
  });
  test('표시 중복 제거는 원래 객체·다른 값·다른 행·용량·기호를 보존한다', () {
    // [OCR 추가] 원문 숫자는 number가 없어도 중복을 판별하고 용량을 숫자로 바꾸지 않는다.
    final first = fixture.number('one', 1, 10, quantity: true);
    final duplicate = ReceiptOcrCandidate(
      id: 'duplicate',
      text: '1',
      bounds: first.bounds,
    );
    final conflict = fixture.number('two', 2, 10, quantity: true);
    final next = fixture.number('next', 1, 50, quantity: true);
    final volume = ReceiptOcrCandidate(
      id: 'volume',
      text: '1L',
      bounds: first.bounds,
    );
    final symbol = ReceiptOcrCandidate(
      id: 'symbol',
      text: '*',
      bounds: first.bounds,
    );
    final candidates = [first, duplicate, conflict, next, volume, symbol];
    final shown = receiptCandidatesWithoutDuplicateNumbers(candidates);
    expect(shown, [first, conflict, next, volume, symbol]);
    expect(shown.first, same(first));
    expect(candidates, hasLength(6));
    expect(volume.number, isNull); // [OCR 추가]
    expect(
      receiptCandidatesWithoutDuplicateNumbers(
        candidates,
        selectedId: duplicate.id,
      ),
      [duplicate, conflict, next, volume, symbol],
    ); // [OCR 추가] 중복 중 사용자가 고른 후보가 있으면 그 ID와 영역을 유지한다.
  });
  test('교보 보정 실측 좌표: 마지막 두 금액은 전체 OCR 후보를 재사용한다', () {
    // [OCR 추가] 저장된 실제 응답 재생이다. 새 사진 인식과 구분한다.
    final source = recordedSource('corrected'); // [OCR 추가]
    final first = source.products.first; // [OCR 추가]
    final amount = source.numbers.firstWhere(
      (n) => n.number == 9600 && n.bounds.left > 1500,
    ); // [OCR 추가]
    final rawQuantity = source.numbers.firstWhere(
      (n) => n.number == 1,
    ); // [OCR 추가]
    final quantity = ReceiptOcrCandidate(
      id: 'manual-first-q',
      text: '1',
      number: 1,
      bounds: Rect.fromCenter(
        center: rawQuantity.bounds.center,
        width: 80,
        height: 100,
      ),
    ); // [OCR 추가]
    final lines = automaticReceiptLines(
      source,
      ReceiptAutomaticSeed(
        product: first,
        amount: amount,
        quantity: quantity,
        isUnitPrice: false,
      ),
    ); // [OCR 추가]
    for (final suffix in ['303/LEAVES', '304-CA1S']) {
      // [OCR 추가]
      final line = lines.singleWhere(
        (line) => line.ocrProduct!.text.contains(suffix),
      ); // [OCR 추가]
      final expected = source.numbers.singleWhere(
        (n) =>
            n.number == 3500 &&
            n.bounds.left > 1500 &&
            n.bounds.top > line.ocrProduct!.bounds.bottom &&
            n.bounds.top < line.ocrProduct!.bounds.bottom + 200,
      ); // [OCR 추가]
      expect(line.ocrAmount?.id, expected.id); // [OCR 추가]
      expect(line.ocrAmount?.bounds, expected.bounds); // [OCR 추가]
      expect(line.total, 3500); // [OCR 추가]
      expect(line.selected, isTrue); // [OCR 추가]
      // [OCR 추가] 허용 폭이 커져도 같은 행의 서로 다른 두 금액은 임의 선택하지 않는다.
      final ambiguousSource = fixture.source(source.products, [
        ...source.numbers,
        ReceiptOcrCandidate(
          id: 'conflicting-price',
          text: '3600',
          number: 3600,
          bounds: expected.bounds.shift(const Offset(10, 0)),
        ),
      ]); // [OCR 추가]
      final ambiguous =
          automaticReceiptLines(
            ambiguousSource,
            ReceiptAutomaticSeed(
              product: first,
              amount: amount,
              quantity: quantity,
              isUnitPrice: false,
            ),
          ).singleWhere(
            (item) => item.ocrProduct!.id == line.ocrProduct!.id,
          ); // [OCR 추가]
      expect(ambiguous.ocrAmount, isNull); // [OCR 추가]
      expect(ambiguous.selected, isFalse); // [OCR 추가]
    } // [OCR 추가]
  }); // [OCR 추가]
  for (final mode in ['original', 'corrected']) {
    test('교보 실제 좌표 재생: $mode 전체 OCR 이름·금액 유지와 누락 부분 재인식', () async {
      final source = recordedSource(mode); // [OCR 추가]
      final first = source.products.firstWhere(
        (name) => name.text.contains('포스트잇'),
      ); // [OCR 추가]
      final quantities =
          source.numbers
              .where(
                (number) =>
                    number.number == 1 &&
                    number.bounds.top > first.bounds.top &&
                    number.bounds.top < first.bounds.bottom + 220,
              )
              .toList()
            ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top)); // [OCR 추가]
      final amounts =
          source.numbers
              .where(
                (number) =>
                    number.number == 9600 &&
                    number.bounds.top > first.bounds.top &&
                    number.bounds.top < first.bounds.bottom + 220,
              )
              .toList()
            ..sort(
              (a, b) => b.bounds.right.compareTo(a.bounds.right),
            ); // [OCR 추가]
      final seed = ReceiptAutomaticSeed(
        product: first,
        quantity: ReceiptOcrCandidate(
          id: 'manual-q',
          text: '1',
          number: 1,
          bounds: Rect.fromCenter(
            center: quantities.first.bounds.center,
            width: 80,
            height: 100,
          ),
        ),
        amount: amounts.first,
        isUnitPrice: false,
      ); // [OCR 추가]
      final scans = recordedScans(mode); // [OCR 추가]
      var partialCalls = 0; // [OCR 추가]
      final lines = await readAutomaticReceiptLines(
        source: source,
        seed: seed,
        photoBytes: Uint8List(0),
        photoSize: mode == 'original'
            ? const Size(3000, 4000)
            : const Size(2218, 4002),
        isCurrent: () => true,
        scanRegion: (_, bounds) async {
          if (bounds.center.dx < seed.quantity!.bounds.left) {
            return scans[0]; // [OCR 추가]
          }
          if (bounds.center.dx < seed.amount.bounds.left) {
            return scans[1]; // [OCR 추가]
          }
          return scans[2]; // [OCR 추가]
        },
        recognize: (_, bounds) async {
          partialCalls++;
          // [OCR 수정] 기존 전체 OCR 금액은 재사용하고 누락 금액만 부분 OCR 응답을 합성한다.
          expect(
            bounds.center.dx,
            greaterThan(seed.quantity!.bounds.center.dx),
          );
          return '3500';
        },
      );
      expect(
        lines,
        hasLength(mode == 'original' ? 6 : 8),
      ); // [OCR 수정] 원본의 마지막 두 이름은 시작 열 허용 범위 밖이며 이름 열로 보완하지 않는다.
      expect(lines!.map((line) => line.total), [
        9600,
        1300,
        1300,
        1300,
        1300,
        3500,
        if (mode == 'corrected') 3500,
        if (mode == 'corrected') 3500,
      ]); // [OCR 수정]
      expect(
        lines.every((line) => line.quantity == 1 && line.selected),
        isTrue,
      ); // [OCR 추가]
      expect(
        partialCalls,
        0,
      ); // [OCR 수정] 원근 오차 범위에서 전체 OCR 금액을 재사용하여 잘못된 위치의 재인식을 피한다.
    });
  }

  test('검증된 숫자 열도 다음 상품 행이나 서로 다른 값은 임의로 선택하지 않는다', () {
    const expected = Rect.fromLTRB(100, 100, 120, 120); // [OCR 추가]
    const allowed = Rect.fromLTRB(0, 90, 300, 130); // [OCR 추가]
    const first = ReceiptOcrCandidate(
      id: 'one',
      text: '1',
      bounds: Rect.fromLTRB(150, 100, 170, 120),
    ); // [OCR 추가]
    const conflict = ReceiptOcrCandidate(
      id: 'two',
      text: '2',
      bounds: Rect.fromLTRB(150, 100, 170, 120),
    ); // [OCR 추가]
    const next = ReceiptOcrCandidate(
      id: 'next',
      text: '1',
      bounds: Rect.fromLTRB(150, 125, 170, 145),
    ); // [OCR 추가]
    expect(
      receiptColumnRowNear(
        [first],
        expected,
        allowed,
        quantity: true,
        verifiedColumn: true,
      ),
      first,
    ); // [OCR 추가]
    expect(
      receiptColumnRowNear(
        [first, conflict],
        expected,
        allowed,
        quantity: true,
        verifiedColumn: true,
      ),
      isNull,
    ); // [OCR 추가]
    expect(
      receiptColumnRowNear(
        [next],
        expected,
        allowed,
        quantity: true,
        verifiedColumn: true,
      ),
      isNull,
    ); // [OCR 추가]
  });
}
