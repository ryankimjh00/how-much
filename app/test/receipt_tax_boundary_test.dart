import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_automatic.dart'; // [OCR 추가]
import 'package:how_much/receipt_ocr.dart'; // [OCR 추가]
import 'receipt_ocr_test.dart' as ocr; // [OCR 추가]
import 'receipt_automatic_test.dart' as fixture; // [OCR 추가]
import 'receipt_automatic_retry_test.dart' show seedFor; // [OCR 추가]

void main() {
  test('같은 행의 부가세·과세와 내부 공백·별도 OCR 줄을 경계로 사용한다', () {
    expect(
      receiptProductEndAboveTax([
        ocr.row(['부가세', '과세'], top: 200),
      ]),
      200,
    ); // [OCR 추가]
    expect(
      receiptProductEndAboveTax([
        ocr.row(['부 가 세'], top: 200),
        ocr.row(['과 세'], top: 202),
      ]),
      200,
    ); // [OCR 추가]
  });
  test('열별 글자 조각은 작은 위아래 오차가 있어도 왼쪽 순서로 단어를 묶는다', () {
    final rows = [
      for (final (index, text) in ['부', '가', '세', '과', '세'].indexed)
        ReceiptOcrRow(
          id: 'char-$index',
          text: text,
          bounds: Rect.fromLTWH(
            index * 30.0,
            200 + (index.isEven ? 0 : 2),
            20,
            20,
          ),
          tokens: [],
        ),
    ]; // [OCR 추가]
    expect(receiptProductEndAboveTax(rows), 200); // [OCR 추가]
  });
  test('붙어 있는 서로 다른 행·단독 단어·비과세는 종료 조건이 아니다', () {
    expect(
      receiptProductEndAboveTax([
        ocr.row(['부가세'], top: 200),
        ocr.row(['과세'], top: 222),
      ]),
      isNull,
    ); // [OCR 추가]
    expect(
      receiptProductEndAboveTax([
        ocr.row(['부가세'], top: 200),
      ]),
      isNull,
    ); // [OCR 추가]
    expect(
      receiptProductEndAboveTax([
        ocr.row(['과세'], top: 200),
      ]),
      isNull,
    ); // [OCR 추가]
    expect(
      receiptProductEndAboveTax([
        ocr.row(['부가세', '비과세'], top: 200),
      ]),
      isNull,
    ); // [OCR 추가]
  });
  test('과세물품가액은 단독·띄어쓰기·같은 행의 분리 조각도 정지행이다', () {
    // [OCR 추가] 공백과 OCR 줄 분리는 허용하되 서로 다른 사진 행은 합치지 않는다.
    for (final text in ['과세물품가액', '과 세 물 품 가 액']) {
      expect(
        receiptProductEndAboveTax([
          ocr.row([text], top: 200),
        ]),
        200,
      );
    }
    expect(
      receiptProductEndAboveTax([
        ocr.row(['과세물품', '가액'], top: 200),
      ]),
      200,
    ); // [OCR 추가]
    expect(
      receiptProductEndAboveTax([
        ocr.row(['과세물품'], top: 200),
        ocr.row(['가액'], top: 222),
      ]),
      isNull,
    ); // [OCR 추가]
    expect(
      receiptProductEndAboveTax([
        ocr.row(['비과세물품가액'], top: 200),
      ]),
      isNull,
    ); // [OCR 추가]
  });
  test('과세·합계는 같은 행일 때만 정지하며 합계 단독·비과세는 제외한다', () {
    // [OCR 추가] 열별 OCR 줄도 같은 사진 행이면 쌍으로 확인한다.
    expect(
      receiptProductEndAboveTax([
        ocr.row(['과 세'], top: 200),
        ocr.row(['합 계'], top: 202),
      ]),
      200,
    ); // [OCR 추가]
    expect(
      receiptProductEndAboveTax([
        ocr.row(['과세'], top: 200),
        ocr.row(['합계'], top: 222),
      ]),
      isNull,
    ); // [OCR 추가]
    for (final texts in [
      ['합계'],
      ['비과세', '합계'],
    ]) {
      expect(receiptProductEndAboveTax([ocr.row(texts, top: 200)]), isNull);
    } // [OCR 추가]
  });
  test('결제·대상·금액은 같은 행에 세 단어가 모두 있어야 정지한다', () {
    // [OCR 추가] 띄어쓰기와 OCR 줄 분리는 허용하지만 다른 사진 행을 합치지 않는다.
    expect(
      receiptProductEndAboveTax([
        ocr.row(['결제대상금액'], top: 200),
      ]),
      200,
    );
    expect(
      receiptProductEndAboveTax([
        ocr.row(['결 제'], top: 200),
        ocr.row(['대 상', '금 액'], top: 202),
      ]),
      200,
    ); // [OCR 추가]
    expect(
      receiptProductEndAboveTax([
        ocr.row(['결제', '대상'], top: 200),
        ocr.row(['금액'], top: 222),
      ]),
      isNull,
    ); // [OCR 추가]
    for (final texts in [
      ['결제', '대상'],
      ['결제', '금액'],
      ['대상', '금액'],
    ]) {
      expect(receiptProductEndAboveTax([ocr.row(texts, top: 200)]), isNull);
    } // [OCR 추가]
  });
  for (final taxLabels in [
    ['부가세', '과세'],
    ['과세물품가액'],
    ['과세', '합계'],
    ['결제', '대상', '금액'], // [OCR 추가]
  ]) {
    // [OCR 수정] 네 정지 조건 모두 크롭·검토 경계와 원문 보존을 확인한다.
    for (final taxTop in [80.0, 200.0]) {
      test(
        '자동 크롭·검토는 수량 공백과 세금 행 중 더 위에서 종료한다: $taxLabels / $taxTop',
        () async {
          // [OCR 수정]
          // [OCR 추가] 모의 OCR 응답으로 경계 전달과 원문 보존을 검사한다. 실사진 재인식과 구분한다.
          final products = [
            fixture.name('first', '퍼실', 10),
            fixture.name('second', '베지밀', 50),
            fixture.name('third', '마미손', 90),
            fixture.name('footer', '하단조각', 230),
          ]; // [OCR 추가]
          final base = fixture.source(products, [
            fixture.number('q1', 3, 10, quantity: true),
            fixture.number('p1', 80940, 10),
            fixture.number('q2', 2, 50, quantity: true),
            fixture.number('p2', 33760, 50),
            fixture.number('q3', 1, 90, quantity: true),
            fixture.number('p3', 9980, 90),
          ]); // [OCR 추가]
          final source = ReceiptOcrResult(
            text: base.text,
            photoPath: base.photoPath,
            rows: [
              ...base.rows,
              ocr.row(taxLabels, top: taxTop), // [OCR 수정]
            ],
            products: base.products,
            numbers: base.numbers,
          ); // [OCR 추가]
          final crops = <Rect>[]; // [OCR 추가]
          var partials = 0; // [OCR 추가]
          ReceiptOcrResult? accumulated; // [OCR 추가]
          final lines = await readAutomaticReceiptLines(
            source: source,
            seed: seedFor(source),
            photoBytes: Uint8List(0),
            photoSize: const Size(400, 600),
            isCurrent: () => true,
            scanRegion: (_, bounds) async {
              crops.add(bounds);
              return products;
            },
            recognize: (_, _) async {
              partials++;
              return '';
            },
            onCandidates: (result) => accumulated = result,
          ); // [OCR 추가]
          expect(
            crops,
            isEmpty,
          ); // [OCR 수정] 전체 OCR 수량이 모두 연결되면 열을 읽지 않아도 종료 경계를 유지한다. // [OCR 추가]
          expect(lines, hasLength(taxTop == 80 ? 2 : 3)); // [OCR 추가]
          expect(lines!.every((line) => line.selected), isTrue); // [OCR 추가]
          expect(partials, 0); // [OCR 추가]
          expect(
            accumulated!.products,
            hasLength(4),
          ); // [OCR 추가] 범위 밖의 원본 이름·숫자는 누적 결과에 보존한다.
          expect(source.rows.last.text, taxLabels.join(' ')); // [OCR 수정]
          expect(
            automaticReceiptLines(source, seedFor(source)),
            hasLength(taxTop == 80 ? 2 : 3),
          ); // [OCR 추가] 사진 없이 후보를 검토하는 경우도 세금 경계를 적용한다.
        },
      );
    }
  } // [OCR 추가]
}
