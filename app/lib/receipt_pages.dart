import 'package:flutter/material.dart'; // [OCR 추가]
import 'models.dart'; // [OCR 추가]
import 'receipt_selection_screen.dart'; // [OCR 추가]

/// [OCR 수정] 촬영/앨범 선택 단계에는 사진 경로만 보관하고 OCR은 실행하지 않는다.
class ReceiptPhotoPage {
  const ReceiptPhotoPage({required this.path}); // [OCR 수정]
  final String path; // [OCR 수정]
} // [OCR 추가]

/// [OCR 추가] 장별 선택을 독립 ID와 원래 사진 좌표로 모은다. 같은 상품의 중복은 사용자가 검토에서 제외한다.
ReceiptDraft combineReceiptPages(List<ReceiptDraft> pages) {
  // [OCR 추가]
  if (pages.isEmpty || pages.any((page) => page.ocrResult == null)) {
    // [OCR 추가]
    throw const FormatException('선택한 영수증 사진을 확인해주세요.'); // [OCR 추가]
  } // [OCR 추가]
  final first = pages.first; // [OCR 추가]
  return ReceiptDraft(
    // [OCR 추가]
    id: 'pages-${first.id}', // [OCR 추가]
    store: first.store, // [OCR 추가]
    purchasedOn: first.purchasedOn, // [OCR 추가]
    condition: first.condition, // [OCR 추가]
    share: first.share, // [OCR 추가]
    ocrResult: first.ocrResult, // [OCR 추가]
    ocrPages: [for (final page in pages) page.ocrResult!], // [OCR 추가]
    lines: [
      // [OCR 추가]
      for (var i = 0; i < pages.length; i++) // [OCR 추가]
        for (final line in pages[i].lines) // [OCR 추가]
          ReceiptLineDraft(
            // [OCR 추가]
            id: 'page-$i-${line.id}', // [OCR 추가]
            title: line.title, // [OCR 추가]
            quantity: line.quantity, // [OCR 추가]
            total: line.total, // [OCR 추가]
            selected: line.selected, // [OCR 추가]
            itemId: line.itemId, // [OCR 추가]
            spec: line.spec, // [OCR 추가]
            ocrProduct: line.ocrProduct, // [OCR 추가]
            ocrAmount: line.ocrAmount, // [OCR 추가]
            ocrQuantity: line.ocrQuantity, // [OCR 추가]
            ocrAmountIsUnitPrice: line.ocrAmountIsUnitPrice, // [OCR 추가]
            ocrInputAmount: line.ocrInputAmount, // [OCR 추가]
            ocrNotice: line.ocrNotice, // [OCR 추가]
            receiptPhotoIndex: i, // [OCR 추가]
            setParentId:
                line
                    .setParentId
                    .isEmpty // [OCR 추가]
                ? '' // [OCR 추가]
                : 'page-$i-${line.setParentId}', // [OCR 추가]
          ), // [OCR 추가]
    ], // [OCR 추가]
  ); // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 각 장에서 첫 상품 기준을 새로 받는다. 완료한 장은 보존하며 모든 장이 끝나야 통합 검토 초안을 반환한다.
Future<ReceiptDraft?> selectReceiptPages(
  // [OCR 추가]
  BuildContext context, // [OCR 추가]
  List<ReceiptPhotoPage> pages, { // [OCR 추가]
  required Map<ReceiptPhotoPage, ReceiptDraft> selections, // [OCR 추가]
  required Map<ReceiptPhotoPage, ReceiptDraft> recognizedPages, // [OCR 추가]
  required Future<ReceiptDraft?> Function(ReceiptPhotoPage) // [OCR 추가]
  recognize, // [OCR 추가]
  required bool Function() isCurrent, // [OCR 추가]
}) async {
  // [OCR 추가]
  for (var i = 0; i < pages.length; i++) {
    // [OCR 추가]
    if (!context.mounted || !isCurrent()) return null; // [OCR 추가]
    final page = pages[i]; // [OCR 추가]
    if (selections.containsKey(page)) continue; // [OCR 추가]
    var draft = recognizedPages[page]; // [OCR 추가]
    if (draft == null) {
      // [OCR 추가]
      draft = await recognize(page); // [OCR 추가] 촬영 완료 이후 해당 장을 선택할 때 처음 읽는다.
      if (draft == null || !context.mounted || !isCurrent()) {
        // [OCR 수정]
        return null; // [OCR 수정]
      } // [OCR 수정]
      recognizedPages[page] = draft; // [OCR 추가] 취소 후 다시 선택해도 완료된 OCR을 반복하지 않는다.
    } // [OCR 추가]
    final selected = await Navigator.push<ReceiptDraft>(
      // [OCR 추가]
      context, // [OCR 추가]
      MaterialPageRoute(
        // [OCR 추가]
        builder: (_) => ReceiptSelectionScreen(
          // [OCR 추가]
          draft: draft!, // [OCR 수정]
          pageNumber: i + 1, // [OCR 추가]
          pageCount: pages.length, // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    // [OCR 추가] 취소·계정 변경·화면 종료 시 다음 장과 최종 검토로 진행하지 않는다.
    if (selected == null || !context.mounted || !isCurrent()) {
      return null; // [OCR 추가]
    }
    selections[page] = selected; // [OCR 추가]
  } // [OCR 추가]
  return combineReceiptPages([
    for (final page in pages) selections[page]!,
  ]); // [OCR 추가]
} // [OCR 추가]
