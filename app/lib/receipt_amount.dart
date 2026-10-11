import 'models.dart'; // [OCR 수정]

/// [OCR 추가] 단가/총액 입력을 기존 수량·결제금액 모델로 변환한다. 필수 수량 누락과 곱셈 초과를 거부한다.
ReceiptLineDraft receiptLineFromAmount({
  // [OCR 추가]
  required String id, // [OCR 추가]
  required String title, // [OCR 추가]
  required int amount, // [OCR 추가]
  required bool isUnitPrice, // [OCR 추가]
  int? quantity, // [OCR 추가]
}) {
  // [OCR 추가]
  // [OCR 수정]
  if (amount < 0 || amount > 9999999) {
    // [OCR 추가]
    // [OCR 추가]
    throw const FormatException('금액은 0~9,999,999원으로 입력해주세요.'); // [OCR 수정]
  } // [OCR 추가]
  if (!isUnitPrice && quantity == null) {
    // [OCR 추가]
    // [OCR 추가]
    throw const FormatException('상품 결제금액을 입력할 때는 수량이 필요해요.'); // [OCR 수정]
  } // [OCR 추가]
  final confirmedQuantity = quantity ?? 1; // [OCR 수정]
  if (confirmedQuantity < 1 || confirmedQuantity > 999) {
    // [OCR 추가]
    // [OCR 추가]
    throw const FormatException('수량은 1~999개로 입력해주세요.'); // [OCR 수정]
  } // [OCR 추가]
  final total = isUnitPrice ? amount * confirmedQuantity : amount; // [OCR 수정]
  if (total > 9999999) {
    // [OCR 추가]
    // [OCR 추가]
    throw const FormatException(
      // [OCR 추가]
      '수량을 곱한 상품 결제금액은 9,999,999원을 넘을 수 없어요.', // [OCR 추가]
    ); // [OCR 수정]
  } // [OCR 추가]
  return ReceiptLineDraft(
    // [OCR 추가]
    id: id, // [OCR 추가]
    title: title, // [OCR 추가]
    quantity: confirmedQuantity, // [OCR 추가]
    total: total, // [OCR 추가]
  ); // [OCR 수정]
} // [OCR 수정]
