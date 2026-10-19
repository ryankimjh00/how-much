import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_column_scan.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]

void main() {
  for (final seedIndex in [0, 1]) {
    test('교보101 중복 수량: 첫 기준$seedIndex에서도 이미 읽힌 수량·금액을 재사용한다', () async {
      // [OCR 추가] 실기기의 작은 가로 틈 중복을 합성한 회귀이며 새 사진 OCR과 구분한다.
      final names = [
        for (var i = 0; i < 3; i++)
          fixture.name('name-$i', i == 0 ? '포스트잇' : '101 스티커', 10 + i * 40),
      ];
      final q1 = fixture.number('q1', 1, 10, quantity: true);
      const q2 = ReceiptOcrCandidate(
        id: 'q2',
        text: '1',
        number: 1,
        bounds: Rect.fromLTWH(180, 50, 8, 20),
      );
      const q2Duplicate = ReceiptOcrCandidate(
        id: 'q2-duplicate',
        text: '1',
        number: 1,
        bounds: Rect.fromLTWH(188.5, 50, 5, 20),
      );
      final q3 = fixture.number('q3', 1, 90, quantity: true);
      final amounts = [
        for (var i = 0; i < 3; i++)
          fixture.number('amount-$i', i == 0 ? 9600 : 1300, 10 + i * 40),
      ];
      final source = fixture.source(names, [
        q1,
        q2,
        q2Duplicate,
        q3,
        ...amounts,
      ]);
      var partialCalls = 0;
      final scans = <Rect>[];
      final lines = await readAutomaticReceiptLines(
        source: source,
        seed: ReceiptAutomaticSeed(
          product: names[seedIndex],
          quantity: seedIndex == 0 ? q1 : q2,
          amount: amounts[seedIndex],
          isUnitPrice: false,
        ),
        photoBytes: Uint8List(0),
        photoSize: const Size(400, 200),
        isCurrent: () => true,
        scanRegion: (_, bounds) async {
          scans.add(bounds);
          return [];
        },
        recognize: (_, _) async {
          partialCalls++;
          return '';
        },
      );
      expect(
        lines!.map((line) => line.quantity),
        List.filled(3 - seedIndex, 1),
      );
      expect(
        lines.map((line) => line.total),
        amounts.skip(seedIndex).map((amount) => amount.number),
      );
      expect(lines.every((line) => line.selected), isTrue);
      expect(partialCalls, 0); // [OCR 추가] 실패할 부분 OCR 대신 이미 읽힌 수량·금액을 사용해야 한다.
      expect(scans, isEmpty); // [OCR 수정] 상품명·금액 열은 다시 읽지 않는다.
      expect(source.numbers, hasLength(7)); // [OCR 추가] 원문에는 중복 두 개를 그대로 남긴다.
    });
  }

  test('숫자 열의 같은 글자 중복은 하나로 연결하고 다른 행·값은 유지한다', () {
    const first = ReceiptOcrCandidate(
      id: 'first',
      text: '1',
      bounds: Rect.fromLTWH(180, 50, 8, 20),
    );
    const duplicate = ReceiptOcrCandidate(
      id: 'duplicate',
      text: '1',
      bounds: Rect.fromLTWH(188.5, 50, 5, 20),
    );
    const next = ReceiptOcrCandidate(
      id: 'next',
      text: '1',
      bounds: Rect.fromLTWH(180, 90, 8, 20),
    );
    const conflict = ReceiptOcrCandidate(
      id: 'conflict',
      text: '2',
      bounds: Rect.fromLTWH(180, 50, 8, 20),
    );
    const expected = Rect.fromLTWH(180, 50, 20, 20);
    const allowed = Rect.fromLTRB(0, 40, 400, 80);
    expect(
      receiptColumnRowNear(
        [first, duplicate, next],
        expected,
        allowed,
        quantity: true,
      )?.id,
      first.id,
    );
    expect(
      receiptColumnRowNear(
        [first, duplicate, conflict],
        expected,
        allowed,
        quantity: true,
      ),
      isNull,
    ); // [OCR 추가] 같은 위치의 상충 값은 임의 확정하지 않는다.
  });
}
