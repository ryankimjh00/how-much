import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_column_scan.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]

void main() {
  // [OCR 추가] 실제 접근성 박스에서 4dp 표시 여백을 뺀 추정 좌표다. ML Kit 원본 좌표가 아니다.
  const first = ReceiptOcrCandidate(
    id: 'sweets-q',
    text: '1',
    number: 1,
    bounds: Rect.fromLTRB(698.5, 659.5, 708.5, 691.5),
  );
  const duplicate = ReceiptOcrCandidate(
    id: 'sweets-q-duplicate',
    text: '1',
    number: 1,
    bounds: Rect.fromLTRB(713.5, 658.5, 724.5, 695.5),
  );

  test('스윗츠 중복 1은 표시·자동 누적·열 재사용 모두 하나로 센다', () {
    // [OCR 추가] 높이 32px에 가로 틈 5px인 중복을 재생하되 다른 행·열·값은 유지한다.
    const nextRow = ReceiptOcrCandidate(
      id: 'next-row',
      text: '1',
      number: 1,
      bounds: Rect.fromLTRB(698.5, 739.5, 708.5, 771.5),
    );
    const nextColumn = ReceiptOcrCandidate(
      id: 'next-column',
      text: '1',
      number: 1,
      bounds: Rect.fromLTRB(740, 659.5, 750, 691.5),
    );
    final conflict = ReceiptOcrCandidate(
      id: 'conflict',
      text: '2',
      number: 2,
      bounds: first.bounds,
    );
    final candidates = [first, duplicate, nextRow, nextColumn, conflict];
    expect(receiptCandidatesWithoutDuplicateNumbers(candidates), [
      first,
      nextRow,
      nextColumn,
      conflict,
    ]);
    expect(
      receiptNumbersWithCandidates([], candidates).map((value) => value.id),
      [first.id, nextRow.id, nextColumn.id, conflict.id],
    );
    expect(
      receiptColumnRowNear(
        [first, duplicate],
        first.bounds,
        const Rect.fromLTWH(650, 630, 150, 100),
        quantity: true,
      ),
      same(first),
    );
    expect(candidates, hasLength(5)); // [OCR 추가] 원문 후보는 변경하지 않는다.
  });

  test('스윗츠의 두 1 때문에 실제 수량을 버리고 부분 OCR하지 않는다', () async {
    // [OCR 추가] 좌표 관계만 합성하며 실제 사진 인식 성공으로 보고하지 않는다.
    const seedName = ReceiptOcrCandidate(
      id: 'seed-name',
      text: '첫 스티커',
      bounds: Rect.fromLTWH(300, 550, 300, 32),
    );
    const sweets = ReceiptOcrCandidate(
      id: 'sweets',
      text: '[MA]81763/페인팅 스티커/스윗츠',
      bounds: Rect.fromLTWH(300, 630, 330, 32),
    );
    const seedQuantity = ReceiptOcrCandidate(
      id: 'seed-q',
      text: '1',
      number: 1,
      bounds: Rect.fromLTRB(698.5, 579.5, 708.5, 611.5),
    );
    const seedAmount = ReceiptOcrCandidate(
      id: 'seed-p',
      text: '4000',
      number: 4000,
      bounds: Rect.fromLTWH(900, 579.5, 80, 32),
    );
    const amount = ReceiptOcrCandidate(
      id: 'sweets-p',
      text: '4900',
      number: 4900,
      bounds: Rect.fromLTWH(900, 659.5, 80, 32),
    );
    final source = fixture.source(
      [seedName, sweets],
      [seedQuantity, seedAmount, first, duplicate, amount],
    );
    var partialCalls = 0;
    final lines = await readAutomaticReceiptLines(
      source: source,
      seed: ReceiptAutomaticSeed(
        product: seedName,
        quantity: seedQuantity,
        amount: seedAmount,
        isUnitPrice: false,
      ),
      photoBytes: Uint8List(0),
      photoSize: const Size(1100, 2000),
      isCurrent: () => true,
      recognize: (_, _) async {
        partialCalls++;
        return '';
      },
    );
    expect(lines, hasLength(2));
    expect(lines!.last.quantity, 1);
    expect(lines.last.total, 4900);
    expect(lines.last.selected, isTrue);
    expect(partialCalls, 0);
  });
}
