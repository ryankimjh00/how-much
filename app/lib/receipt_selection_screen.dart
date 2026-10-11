import 'ocr_service.dart'; // [OCR 추가]
import 'receipt_automatic.dart'; // [OCR 추가]
import 'receipt_column_scan.dart'; // [OCR 추가]
import 'receipt_region_screen.dart'; // [OCR 추가]
import 'dart:io'; // [OCR 추가]
import 'dart:math' as math; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/gestures.dart'; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'package:intl/intl.dart'; // [OCR 추가]
import 'app_theme.dart'; // [OCR 추가]
import 'design_widgets.dart'; // [OCR 추가]
import 'models.dart'; // [OCR 추가]
import 'receipt_amount.dart'; // [OCR 추가]
import 'receipt_ocr.dart'; // [OCR 추가]

/// [OCR 추가] OCR 후보를 수동 선택하여 새 검토 초안을 반환한다. 취소는 원본 초안을 변경하지 않는다.
class ReceiptSelectionScreen extends StatefulWidget {
  // [OCR 추가]
  const ReceiptSelectionScreen({
    // [OCR 수정]
    super.key, // [OCR 수정]
    required this.draft, // [OCR 수정]
    this.editLine, // [OCR 수정]
    this.pageNumber, // [OCR 추가]
    this.pageCount, // [OCR 추가]
    this.recognizeRegion, // [OCR 추가]
    this.scanRegion, // [OCR 추가]
    this.recognizeQuantity, // [OCR 추가] 병렬 수량 인식도 모의 주입하여 두 필드 표시를 검증한다.
  }); // [OCR 수정] // [OCR 추가]
  final int? pageNumber; // [OCR 추가]
  final int? pageCount; // [OCR 추가]
  final ReceiptLineDraft? editLine; // [OCR 추가]
  final ReceiptDraft draft; // [OCR 추가]
  final Future<String> Function(Uint8List, Rect)? recognizeRegion; // [OCR 추가]
  final Future<String> Function(Uint8List, Rect)? recognizeQuantity; // [OCR 추가]
  final Future<List<ReceiptOcrCandidate>> Function(Uint8List, Rect)?
  scanRegion; // [OCR 추가]
  @override // [OCR 추가]
  State<ReceiptSelectionScreen> createState() => _ReceiptSelectionScreenState(); // [OCR 추가]
} // [OCR 추가]

class _ReceiptSelectionScreenState extends State<ReceiptSelectionScreen> {
  // [OCR 추가]
  // [OCR 추가] fresh의 접점 추적·목록 정지·사진 변환을 그대로 사용해 사진 조작과 후보 목록 스크롤을 분리한다.
  final _scroll = ScrollController(keepScrollOffset: false); // [OCR 추가]
  final _transform = TransformationController(); // [OCR 추가]
  final _photoPointers = <int>{}; // [OCR 추가]
  void _trackPhotoPointer(int pointer, bool down) {
    // [OCR 추가]
    // [OCR 추가]
    final wasActive = _photoPointers.isNotEmpty; // [OCR 추가]
    if (down) {
      // [OCR 추가]
      // [OCR 추가]
      _photoPointers.add(pointer); // [OCR 추가]
    } else {
      // [OCR 추가]
      // [OCR 추가]
      _photoPointers.remove(pointer); // [OCR 추가]
    } // [OCR 추가]
    if (wasActive == _photoPointers.isNotEmpty) {
      // [OCR 추가]
      return; // [OCR 추가]
    } // [OCR 추가]
    if (down && _scroll.hasClients) {
      // [OCR 추가]
      _scroll.jumpTo(_scroll.offset); // [OCR 추가]
    } // [OCR 추가]
    setState(() {}); // [OCR 추가]
  } // [OCR 추가]

  @override // [OCR 추가]
  void dispose() {
    // [OCR 추가]
    // [OCR 추가]
    _automaticRevision++; // [OCR 추가]
    _scroll.dispose(); // [OCR 추가]
    _transform.dispose(); // [OCR 추가]
    super.dispose(); // [OCR 추가]
  } // [OCR 추가]

  late List<ReceiptOcrCandidate> _products; // [OCR 추가]
  final _selectedIds = <String>[]; // [OCR 추가]
  final _pricesByProduct = <String, List<ReceiptOcrCandidate>>{}; // [OCR 추가]
  final _selectedPrices = <String, String>{}; // [OCR 추가]
  final _quantitiesByProduct =
      <String, List<ReceiptOcrCandidate>>{}; // [OCR 수정]
  final _selectedQuantities = <String, String>{}; // [OCR 수정]
  // [OCR 추가] 후보별 사본만 기록해 같은 원문을 다른 상품에서 골라도 크기 상태를 공유하지 않는다.
  final _quantitySearchAreas = <ReceiptOcrCandidate>{}; // [OCR 추가]
  final _changedDirectAmounts = <String>{}; // [OCR 추가]
  final _directPrices = <String, int>{}; // [OCR 수정]
  final _directQuantities = <String, int>{}; // [OCR 수정]
  bool _automatic = true; // [OCR 추가]
  bool _isUnitPrice = false; // [OCR 수정] 기본은 상품 결제금액이며 수량은 두 방식 모두 확인한다.
  bool _choosingQuantity = false; // [OCR 수정]
  bool _finished = false; // [OCR 추가]
  int? _priceIndex; // [OCR 추가]
  Uint8List? _photoBytes; // [OCR 추가]
  Size? _photoSize; // [OCR 추가]
  String _photoError = ''; // [OCR 추가]
  late final Future<void> _photoLoading; // [OCR 추가]
  bool _automaticReading = false; // [OCR 추가]
  int _automaticRevision = 0; // [OCR 추가]
  String _automaticProgress = ''; // [OCR 추가]
  Rect? _automaticBounds; // [OCR 추가]
  final _automaticFieldBounds = <String, Rect>{}; // [OCR 추가]
  final _automaticFieldProgress = <String, String>{}; // [OCR 추가]
  final _photoViewport = GlobalKey(); // [OCR 추가]
  ReceiptOcrResult? _accumulatedSource; // [OCR 추가]
  ReceiptOcrResult get _source =>
      _accumulatedSource ?? widget.draft.ocrResult!; // [OCR 수정]
  bool get _choosingNames => _priceIndex == null; // [OCR 추가]
  // [OCR 추가] 첫 선택에서는 후보 분류로 원문을 숨기지 않는다. 용도는 사용자가 선택한다.
  List<ReceiptOcrCandidate> get _photoCandidates {
    // [OCR 추가]
    final candidates = _visibleCandidates; // [OCR 추가]
    // [OCR 추가] 첫 선택 이후에는 기존 같은 열 상품명·수량·금액 후보 좁히기를 유지한다.
    if (!_choosingNames || _selectedIds.isNotEmpty) {
      // [OCR 추가]
      return candidates; // [OCR 추가]
    } // [OCR 추가]
    return receiptCandidatesWithoutDuplicateNumbers([
      // [OCR 추가]
      ...candidates, // [OCR 추가]
      ..._source.numbers.where(
        (candidate) => !_source.rows.any(
          (row) => row.tokens.any((token) => token.id == candidate.id),
        ),
      ), // [OCR 추가] 열/부분 OCR에서 새로 읽힌 숫자도 다음 검토·선택에서 표시한다.
      for (final row in _source.rows) // [OCR 추가]
        for (final token in row.tokens) // [OCR 추가]
          if (token.bounds.isFinite &&
              !token.bounds.isEmpty && // [OCR 추가]
              !candidates.any(
                (candidate) => // [OCR 추가]
                    candidate.bounds.left <= token.bounds.left && // [OCR 추가]
                    candidate.bounds.top <= token.bounds.top && // [OCR 추가]
                    candidate.bounds.right >= token.bounds.right && // [OCR 추가]
                    candidate.bounds.bottom >= token.bounds.bottom,
              )) // [OCR 추가]
            ReceiptOcrCandidate(
              // [OCR 추가]
              id: token.id,
              text: token.text,
              bounds: token.bounds, // [OCR 추가]
            ), // [OCR 추가]
    ]); // [OCR 수정] 원문 숫자의 겹친 박스에도 자동 누적과 같은 중복 기준을 적용한다.
  } // [OCR 추가]

  ReceiptOcrCandidate _product(String id) => // [OCR 추가]
      _products.firstWhere((item) => item.id == id); // [OCR 추가]
  List<ReceiptOcrCandidate> get _visibleCandidates {
    // [OCR 추가]
    if (_choosingNames) {
      // [OCR 추가]
      if (_automatic || _selectedIds.isEmpty) return _products; // [OCR 추가]
      final first = _product(_selectedIds.first); // [OCR 추가]
      return receiptProductsBelow(_products, first); // [OCR 추가]
    } // [OCR 추가]
    final product = _product(_selectedIds[_priceIndex!]); // [OCR 추가]
    if (_choosingQuantity) {
      return receiptCandidatesWithoutDuplicateNumbers(
        _quantitiesByProduct[product.id]!,
        selectedId: _selectedQuantities[product.id], // [OCR 추가]
      ); // [OCR 수정]
    }
    if (_automatic) {
      // [OCR 수정]
      // [OCR 수정]
      return receiptCandidatesWithoutDuplicateNumbers(
        receiptAutomaticAmountsNear(
          // [OCR 수정]
          // [OCR 추가]
          _source, // [OCR 수정]
          product, // [OCR 추가]
          quantity: _selectedCandidate(product.id, quantity: true), // [OCR 추가]
          amounts: _pricesByProduct[product.id]!, // [OCR 추가]
        ),
        selectedId: _selectedPrices[product.id], // [OCR 추가]
      ); // [OCR 수정]
    } // [OCR 추가]
    return receiptCandidatesWithoutDuplicateNumbers(
      _pricesByProduct[product.id]!,
      selectedId: _selectedPrices[product.id], // [OCR 추가]
    ); // [OCR 수정]
  } // [OCR 추가]

  @override // [OCR 추가]
  void initState() {
    // [OCR 추가]
    super.initState(); // [OCR 추가]
    _products = List.of(_source.products); // [OCR 추가]
    // [OCR 추가] 기존 항목은 별도 사본 상태에서 수량 → 금액 순서로 선택한다.
    final edited = widget.editLine; // [OCR 추가]
    if (edited != null) {
      if (edited.ocrQuantity != null) {
        // [OCR 추가]
        _quantitySearchAreas.add(edited.ocrQuantity!); // [OCR 추가]
      } // [OCR 추가]
      _automatic = false; // [OCR 수정] 기존 항목 편집은 전체 자동을 실행하지 않는다.
      // [OCR 수정]
      // [OCR 추가]
      final product = edited.ocrProduct!; // [OCR 추가]
      _products = [product]; // [OCR 추가]
      _selectedIds.add(product.id); // [OCR 추가]
      _pricesByProduct[product.id] = receiptPricesNear(
        // [OCR 수정]
        _source, // [OCR 수정]
        product, // [OCR 수정]
      ); // [OCR 추가]
      _quantitiesByProduct[product.id] = receiptPricesNear(
        // [OCR 수정]
        _source, // [OCR 수정]
        product, // [OCR 수정]
      ).where((c) => c.number! >= 1 && c.number! <= 999).toList(); // [OCR 추가]
      _directQuantities[product.id] = edited.quantity; // [OCR 추가]
      _directPrices[product.id] = // [OCR 추가]
          edited.ocrInputAmount ?? edited.total; // [OCR 추가]
      _isUnitPrice = edited.ocrAmountIsUnitPrice; // [OCR 수정]
      _priceIndex = 0; // [OCR 추가]
      _choosingQuantity = true; // [OCR 추가]
    } // [OCR 추가]
    _photoLoading = _loadPhoto(); // [OCR 수정]
  } // [OCR 추가]

  Future<void> _loadPhoto() async {
    // [OCR 추가]
    try {
      // [OCR 추가]
      final bytes = // [OCR 추가]
          _source.photoBytes ?? // [OCR 추가]
          await File(_source.photoPath).readAsBytes(); // [OCR 수정]
      final codec = await ui.instantiateImageCodec(bytes); // [OCR 추가]
      late final Size size; // [OCR 추가]
      try {
        // [OCR 추가]
        final frame = await codec.getNextFrame(); // [OCR 추가]
        size = Size(
          // [OCR 추가]
          frame.image.width.toDouble(), // [OCR 추가]
          frame.image.height.toDouble(), // [OCR 추가]
        ); // [OCR 추가]
        frame.image.dispose(); // [OCR 추가]
      } finally {
        // [OCR 추가]
        codec.dispose(); // [OCR 추가]
      } // [OCR 추가]
      if (!mounted) return; // [OCR 추가]
      setState(() {
        // [OCR 추가]
        _photoBytes = bytes; // [OCR 추가]
        _photoSize = size; // [OCR 추가]
      }); // [OCR 추가]
    } catch (_) {
      // [OCR 추가]
      if (mounted) {
        // [OCR 추가]
        setState(
          // [OCR 추가]
          () => _photoError = '사진을 열지 못했어요. 아래 후보 버튼으로 선택할 수 있어요.', // [OCR 추가]
        ); // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]

  bool _isSelected(ReceiptOcrCandidate candidate) {
    // [OCR 수정]
    // [OCR 수정]
    if (_choosingNames) return _selectedIds.contains(candidate.id); // [OCR 수정]
    final selected =
        _choosingQuantity // [OCR 수정]
        ? _selectedQuantities // [OCR 수정]
        : _selectedPrices; // [OCR 수정]
    return selected[_selectedIds[_priceIndex!]] == candidate.id; // [OCR 수정]
  } // [OCR 수정]

  void _prepareAutomaticSeed(ReceiptOcrCandidate product) {
    // [OCR 추가]
    _pricesByProduct.putIfAbsent(
      product.id,
      () => receiptPricesNear(_source, product),
    ); // [OCR 추가]
    _quantitiesByProduct.putIfAbsent(
      product.id,
      () => receiptPricesNear(_source, product)
          .where(
            (candidate) => candidate.number! >= 1 && candidate.number! <= 999,
          )
          .toList(),
    ); // [OCR 추가]
    _priceIndex = 0; // [OCR 추가]
    _choosingQuantity = true; // [OCR 추가]
  } // [OCR 추가]

  void _select(ReceiptOcrCandidate candidate) {
    // [OCR 수정]
    // [OCR 수정]
    setState(() {
      // [OCR 수정]
      // [OCR 수정]
      // [OCR 추가] 숫자·기호 원문 박스도 상품명으로 선택할 수 있게 선택 상태에 보관한다.
      if (_choosingNames && !_products.any((item) => item.id == candidate.id)) {
        // [OCR 추가]
        _products.add(candidate); // [OCR 추가]
      } // [OCR 추가]
      if (_choosingNames && _automatic) {
        // [OCR 추가]
        // [OCR 추가]
        final wasSelected = _selectedIds.contains(candidate.id); // [OCR 추가]
        _selectedIds.clear(); // [OCR 추가]
        if (!wasSelected) {
          // [OCR 수정]
          _selectedIds.add(candidate.id); // [OCR 수정]
          _prepareAutomaticSeed(candidate); // [OCR 추가]
        } // [OCR 수정]
        return; // [OCR 추가]
      } // [OCR 추가]
      if (_choosingNames) {
        // [OCR 수정]
        // [OCR 수정]
        if (_selectedIds.contains(candidate.id)) {
          // [OCR 수정]
          // [OCR 수정]
          if (_selectedIds.first == candidate.id) {
            // [OCR 수정]
            _selectedIds.clear(); // [OCR 수정]
          } else {
            // [OCR 수정]
            _selectedIds.remove(candidate.id); // [OCR 수정]
          } // [OCR 수정]
        } else {
          // [OCR 수정]
          _selectedIds.add(candidate.id); // [OCR 수정]
        } // [OCR 수정]
        return; // [OCR 수정]
      } // [OCR 수정]
      final id = _selectedIds[_priceIndex!]; // [OCR 수정]
      if (_choosingQuantity) {
        // [OCR 수정]
        // [OCR 수정] 수량만 바꾸어도 독립적으로 선택한 금액은 유지한다. 같은 영역을 두 필드로 쓰는 경우만 해제한다.
        if (_automatic && _selectedPrices[id] == candidate.id) {
          // [OCR 수정]
          // [OCR 추가]
          _selectedPrices.remove(id); // [OCR 추가]
          _directPrices.remove(id); // [OCR 추가]
        } // [OCR 추가]
        // [OCR 추가] 눈에 보인 한 글자 박스 여백을 실제 수량 열·부분 OCR의 기준 영역에 반영한다.
        final quantity = _quantityWithSearchArea(candidate); // [OCR 추가]
        final candidates = _quantitiesByProduct[id]!; // [OCR 추가]
        candidates[candidates.indexWhere((item) => item.id == candidate.id)] =
            quantity; // [OCR 추가]
        _selectedQuantities[id] = quantity.id; // [OCR 수정]
        _directQuantities.remove(id); // [OCR 수정]
        if (_automatic) _choosingQuantity = false; // [OCR 추가]
      } // [OCR 수정]
      else {
        // [OCR 수정]
        _selectedPrices[id] = candidate.id; // [OCR 수정]
        _directPrices.remove(id); // [OCR 수정]
      } // [OCR 수정]
    }); // [OCR 수정]
  } // [OCR 수정]

  int? _amountFor(String id) {
    // [OCR 수정]
    // [OCR 수정]
    if (_directPrices.containsKey(id)) return _directPrices[id]; // [OCR 수정]
    final selected = _selectedPrices[id]; // [OCR 수정]
    if (selected == null) return null; // [OCR 수정]
    return _pricesByProduct[id]! // [OCR 수정]
        .firstWhere((candidate) => candidate.id == selected) // [OCR 수정]
        .number; // [OCR 수정]
  } // [OCR 수정]

  int _quantityFor(String id) {
    // [OCR 수정]
    // [OCR 수정]
    if (_directQuantities.containsKey(id)) {
      // [OCR 수정]
      // [OCR 수정]
      return _directQuantities[id]!; // [OCR 수정]
    } // [OCR 추가]
    final selected = _selectedQuantities[id]; // [OCR 수정]
    if (selected == null) return 1; // [OCR 수정] 화면에서 확인할 기본 수량은 1개다. // [OCR 수정]
    return _quantitiesByProduct[id]! // [OCR 수정]
        .firstWhere((candidate) => candidate.id == selected) // [OCR 수정]
        .number!; // [OCR 수정]
  } // [OCR 수정]

  bool get _canContinue {
    // [OCR 수정]
    // [OCR 수정]
    if (_automatic) {
      // [OCR 수정]
      if (_selectedIds.length != 1) return false; // [OCR 추가]
      final id = _selectedIds.single; // [OCR 추가]
      final amount = _selectedCandidate(id); // [OCR 수정]
      final quantity = _selectedCandidate(id, quantity: true); // [OCR 수정]
      if (amount == null || quantity == null) return false; // [OCR 추가]
      // [OCR 추가] 어느 입력 칸을 보고 있어도 세 기준과 현재 좁힌 금액 범위를 확인한다.
      return receiptAutomaticAmountsNear(
        _source,
        _product(id),
        quantity: quantity,
        amounts: _pricesByProduct[id]!,
      ).any((candidate) => candidate.id == amount.id); // [OCR 수정]
    } // [OCR 수정]
    if (_choosingNames) return _selectedIds.isNotEmpty; // [OCR 수정]
    final id = _selectedIds[_priceIndex!]; // [OCR 수정]
    if (_choosingQuantity) {
      // [OCR 수정]
      // [OCR 수정]
      return true; // [OCR 수정] 기본 1개도 사용자가 확인해 진행할 수 있다.
    } // [OCR 추가]
    return _amountFor(id) != null; // [OCR 수정]
  } // [OCR 수정]

  void _next() {
    // [OCR 수정]
    // [OCR 수정]
    if (_finished || _automaticReading || !_canContinue) return; // [OCR 수정]
    if (_automatic) {
      // [OCR 추가]
      _finishAutomatic(); // [OCR 추가]
      return; // [OCR 추가]
    } // [OCR 추가]
    if (_choosingNames) {
      // [OCR 수정]
      // [OCR 수정]
      setState(() {
        // [OCR 수정]
        // [OCR 수정]
        for (final id in _selectedIds) {
          // [OCR 수정]
          // [OCR 수정]
          _pricesByProduct.putIfAbsent(
            // [OCR 수정]
            id, // [OCR 수정]
            () => receiptPricesNear(_source, _product(id)), // [OCR 수정]
          ); // [OCR 수정]
          // [OCR 수정] 이유: 수량과 금액은 같은 원본 숫자라도 독립된 후보 목록에서 수정한다.
          _quantitiesByProduct.putIfAbsent(
            // [OCR 수정]
            id, // [OCR 수정]
            () =>
                receiptPricesNear(_source, _product(id)) // [OCR 수정]
                    .where(
                      // [OCR 수정]
                      (candidate) => // [OCR 수정]
                          candidate.number! >= 1 &&
                          candidate.number! <= 999, // [OCR 수정]
                    ) // [OCR 수정]
                    .toList(), // [OCR 수정]
          ); // [OCR 수정]
        } // [OCR 수정]
        _priceIndex = 0; // [OCR 추가]
      }); // [OCR 수정]
      return; // [OCR 수정]
    } // [OCR 수정]
    if (widget.editLine != null && _choosingQuantity) {
      // [OCR 수정]
      // [OCR 추가]
      setState(() => _choosingQuantity = false); // [OCR 추가]
      return; // [OCR 추가]
    } // [OCR 추가]
    if (!_choosingQuantity && widget.editLine == null) {
      // [OCR 수정]
      // [OCR 수정]
      // [OCR 수정]
      // [OCR 수정] 모든 상품의 금액을 연결한 뒤 첫 상품의 수량 단계로 이동한다.
      setState(() {
        // [OCR 수정]
        if (_priceIndex! < _selectedIds.length - 1) {
          // [OCR 수정]
          _priceIndex = _priceIndex! + 1; // [OCR 수정]
        } else {
          // [OCR 수정]
          _priceIndex = 0; // [OCR 수정]
          _choosingQuantity = true; // [OCR 수정]
        } // [OCR 수정]
      }); // [OCR 수정]
      return; // [OCR 수정]
    } // [OCR 수정]
    final id = _selectedIds[_priceIndex!]; // [OCR 수정]
    try {
      // [OCR 수정]
      // [OCR 수정]
      receiptLineFromAmount(
        // [OCR 수정]
        id: 'check', // [OCR 수정]
        title: _product(id).text, // [OCR 수정]
        amount: _amountFor(id)!, // [OCR 수정]
        isUnitPrice: _isUnitPrice, // [OCR 수정]
        quantity: _quantityFor(id), // [OCR 수정]
      ); // [OCR 수정]
    } on FormatException catch (error) {
      // [OCR 수정]
      // [OCR 수정]
      ScaffoldMessenger.of(
        // [OCR 수정]
        context, // [OCR 수정]
      ).showSnackBar(SnackBar(content: Text(error.message))); // [OCR 수정]
      return; // [OCR 수정]
    } // [OCR 수정]
    if (_priceIndex! < _selectedIds.length - 1) {
      // [OCR 수정]
      // [OCR 수정]
      setState(() {
        // [OCR 수정]
        _priceIndex = _priceIndex! + 1; // [OCR 수정]
        // [OCR 수정] 수량도 선택된 상품 전체를 차례로 확인한다.
      }); // [OCR 수정]
      return; // [OCR 수정]
    } // [OCR 수정]
    final lines = <ReceiptLineDraft>[]; // [OCR 수정]
    for (var index = 0; index < _selectedIds.length; index++) {
      // [OCR 수정]
      // [OCR 수정]
      final productId = _selectedIds[index]; // [OCR 수정]
      lines.add(
        // [OCR 수정]
        receiptLineFromAmount(
          // [OCR 수정]
          id: 'manual-ocr-$index', // [OCR 수정]
          title: _product(productId).text, // [OCR 수정]
          amount: _amountFor(productId)!, // [OCR 수정]
          isUnitPrice: _isUnitPrice, // [OCR 수정]
          quantity: _quantityFor(productId), // [OCR 수정]
        ), // [OCR 수정]
      ); // [OCR 수정]
    } // [OCR 수정]
    // [OCR 추가] 상품명·선택 금액만 별도 박스로 남긴다. 직접 입력한 금액은 추정 박스를 만들지 않는다.
    for (var i = 0; i < lines.length; i++) {
      // [OCR 수정]
      // [OCR 추가]
      final id = _selectedIds[i]; // [OCR 추가]
      lines[i].ocrProduct = _product(id); // [OCR 추가]
      lines[i].ocrAmountIsUnitPrice = _isUnitPrice; // [OCR 추가]
      lines[i].ocrInputAmount = _amountFor(id); // [OCR 추가]
      lines[i].ocrQuantity = // [OCR 추가]
          _selectedCandidate(id, quantity: true) ?? // [OCR 추가]
          widget.editLine?.ocrQuantity; // [OCR 추가]
      final selected = _selectedPrices[id]; // [OCR 추가]
      if (selected != null) {
        // [OCR 추가]
        lines[i].ocrAmount = _pricesByProduct[id]!.firstWhere(
          (candidate) => candidate.id == selected,
        ); // [OCR 추가]
      } else if (!_changedDirectAmounts.contains(id)) {
        // [OCR 추가]
        lines[i].ocrAmount = widget.editLine?.ocrAmount; // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    _returnLines(lines); // [OCR 추가]
  } // [OCR 수정]

  void _returnLines(List<ReceiptLineDraft> lines) {
    if (_finished) return; // [OCR 추가] 건너뛰기 연속 입력으로 다음 화면까지 닫히지 않게 한다.
    // [OCR 추가]
    // [OCR 추가]
    _finished = true; // [OCR 수정]
    Navigator.pop(
      // [OCR 수정]
      context, // [OCR 수정]
      ReceiptDraft(
        // [OCR 수정]
        id: widget.draft.id, // [OCR 수정]
        store: widget.draft.store, // [OCR 수정]
        purchasedOn: widget.draft.purchasedOn, // [OCR 수정]
        lines: lines, // [OCR 수정]
        condition: widget.draft.condition, // [OCR 수정]
        share: widget.draft.share, // [OCR 수정]
        ocrResult: _source, // [OCR 수정]
      ), // [OCR 수정]
    ); // [OCR 수정]
  } // [OCR 추가]

  Future<void> _finishAutomatic() async {
    // [OCR 추가]
    if (_automaticReading || _finished) return; // [OCR 추가]
    final id = _selectedIds.single; // [OCR 추가]
    final seed = ReceiptAutomaticSeed(
      // [OCR 추가]
      product: _product(id),
      amount: _selectedCandidate(id)!, // [OCR 추가]
      quantity: _selectedCandidate(id, quantity: true), // [OCR 추가]
      isUnitPrice: _isUnitPrice,
      includeQuantity: true, // [OCR 추가]
    ); // [OCR 추가]
    final revision = ++_automaticRevision; // [OCR 추가]
    bool isCurrent() =>
        mounted && !_finished && revision == _automaticRevision; // [OCR 추가]
    setState(() {
      // [OCR 추가]
      _automaticReading = true; // [OCR 추가]
      _automaticBounds = null; // [OCR 추가]
      _automaticFieldBounds.clear(); // [OCR 추가]
      _automaticFieldProgress.clear(); // [OCR 추가]
      _automaticProgress = '자동 선택 영역을 읽고 있어요'; // [OCR 추가]
    }); // [OCR 추가]
    try {
      // [OCR 추가]
      // [OCR 추가] 사진 로딩 중 누르면 로딩 완료를 기다려 보정 사진과 OCR 좌표를 같은 기준으로 사용한다.
      await _photoLoading; // [OCR 추가]
      if (!isCurrent()) return; // [OCR 추가]
      final List<ReceiptLineDraft>? lines; // [OCR 추가]
      if (_photoBytes == null || _photoSize == null) {
        // [OCR 추가]
        // [OCR 추가] 사진을 열 수 없다는 기존 오류를 유지하며 기존 OCR 후보는 검토할 수 있게 남긴다.
        lines = automaticReceiptLines(
          _source,
          seed,
          products: _products,
        ); // [OCR 추가]
      } else {
        // [OCR 추가]
        // [OCR 추가] 열 탐색도 반복 OCR과 같은 프레임/터치 처리 대기를 사용한다.
        Future<void> prepareRead() async {
          // [OCR 수정] 프레임이 중지되어도 박스 표시 대기가 OCR을 막지 않게 최대 150ms만 기다린다.
          await WidgetsBinding.instance.endOfFrame.timeout(
            // [OCR 수정]
            const Duration(milliseconds: 150), // [OCR 추가]
            onTimeout: () {}, // [OCR 추가]
          ); // [OCR 수정]
          // [OCR 수정] 플랫폼 OCR을 연속 호출하기 전에 렌더링/터치 이벤트가 처리될 시간을 준다.
          await Future<void>.delayed(
            const Duration(milliseconds: 50),
          ); // [OCR 추가]
        } // [OCR 추가]

        // [OCR 추가] 모의 부분 OCR 주입 시 열 탐색도 별도로 주입해 실제 인식과 섞지 않는다.
        Future<List<ReceiptLineDraft>?> readWithSession(
          ReceiptRegionSession? session,
        ) async {
          // [OCR 추가]
          final scanRegion =
              widget.scanRegion ??
              (widget.recognizeRegion == null
                  ? (Uint8List bytes, Rect bounds) =>
                        session!.recognizeRegionRows(bounds)
                  : null); // [OCR 추가]
          return await readAutomaticReceiptLines(
            // [OCR 추가]
            source: _source,
            onCandidates: (result) {
              // [OCR 추가]
              if (!isCurrent()) return; // [OCR 추가]
              _accumulatedSource = result; // [OCR 추가]
              _products = List.of(result.products); // [OCR 추가]
            },
            seed: seed,
            products: _products, // [OCR 추가]
            photoBytes: _photoBytes!,
            photoSize: _photoSize!, // [OCR 추가]
            scanRegion: scanRegion == null
                ? null
                : (bytes, bounds) async {
                    await prepareRead(); // [OCR 추가]
                    if (!isCurrent()) return []; // [OCR 추가]
                    return await scanRegion(bytes, bounds); // [OCR 추가]
                  }, // [OCR 추가]
            recognize: (bytes, bounds) async {
              // [OCR 수정]
              await prepareRead(); // [OCR 수정]
              if (!isCurrent()) return ''; // [OCR 추가]
              final recognize =
                  widget.recognizeRegion ??
                  (Uint8List bytes, Rect bounds) =>
                      session!.recognizeRegion(bounds); // [OCR 추가]
              return await recognize(bytes, bounds); // [OCR 수정]
            }, // [OCR 수정]
            recognizeQuantity:
                widget.recognizeQuantity ??
                (session?.quantitySession == null
                    ? null
                    : (bytes, bounds) async {
                        await prepareRead(); // [OCR 추가]
                        if (!isCurrent()) return ''; // [OCR 추가]
                        return await session!.quantitySession!
                            .recognizeQuantityRegion(
                              // [OCR 수정]
                              bounds,
                              // [OCR 추가] 사용자가 지정한 수량·금액 간격으로 같은 행의 가격 문맥까지 포함한다.
                              horizontalContext: seed.quantity == null
                                  ? 0
                                  : (seed.amount.bounds.right -
                                            seed.quantity!.bounds.right)
                                        .abs(), // [OCR 추가]
                            ); // [OCR 추가]
                      }), // [OCR 수정]
            isCurrent: isCurrent, // [OCR 추가]
            onProductShown: prepareRead, // [OCR 추가]
            onProgress: (item, total, field, attempts, successes, bounds) {
              // [OCR 추가]
              if (!isCurrent()) return; // [OCR 추가]
              setState(() {
                // [OCR 수정] 두 필드가 갱신될 때 서로의 박스와 진행 문구를 덮어쓰지 않는다.
                final quantityColumn =
                    item == 0 &&
                    field == '수량 열 확인' &&
                    _automaticFieldBounds.isNotEmpty;
                if ((item > 0 && field != '상품명 확인') || quantityColumn) {
                  final label = quantityColumn ? '수량' : field;
                  _automaticFieldBounds[label] = bounds;
                  _automaticFieldProgress[label] = quantityColumn
                      ? '$field $attempts회'
                      : '$field $attempts회 인식 · 성공 $successes회';
                  _automaticBounds = null;
                  if (!quantityColumn) _automaticProgress = '$item/$total 상품';
                } else {
                  // [OCR 추가] 새 상품/초기 열 탐색으로 넘어가면 이전 상품 박스를 지운다.
                  _automaticFieldBounds.clear();
                  _automaticFieldProgress.clear();
                  _automaticBounds = bounds;
                  _automaticProgress = item == 0
                      ? field
                      : '$item/$total 상품 · $field';
                }
              }); // [OCR 수정]
              // [OCR 추가] 두 박스의 합친 범위를 따라가 한쪽 갱신마다 사진이 좌우로 흔들리지 않게 한다.
              final visible = _automaticFieldBounds.values.fold<Rect?>(
                null,
                (combined, rect) =>
                    combined == null ? rect : combined.expandToInclude(rect),
              );
              _followAutomaticBounds(visible ?? bounds); // [OCR 수정]
            }, // [OCR 추가]
          ); // [OCR 추가]
        } // [OCR 추가]

        // [OCR 수정] 실제 자동 선택만 한 장 전용 세션으로 감싼다. 모의 OCR은 네이티브 인식과 섞지 않는다.
        if (widget.recognizeRegion == null) {
          lines = await OcrService().withReceiptRegionSession(
            _photoBytes!,
            readWithSession,
            parallelQuantity: true, // [OCR 추가]
          ); // [OCR 추가]
        } else {
          lines = await readWithSession(null); // [OCR 추가]
        } // [OCR 추가]
      } // [OCR 추가]
      if (!isCurrent() || lines == null) return; // [OCR 추가]
      _returnLines(lines); // [OCR 추가]
    } on FormatException catch (error) {
      // [OCR 추가]
      if (!mounted || !isCurrent()) return; // [OCR 추가]
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message))); // [OCR 추가]
    } catch (_) {
      // [OCR 추가]
      if (!mounted || !isCurrent()) return; // [OCR 추가]
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자동 선택을 완료하지 못했어요. 다시 시도해주세요.')),
      ); // [OCR 추가]
    } finally {
      // [OCR 추가]
      if (mounted && revision == _automaticRevision) {
        // [OCR 수정] 완료로 화면을 닫을 때도 박스를 지운다.
        // [OCR 추가]
        setState(() {
          _automaticReading = false;
          _automaticProgress = '';
          _automaticBounds = null; // [OCR 추가]
          _automaticFieldBounds.clear(); // [OCR 추가]
          _automaticFieldProgress.clear(); // [OCR 추가]
        }); // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]

  void _previous() {
    if (_automatic) {
      // [OCR 추가]
      // [OCR 추가]
      setState(() {
        // [OCR 추가]
        // [OCR 추가]
        if (!_choosingQuantity) {
          // [OCR 추가]
          _choosingQuantity = true; // [OCR 추가]
        } // [OCR 추가]
        else {
          // [OCR 추가]
          _priceIndex = null; // [OCR 추가]
          _choosingQuantity = false; // [OCR 추가]
        } // [OCR 추가]
      }); // [OCR 추가]
      return; // [OCR 추가]
    } // [OCR 추가]
    // [OCR 수정]
    if (widget.editLine != null) {
      // [OCR 수정]
      // [OCR 추가]
      if (_choosingQuantity) {
        // [OCR 수정]
        Navigator.pop(context); // [OCR 수정]
        return; // [OCR 수정]
      } // [OCR 추가]
      setState(() => _choosingQuantity = true); // [OCR 추가]
      return; // [OCR 추가]
    } // [OCR 추가]
    setState(() {
      // [OCR 수정]
      if (_choosingQuantity && _priceIndex == 0) {
        // [OCR 수정]
        _choosingQuantity = false; // [OCR 수정]
        _priceIndex = _selectedIds.length - 1; // [OCR 수정]
        return; // [OCR 수정]
      } // [OCR 수정]
      if (_priceIndex == 0) {
        // [OCR 수정]
        _priceIndex = null; // [OCR 수정]
        return; // [OCR 수정]
      } // [OCR 수정]
      _priceIndex = _priceIndex! - 1; // [OCR 수정]
    }); // [OCR 수정]
  } // [OCR 수정]

  Future<String?> _askValue(
    // [OCR 수정]
    String title, // [OCR 수정]
    String initial, { // [OCR 수정]
    bool name = false, // [OCR 수정]
    bool quantity = false, // [OCR 수정]
  }) async {
    // [OCR 수정]
    // [OCR 수정]
    final controller = TextEditingController(text: initial); // [OCR 수정]
    final formKey = GlobalKey<FormState>(); // [OCR 수정]
    var label = '금액 (원)'; // [OCR 추가]
    if (quantity) label = '수량 (개)'; // [OCR 추가]
    if (name) label = '상품명'; // [OCR 추가] // [OCR 수정]
    final edited = await showDialog<String>(
      // [OCR 수정]
      context: context, // [OCR 수정]
      builder: (dialogContext) => AlertDialog(
        // [OCR 수정]
        // [OCR 수정]
        title: Text(title), // [OCR 수정]
        content: SingleChildScrollView(
          // [OCR 수정]
          child: Form(
            // [OCR 수정]
            key: formKey, // [OCR 수정]
            child: TextFormField(
              // [OCR 수정]
              // [OCR 수정]
              key: const ValueKey('ocr-edit-value'), // [OCR 수정]
              controller: controller, // [OCR 수정]
              autofocus: true, // [OCR 수정]
              keyboardType:
                  name // [OCR 수정]
                  ? TextInputType
                        .text // [OCR 수정]
                  : TextInputType.number, // [OCR 수정]
              decoration: InputDecoration(
                // [OCR 수정]
                labelText: label, // [OCR 수정]
              ), // [OCR 수정]
              validator: (text) {
                // [OCR 수정]
                // [OCR 수정]
                final value = (text ?? '').trim(); // [OCR 수정]
                if (name) {
                  // [OCR 수정]
                  if (value.isEmpty || value.length > 50) {
                    // [OCR 수정]
                    // [OCR 수정]
                    return '상품명은 1~50자로 입력해주세요.'; // [OCR 수정]
                  } // [OCR 추가]
                  return null; // [OCR 수정]
                } // [OCR 수정]
                final number = receiptSelectionAmount(value); // [OCR 수정]
                if (quantity) {
                  // [OCR 수정]
                  if (number == null || number < 1 || number > 999) {
                    // [OCR 수정]
                    // [OCR 수정]
                    return '수량은 1~999개로 입력해주세요.'; // [OCR 수정]
                  } // [OCR 추가]
                  return null; // [OCR 수정]
                } // [OCR 수정]
                if (number == null) {
                  // [OCR 수정]
                  // [OCR 수정]
                  return '0~9,999,999원의 정수로 입력해주세요.'; // [OCR 수정]
                } // [OCR 추가]
                return null; // [OCR 수정]
              }, // [OCR 수정]
            ), // [OCR 수정]
          ), // [OCR 수정]
        ), // [OCR 수정]
        actions: [
          // [OCR 수정]
          TextButton(
            // [OCR 수정]
            onPressed: () => Navigator.pop(dialogContext), // [OCR 수정]
            child: const Text('취소'), // [OCR 수정]
          ), // [OCR 수정]
          FilledButton(
            // [OCR 수정]
            onPressed: () {
              // [OCR 수정]
              if (formKey.currentState!.validate()) {
                // [OCR 수정]
                // [OCR 수정]
                Navigator.pop(
                  // [OCR 수정]
                  dialogContext, // [OCR 수정]
                  controller.text.trim(), // [OCR 수정]
                ); // [OCR 수정]
              } // [OCR 추가]
            }, // [OCR 수정]
            child: const Text('적용'), // [OCR 수정]
          ), // [OCR 수정]
        ], // [OCR 수정]
      ), // [OCR 수정]
    ); // [OCR 수정]
    // [OCR 수정] 이유: 대화상자의 종료 애니메이션 동안 입력 컨트롤러를 유지한다.
    WidgetsBinding.instance.addPostFrameCallback(
      // [OCR 수정]
      (_) => controller.dispose(), // [OCR 수정]
    ); // [OCR 수정]
    return edited; // [OCR 수정]
  } // [OCR 수정]

  Future<void> _edit(ReceiptOcrCandidate candidate) async {
    // [OCR 수정]
    // [OCR 수정]
    final name = _choosingNames; // [OCR 수정]
    final quantity = _choosingQuantity; // [OCR 수정]
    final id = name ? null : _selectedIds[_priceIndex!]; // [OCR 수정]
    var title = '금액 수정'; // [OCR 수정]
    if (name) title = '상품명 수정'; // [OCR 수정]
    if (quantity) title = '수량 수정'; // [OCR 수정]
    final edited = await _askValue(
      // [OCR 수정]
      title, // [OCR 수정]
      // [OCR 수정] 이유: 숫자 후보 수정창은 이미 검증한 값으로 시작해 원·통화 기호 때문에 그대로 적용이 실패하지 않게 한다.
      name // [OCR 수정]
          ? candidate
                .text // [OCR 수정]
          : NumberFormat.decimalPattern(
              // [OCR 수정]
              'ko_KR', // [OCR 수정]
            ).format(candidate.number!), // [OCR 수정]
      name: name, // [OCR 수정]
      quantity: quantity, // [OCR 수정]
    ); // [OCR 수정]
    if (!mounted || edited == null) return; // [OCR 수정]
    setState(() {
      // [OCR 수정]
      // [OCR 수정]
      List<ReceiptOcrCandidate> candidates; // [OCR 수정]
      if (name) {
        // [OCR 수정]
        candidates = _products; // [OCR 수정]
      } // [OCR 수정]
      else if (quantity) {
        // [OCR 수정]
        candidates = _quantitiesByProduct[id]!; // [OCR 수정]
      } // [OCR 수정]
      else {
        // [OCR 수정]
        candidates = _pricesByProduct[id]!; // [OCR 수정]
      } // [OCR 수정]
      final index = candidates.indexWhere(
        // [OCR 수정]
        (item) => item.id == candidate.id, // [OCR 수정]
      ); // [OCR 수정]
      final updated = ReceiptOcrCandidate(
        // [OCR 수정]
        // [OCR 수정]
        id: candidate.id, // [OCR 수정]
        text: edited, // [OCR 수정]
        bounds: candidate.bounds, // [OCR 수정]
        number: name ? null : receiptSelectionAmount(edited), // [OCR 수정]
      ); // [OCR 수정]
      // [OCR 추가] 원문 박스 수정은 적용한 경우에만 후보에 추가한다. 취소하면 원본 표시를 유지한다.
      if (quantity && _quantitySearchAreas.contains(candidate)) {
        // [OCR 추가]
        _quantitySearchAreas.add(updated); // [OCR 추가]
      } // [OCR 추가]
      if (index < 0 && name) {
        // [OCR 추가]
        candidates.add(updated); // [OCR 추가]
      } else {
        // [OCR 추가]
        candidates[index] = updated; // [OCR 추가]
      } // [OCR 추가]
    }); // [OCR 수정]
  } // [OCR 수정]

  Future<void> _directInput() async {
    // [OCR 수정]
    // [OCR 수정]
    final quantity = _choosingQuantity; // [OCR 수정]
    final id = _selectedIds[_priceIndex!]; // [OCR 수정]
    final current = quantity ? _quantityFor(id) : _amountFor(id); // [OCR 수정]
    final edited = await _askValue(
      // [OCR 수정]
      quantity ? '수량 직접 입력' : '금액 직접 입력', // [OCR 수정]
      current?.toString() ?? '', // [OCR 수정]
      quantity: quantity, // [OCR 수정]
    ); // [OCR 수정]
    if (!mounted || edited == null) return; // [OCR 수정]
    setState(() {
      // [OCR 수정]
      // [OCR 수정]
      if (quantity) {
        // [OCR 수정]
        _directQuantities[id] = receiptSelectionAmount(edited)!; // [OCR 수정]
        _selectedQuantities.remove(id); // [OCR 수정]
      } // [OCR 수정]
      else {
        // [OCR 수정]
        _changedDirectAmounts.add(id); // [OCR 추가]
        _directPrices[id] = receiptSelectionAmount(edited)!; // [OCR 수정]
        _selectedPrices.remove(id); // [OCR 수정]
      } // [OCR 수정]
    }); // [OCR 수정]
  } // [OCR 수정]

  ReceiptOcrCandidate? _selectedCandidate(String id, {bool quantity = false}) {
    // [OCR 추가]
    // [OCR 추가]
    final selected =
        quantity // [OCR 추가]
        ? _selectedQuantities[id] // [OCR 추가]
        : _selectedPrices[id]; // [OCR 추가]
    if (selected == null) return null; // [OCR 추가]
    final candidates =
        quantity // [OCR 추가]
        ? _quantitiesByProduct[id]! // [OCR 추가]
        : _pricesByProduct[id]!; // [OCR 추가]
    final candidate = candidates.firstWhere(
      (candidate) => candidate.id == selected,
    ); // [OCR 수정]
    if (!quantity || !_directQuantities.containsKey(id)) {
      // [OCR 수정]
      return candidate; // [OCR 추가]
    } // [OCR 수정]
    // [OCR 추가] 화살표로 고친 수량은 선택한 사진 좌표를 유지해 자동 행 연결에 사용한다.
    return ReceiptOcrCandidate(
      // [OCR 추가]
      id: candidate.id, // [OCR 추가]
      text: '${_directQuantities[id]}', // [OCR 추가]
      bounds: candidate.bounds, // [OCR 추가]
      number: _directQuantities[id], // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  Future<void> _regionInput({bool editName = false}) async {
    // [OCR 추가]
    // [OCR 추가]
    final names = _choosingNames; // [OCR 추가]
    final quantity = _choosingQuantity; // [OCR 추가]
    final id =
        names // [OCR 추가]
        ? (editName ? _selectedIds.last : null) // [OCR 추가]
        : _selectedIds[_priceIndex!]; // [OCR 추가]
    ReceiptOcrCandidate? candidate; // [OCR 추가]
    if (names && id != null) candidate = _product(id); // [OCR 추가]
    if (!names) {
      // [OCR 추가]
      candidate = // [OCR 추가]
          _selectedCandidate(id!, quantity: quantity) ?? // [OCR 추가]
          (quantity // [OCR 추가]
              ? widget
                    .editLine
                    ?.ocrQuantity // [OCR 추가]
              : widget.editLine?.ocrAmount); // [OCR 추가]
    } // [OCR 추가]
    final label =
        names // [OCR 추가]
        ? '상품명' // [OCR 추가]
        : quantity // [OCR 추가]
        ? '수량' // [OCR 추가]
        : '금액'; // [OCR 추가]
    final current =
        names // [OCR 추가]
        ? candidate
              ?.text // [OCR 추가]
        : quantity // [OCR 추가]
        ? _quantityFor(id!)
              .toString() // [OCR 추가]
        : _amountFor(id!)?.toString(); // [OCR 추가]
    final value = await Navigator.push<ReceiptRegionValue>(
      // [OCR 추가]
      context, // [OCR 추가]
      MaterialPageRoute(
        // [OCR 추가]
        builder: (_) => ReceiptRegionScreen(
          // [OCR 추가]
          // [OCR 추가]
          photoPath: _source.photoPath, // [OCR 추가]
          photoBytes: _source.photoBytes, // [OCR 추가]
          label: label, // [OCR 추가]
          numeric: !names, // [OCR 추가]
          quantity: quantity, // [OCR 추가]
          initialBounds: candidate?.bounds, // [OCR 추가]
          initialText: current ?? '', // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    if (!mounted || value == null) return; // [OCR 추가]
    final updated = ReceiptOcrCandidate(
      // [OCR 추가]
      id:
          candidate?.id ??
          'region-${DateTime.now().microsecondsSinceEpoch}', // [OCR 추가]
      text: value.text, // [OCR 추가]
      bounds: value.bounds, // [OCR 추가]
      number: names ? null : receiptSelectionAmount(value.text), // [OCR 추가]
    ); // [OCR 추가]
    setState(() {
      // [OCR 추가]
      // [OCR 추가]
      if (names) {
        // [OCR 추가]
        // [OCR 추가]
        if (candidate == null) {
          // [OCR 추가]
          _products.add(updated); // [OCR 추가]
          if (_automatic) _selectedIds.clear(); // [OCR 추가]
          _selectedIds.add(updated.id); // [OCR 추가]
          if (_automatic) _prepareAutomaticSeed(updated); // [OCR 추가]
        } // [OCR 추가]
        else {
          // [OCR 추가]
          _products[_products.indexWhere(
                (item) => item.id == candidate!.id,
              )] = // [OCR 추가]
              updated; // [OCR 추가]
        } // [OCR 추가]
        return; // [OCR 추가]
      } // [OCR 추가]
      final candidates =
          quantity // [OCR 추가]
          ? _quantitiesByProduct[id]! // [OCR 추가]
          : _pricesByProduct[id]!; // [OCR 추가]
      final index = candidates.indexWhere(
        // [OCR 추가]
        (item) => item.id == updated.id, // [OCR 추가]
      ); // [OCR 추가]
      if (index < 0) {
        // [OCR 추가]
        candidates.add(updated); // [OCR 추가]
      } else {
        // [OCR 추가]
        candidates[index] = updated; // [OCR 추가]
      } // [OCR 추가]
      if (quantity) {
        // [OCR 추가]
        // [OCR 추가] 직접 지정·수정한 영역은 확인한 크기 그대로 사용하며 표시 여백을 다시 더하지 않는다.
        _quantitySearchAreas.add(updated); // [OCR 추가]
        _selectedQuantities[id!] = updated.id; // [OCR 추가]
        _directQuantities.remove(id); // [OCR 추가]
        if (_automatic) {
          _choosingQuantity =
              false; // [OCR 수정] 영역으로 확정한 수량도 후보 선택과 같이 금액 단계로 진행한다.
        } // [OCR 수정]
      } // [OCR 추가]
      else {
        // [OCR 추가]
        _selectedPrices[id!] = updated.id; // [OCR 추가]
        _directPrices.remove(id); // [OCR 추가]
        _changedDirectAmounts.remove(id); // [OCR 추가]
      } // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  String get _actionLabel {
    if (_automatic) return '끝까지 자동 선택'; // [OCR 수정]
    // [OCR 수정]
    if (_choosingNames) {
      // [OCR 수정]
      return '상품명 선택 완료 (${_selectedIds.length}개)'; // [OCR 수정]
    } // [OCR 수정]
    if (widget.editLine != null) {
      // [OCR 수정]
      // [OCR 추가]
      return _choosingQuantity ? '금액 선택으로' : '수정 적용'; // [OCR 추가]
    } // [OCR 추가]
    final last = _priceIndex == _selectedIds.length - 1; // [OCR 수정]
    if (!_choosingQuantity) return last ? '수량 확인' : '다음 상품 금액'; // [OCR 수정]
    if (last && widget.pageNumber != null) {
      // [OCR 추가]
      return widget.pageNumber! <
              widget.pageCount! // [OCR 추가]
          ? '다음 장 선택' // [OCR 추가]
          : '모든 항목 검토'; // [OCR 추가]
    }
    return last ? '선택한 항목 검토' : '다음 상품 수량'; // [OCR 수정]
  } // [OCR 수정]

  String get _heading {
    // [OCR 수정]
    // [OCR 수정]
    if (_choosingNames) {
      // [OCR 수정]
      if (_automatic) return '첫 상품명·수량·금액 선택'; // [OCR 수정]
      return '상품명 전체 수동 선택'; // [OCR 수정]
    } // [OCR 수정]
    final product = _product(_selectedIds[_priceIndex!]); // [OCR 수정]
    final kind = _choosingQuantity ? '수량 선택' : '금액 선택'; // [OCR 수정]
    return '${_priceIndex! + 1}/${_selectedIds.length} · ${product.text} $kind'; // [OCR 수정]
  } // [OCR 수정]

  String _candidateLabel(ReceiptOcrCandidate candidate) {
    // [OCR 수정]
    // [OCR 수정]
    if (_choosingNames) return candidate.text; // [OCR 수정]
    if (_choosingQuantity) return '${candidate.number}개'; // [OCR 수정]
    return '${NumberFormat.decimalPattern('ko_KR').format(candidate.number)}원'; // [OCR 수정]
  } // [OCR 수정]

  Widget _amountModeChoices() => SwitchListTile(
    // [OCR 수정]
    key: const ValueKey('ocr-unit-price-toggle'), // [OCR 추가]
    contentPadding: EdgeInsets.zero, // [OCR 수정]
    title: const Text('단가로 입력하기'), // [OCR 수정]
    value: _isUnitPrice, // [OCR 수정]
    onChanged: (value) => setState(() => _isUnitPrice = value), // [OCR 수정]
  ); // [OCR 수정]

  Widget _selectionModeButton(String label, bool automatic) {
    // [OCR 추가]
    final selected = _automatic == automatic; // [OCR 추가]
    return Expanded(
      // [OCR 추가]
      child: OutlinedButton(
        // [OCR 추가]
        key: ValueKey(
          automatic ? 'ocr-automatic-names' : 'ocr-manual-names',
        ), // [OCR 추가]
        style: OutlinedButton.styleFrom(
          // [OCR 추가]
          minimumSize: const Size(0, 48), // [OCR 추가]
          padding: const EdgeInsets.symmetric(horizontal: 8), // [OCR 추가]
          backgroundColor: selected
              ? AppColors.primary
              : AppColors.surface, // [OCR 추가]
          foregroundColor: selected ? Colors.white : null, // [OCR 추가]
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ), // [OCR 추가]
        ), // [OCR 추가]
        // [OCR 추가] 수동으로 고른 여러 상품을 자동 기준 하나로 조용히 축소하지 않는다.
        onPressed:
            automatic &&
                _selectedIds.length >
                    1 // [OCR 추가]
            ? null // [OCR 추가]
            : () => setState(() {
                // [OCR 수정]
                _automatic = automatic; // [OCR 수정]
                _priceIndex = null; // [OCR 추가] 수동 전환 시 여러 이름부터 선택한다.
                _choosingQuantity = false; // [OCR 추가]
                if (automatic && _selectedIds.isNotEmpty) {
                  // [OCR 추가]
                  _prepareAutomaticSeed(
                    _product(_selectedIds.single),
                  ); // [OCR 추가]
                } // [OCR 추가]
              }), // [OCR 수정]
        child: Text(label), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  Widget _automaticControls() => Column(
    // [OCR 수정]
    children: [
      // [OCR 수정]
      // [OCR 추가] 같은 폭의 두 선택 버튼과 간격을 합쳐 단가 버튼 전체 폭에 맞춘다.
      Row(
        // [OCR 추가]
        children: [
          // [OCR 추가]
          _selectionModeButton('상품 수동 선택', false), // [OCR 추가]
          const SizedBox(width: 8), // [OCR 추가]
          _selectionModeButton('자동 선택', true), // [OCR 추가]
        ], // [OCR 추가]
      ), // [OCR 추가]
      const SizedBox(height: 8), // [OCR 추가]
      _amountModeChoices(), // [OCR 수정]
    ], // [OCR 수정]
  ); // [OCR 수정]

  String _seedFieldLabel(String field, String? id) {
    // [OCR 추가]
    if (id == null) return field == '수량' ? '수량\n1' : field; // [OCR 추가]
    if (field == '상품명') return '$field\n${_product(id).text}'; // [OCR 추가]
    if (field == '수량') return '$field\n${_quantityFor(id)}'; // [OCR 추가]
    return '$field\n${_amountFor(id) ?? '—'}'; // [OCR 추가]
  } // [OCR 추가]

  Widget _automaticSeedFields() {
    // [OCR 추가]
    final id = _selectedIds.isEmpty ? null : _selectedIds.single; // [OCR 추가]
    return Row(
      // [OCR 추가]
      children: [
        // [OCR 추가]
        for (final field in [
          '상품명',
          '수량',
          _isUnitPrice ? '단가' : '금액',
        ]) // [OCR 추가]
          Expanded(
            // [OCR 추가]
            child: Padding(
              // [OCR 추가]
              padding: const EdgeInsets.symmetric(horizontal: 2), // [OCR 추가]
              child: OutlinedButton(
                // [OCR 추가]
                key: ValueKey(
                  'ocr-seed-${field == '단가' ? '금액' : field}',
                ), // [OCR 추가]
                onPressed: field != '상품명' && id == null
                    ? null
                    : () => setState(() {
                        // [OCR 추가]
                        _priceIndex = field == '상품명' ? null : 0; // [OCR 추가]
                        _choosingQuantity = field == '수량'; // [OCR 추가]
                      }), // [OCR 추가]
                child: Text(
                  _seedFieldLabel(field, id), // [OCR 추가]
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ), // [OCR 추가]
              ), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
      ], // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  void _changeQuantity(String id, int change) {
    // [OCR 추가]
    final value = _quantityFor(id) + change; // [OCR 추가]
    if (value < 1 || value > 999) return; // [OCR 추가]
    setState(() => _directQuantities[id] = value); // [OCR 추가]
  } // [OCR 추가]

  Widget _quantityArrows() {
    // [OCR 추가]
    final id = _selectedIds.isEmpty
        ? null
        : _selectedIds[_priceIndex ?? 0]; // [OCR 추가]
    final value = id == null ? 1 : _quantityFor(id); // [OCR 추가]
    // [OCR 수정] 터치 범위와 버튼 경계를 항상 보여주고 제한 수량에서는 색으로 비활성 상태를 구분한다.
    final arrowStyle = IconButton.styleFrom(
      // [OCR 추가]
      backgroundColor: AppColors.secondary, // [OCR 추가]
      foregroundColor: AppColors.primary, // [OCR 추가]
      disabledBackgroundColor: AppColors.surface, // [OCR 추가]
      disabledForegroundColor: AppColors.muted, // [OCR 추가]
      minimumSize: const Size(48, 48), // [OCR 추가]
      side: const BorderSide(color: AppColors.border), // [OCR 추가]
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ), // [OCR 추가]
    ); // [OCR 추가]
    return Row(
      // [OCR 추가]
      mainAxisAlignment: MainAxisAlignment.center, // [OCR 추가]
      children: [
        // [OCR 추가]
        IconButton(
          // [OCR 추가]
          key: const ValueKey('ocr-quantity-down'), // [OCR 추가]
          style: arrowStyle, // [OCR 추가]
          tooltip: '수량 줄이기', // [OCR 추가]
          onPressed: id == null || value <= 1
              ? null
              : () => _changeQuantity(id, -1), // [OCR 추가]
          icon: const Icon(Icons.arrow_downward), // [OCR 추가]
        ), // [OCR 추가]
        Padding(
          // [OCR 수정]
          padding: const EdgeInsets.symmetric(horizontal: 20), // [OCR 추가]
          child: Text(
            '$value개',
            key: const ValueKey('ocr-quantity-value'),
          ), // [OCR 수정]
        ), // [OCR 추가]
        IconButton(
          // [OCR 추가]
          key: const ValueKey('ocr-quantity-up'), // [OCR 추가]
          style: arrowStyle, // [OCR 추가]
          tooltip: '수량 늘리기', // [OCR 추가]
          onPressed: id == null || value >= 999
              ? null
              : () => _changeQuantity(id, 1), // [OCR 추가]
          icon: const Icon(Icons.arrow_upward), // [OCR 추가]
        ), // [OCR 추가]
      ], // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  Widget _numberControls() {
    // [OCR 수정]
    // [OCR 수정]
    final id = _selectedIds[_priceIndex!]; // [OCR 수정]
    final current =
        _choosingQuantity // [OCR 수정]
        ? _quantityFor(id) // [OCR 수정]
        : _amountFor(id); // [OCR 수정]
    return Column(
      // [OCR 수정]
      crossAxisAlignment: CrossAxisAlignment.start, // [OCR 수정]
      children: [
        // [OCR 수정]
        // [OCR 수정]
        if (!_automatic && _priceIndex == 0 && !_choosingQuantity) // [OCR 추가]
          _amountModeChoices(), // [OCR 수정]
        if (current != null) // [OCR 수정]
          Text(
            // [OCR 수정]
            _choosingQuantity // [OCR 수정]
                ? '선택한 수량: $current개' // [OCR 수정]
                : '선택한 금액: ${NumberFormat.decimalPattern('ko_KR').format(current)}원', // [OCR 수정]
          ), // [OCR 수정]
        TextButton(
          // [OCR 수정]
          onPressed: _directInput, // [OCR 수정]
          child: Text(_choosingQuantity ? '수량 직접 입력' : '금액 직접 입력'), // [OCR 수정]
        ), // [OCR 수정]
      ], // [OCR 수정]
    ); // [OCR 수정]
  } // [OCR 수정]

  Widget _selectedNamesSummary() {
    // [OCR 수정]
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [OCR 수정]
          Text(
            '선택한 상품명 ${_selectedIds.length}개',
            key: const ValueKey('ocr-selected-name-count'),
            style: Theme.of(context).textTheme.titleMedium,
          ), // [OCR 수정]
          if (_selectedIds.isNotEmpty)
            SizedBox(
              height: 48,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // [OCR 수정]
                    for (final id in _selectedIds)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(_product(id).text),
                          onDeleted: () => _select(_product(id)),
                        ),
                      ), // [OCR 수정]
                  ],
                ),
              ),
            ), // [OCR 수정]
        ],
      ),
    ); // [OCR 수정]
  } // [OCR 수정]

  // [OCR 추가] 확대 배율은 유지하고 현재 영역이 화면 밖일 때만 사진을 이동한다. 읽는 원본 좌표는 변경하지 않는다.
  void _followAutomaticBounds(Rect bounds) {
    // [OCR 추가]
    final viewport = _photoViewport.currentContext
        ?.findRenderObject(); // [OCR 추가]
    if (viewport is! RenderBox || !viewport.hasSize || _photoSize == null) {
      // [OCR 추가]
      return; // [OCR 추가]
    } // [OCR 추가]
    final fitScale = viewport.size.width / _photoSize!.width; // [OCR 추가]
    final rect = Rect.fromLTRB(
      bounds.left * fitScale,
      bounds.top * fitScale, // [OCR 추가]
      bounds.right * fitScale,
      bounds.bottom * fitScale,
    ); // [OCR 추가]
    final shown = MatrixUtils.transformRect(_transform.value, rect); // [OCR 추가]
    var dx = 0.0; // [OCR 추가]
    var dy = 0.0; // [OCR 추가]
    if (shown.left < 12 || shown.right > viewport.size.width - 12) {
      // [OCR 추가]
      dx = viewport.size.width / 2 - shown.center.dx; // [OCR 추가]
    } // [OCR 추가]
    if (shown.top < 12 || shown.bottom > viewport.size.height - 12) {
      // [OCR 추가]
      dy = viewport.size.height / 2 - shown.center.dy; // [OCR 추가]
    } // [OCR 추가]
    if (dx == 0 && dy == 0) return; // [OCR 추가]
    final matrix = _transform.value.clone(); // [OCR 추가]
    final zoom = matrix.getMaxScaleOnAxis(); // [OCR 추가]
    matrix.storage[12] = (matrix.storage[12] + dx).clamp(
      // [OCR 추가]
      -math.max(0.0, _photoSize!.width * fitScale * zoom - viewport.size.width),
      0.0,
    ); // [OCR 추가]
    matrix.storage[13] = (matrix.storage[13] + dy).clamp(
      // [OCR 추가]
      -math.max(
        0.0,
        _photoSize!.height * fitScale * zoom - viewport.size.height,
      ),
      0.0,
    ); // [OCR 추가]
    _transform.value = matrix; // [OCR 추가]
  } // [OCR 추가]

  // [OCR 추가] 원문 표시와 수량 검색이 같은 여백을 사용한다. 확정한 수량 영역에는 중복 적용하지 않는다.
  Rect _candidatePhotoBounds(ReceiptOcrCandidate candidate, double scale) {
    // [OCR 추가]
    if (candidate.text.trim().runes.length != 1 ||
        _quantitySearchAreas.contains(candidate)) {
      // [OCR 추가]
      return candidate.bounds; // [OCR 추가]
    } // [OCR 추가]
    return candidate.bounds
        .inflate(4 / scale)
        .intersect(
          // [OCR 추가]
          Offset.zero & _photoSize!, // [OCR 추가]
        ); // [OCR 추가]
  } // [OCR 추가]

  ReceiptOcrCandidate _quantityWithSearchArea(ReceiptOcrCandidate candidate) {
    // [OCR 추가]
    final viewport = _photoViewport.currentContext
        ?.findRenderObject(); // [OCR 추가]
    if (_photoSize == null || viewport is! RenderBox || !viewport.hasSize) {
      // [OCR 추가]
      return candidate; // [OCR 추가]
    } // [OCR 추가]
    final bounds = _candidatePhotoBounds(
      candidate,
      viewport.size.width / _photoSize!.width,
    ); // [OCR 추가]
    if (bounds == candidate.bounds) return candidate; // [OCR 추가]
    final quantity = ReceiptOcrCandidate(
      // [OCR 추가]
      id: candidate.id,
      text: candidate.text,
      number: candidate.number, // [OCR 추가]
      bounds: bounds,
      isMergedName: candidate.isMergedName, // [OCR 추가]
    ); // [OCR 추가]
    _quantitySearchAreas.add(quantity); // [OCR 추가]
    return quantity; // [OCR 추가]
  } // [OCR 추가]

  Widget _photoCandidateBox(ReceiptOcrCandidate candidate, double scale) {
    // [OCR 수정]
    final photoBounds = _candidatePhotoBounds(candidate, scale); // [OCR 추가]
    final bounds = Rect.fromLTRB(
      // [OCR 수정]
      photoBounds.left * scale,
      photoBounds.top * scale, // [OCR 수정]
      photoBounds.right * scale,
      photoBounds.bottom * scale, // [OCR 수정]
    ); // [OCR 수정]
    return Positioned(
      // [OCR 추가]
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height, // [OCR 추가]
      child: Semantics(
        // [OCR 추가]
        label: candidate.text,
        button: true,
        selected: _isSelected(candidate), // [OCR 추가]
        child: GestureDetector(
          // [OCR 추가]
          key: ValueKey('ocr-box-${candidate.id}'), // [OCR 추가]
          behavior: HitTestBehavior.opaque, // [OCR 추가]
          onTap: () => _select(candidate),
          onLongPress: () => _edit(candidate), // [OCR 추가]
          child: DecoratedBox(
            // [OCR 추가]
            decoration: BoxDecoration(
              // [OCR 추가]
              border: Border.all(
                // [OCR 추가]
                color: _isSelected(candidate)
                    ? AppColors.primary
                    : AppColors.muted, // [OCR 추가]
                width: 1, // [OCR 추가]
              ), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  Widget _photo() {
    // [OCR 추가]
    if (_photoBytes == null) {
      // [OCR 추가]
      return Center(
        // [OCR 추가]
        child: Text(
          // [OCR 추가]
          _photoError.isEmpty ? '사진을 준비하고 있어요.' : _photoError, // [OCR 추가]
          textAlign: TextAlign.center, // [OCR 추가]
        ), // [OCR 추가]
      ); // [OCR 추가]
    } // [OCR 추가]
    return LayoutBuilder(
      // [OCR 추가]
      builder: (context, constraints) {
        // [OCR 추가]
        final size = _photoSize!; // [OCR 추가]
        // [OCR 수정] fresh처럼 가로폭에 맞춘다. 긴 영수증을 전체 축소하면 기본 배율에서 이동할 여지가 없어진다.
        final scale = constraints.maxWidth / size.width; // [OCR 수정]
        return Listener(
          // [OCR 추가]
          key: _photoViewport, // [OCR 추가]
          // [OCR 추가]
          behavior: HitTestBehavior.opaque, // [OCR 추가]
          onPointerDown:
              (event) => // [OCR 추가]
                  _trackPhotoPointer(event.pointer, true), // [OCR 추가]
          onPointerUp:
              (event) => // [OCR 추가]
                  _trackPhotoPointer(event.pointer, false), // [OCR 추가]
          onPointerCancel:
              (event) => // [OCR 추가]
                  _trackPhotoPointer(event.pointer, false), // [OCR 추가]
          onPointerPanZoomStart:
              (event) => // [OCR 추가]
                  _trackPhotoPointer(event.pointer, true), // [OCR 추가]
          onPointerPanZoomEnd:
              (event) => // [OCR 추가]
                  _trackPhotoPointer(event.pointer, false), // [OCR 추가]
          // [OCR 추가] fresh와 같이 사진의 휠 이벤트를 목록이 다시 처리하지 않게 소비한다.
          onPointerSignal: (event) =>
              GestureBinding // [OCR 추가]
                  .instance // [OCR 추가]
                  .pointerSignalResolver // [OCR 추가]
                  .register(event, (_) {}), // [OCR 추가]
          child: InteractiveViewer(
            // [OCR 추가]
            // [OCR 추가]
            transformationController: _transform, // [OCR 추가]
            constrained: false, // [OCR 수정]
            alignment: Alignment.topLeft, // [OCR 수정]
            minScale: 1, // [OCR 수정]
            maxScale: 6, // [OCR 수정]
            // [OCR 추가]
            child: SizedBox(
              // [OCR 추가]
              // [OCR 추가]
              width: size.width * scale, // [OCR 추가]
              height: size.height * scale, // [OCR 추가]
              child: Stack(
                // [OCR 추가]
                // [OCR 추가]
                children: [
                  // [OCR 추가]
                  // [OCR 추가]
                  Positioned.fill(
                    // [OCR 추가]
                    // [OCR 추가]
                    child: Image.memory(
                      // [OCR 추가]
                      _photoBytes!, // [OCR 추가]
                      fit: BoxFit.fill, // [OCR 추가]
                    ), // [OCR 추가]
                  ), // [OCR 추가]
                  for (final candidate in _photoCandidates) // [OCR 수정]
                    _photoCandidateBox(candidate, scale), // [OCR 수정]
                  if (_automaticReading)
                    for (final entry in {
                      'current': ?_automaticBounds,
                      ..._automaticFieldBounds,
                    }.entries)
                      Positioned(
                        key: ValueKey(
                          entry.key == 'current'
                              ? 'ocr-automatic-reading-box'
                              : 'ocr-automatic-reading-box-${entry.key}',
                        ),
                        left: entry.value.left * scale,
                        top: entry.value.top * scale,
                        width: entry.value.width * scale,
                        height: entry.value.height * scale,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.blueAccent,
                                width: 2,
                              ),
                              color: Colors.blueAccent.withValues(alpha: .10),
                            ),
                          ),
                        ),
                      ), // [OCR 수정] 상품명/열 탐색은 한 박스, 수량·금액은 각각 동시에 표시한다.
                ], // [OCR 추가]
              ), // [OCR 추가]
            ), // [OCR 수정]
          ), // [OCR 추가]
        ); // [OCR 추가]
      }, // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  @override // [OCR 추가]
  Widget build(BuildContext context) {
    // [OCR 추가]
    final candidates = _visibleCandidates; // [OCR 추가]
    final hasSelection = _canContinue; // [OCR 수정]
    final heading = _heading; // [OCR 수정]
    return Scaffold(
      // [OCR 추가]
      appBar: AppBar(
        // [OCR 추가]
        leading: const DesignBackButton(), // [OCR 추가]
        leadingWidth: 68, // [OCR 추가]
        titleSpacing: 8, // [OCR 추가]
        title: Text(
          // [OCR 추가]
          widget.pageNumber ==
                  null // [OCR 추가]
              ? '영수증 항목 선택' // [OCR 추가]
              : '영수증 항목 선택 (${widget.pageNumber}/${widget.pageCount}장)', // [OCR 추가]
        ), // [OCR 수정]
        actions: [
          // [OCR 추가]
          if (widget.pageNumber != null) // [OCR 추가]
            TextButton(
              // [OCR 추가]
              onPressed: _automaticReading
                  ? null
                  : () => _returnLines([]), // [OCR 추가]
              child: const Text('이 장 건너뛰기'), // [OCR 추가]
            ), // [OCR 추가]
        ], // [OCR 추가]
      ), // [OCR 추가]
      bottomNavigationBar: BottomAction(
        // [OCR 추가]
        label: _automaticReading ? '자동 선택 중…' : _actionLabel, // [OCR 수정]
        onPressed: hasSelection && !_automaticReading
            ? _next
            : null, // [OCR 추가]
      ), // [OCR 추가]
      body: AbsorbPointer(
        // [OCR 추가] 반복 인식 중에는 기준을 바꾸지 않고 뒤로 가기로 취소한다.
        absorbing: _automaticReading, // [OCR 추가]
        child: SafeArea(
          // [OCR 추가]
          child: Center(
            // [OCR 추가]
            child: ConstrainedBox(
              // [OCR 추가]
              constraints: const BoxConstraints(maxWidth: 640), // [OCR 추가]
              child: Column(
                // [OCR 추가]
                children: [
                  // [OCR 추가]
                  SizedBox(
                    // [OCR 추가]
                    height: math.min(
                      // [OCR 추가]
                      280, // [OCR 추가]
                      MediaQuery.sizeOf(context).height * .32, // [OCR 추가]
                    ), // [OCR 추가]
                    child: _photo(), // [OCR 추가]
                  ), // [OCR 추가]
                  if (_automaticReading) ...[
                    // [OCR 추가]
                    const LinearProgressIndicator(minHeight: 2), // [OCR 추가]
                    Padding(
                      // [OCR 추가]
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ), // [OCR 추가]
                      child: Text(
                        [
                          _automaticProgress,
                          ..._automaticFieldProgress.values,
                        ].join('\n'), // [OCR 수정]
                        key: const ValueKey('ocr-automatic-progress'),
                      ), // [OCR 수정]
                    ), // [OCR 추가]
                  ], // [OCR 추가]
                  if (_choosingNames && !_automatic)
                    _selectedNamesSummary(), // [OCR 수정]
                  Expanded(
                    // [OCR 추가]
                    child: ListView(
                      // [OCR 수정]
                      controller: _scroll, // [OCR 추가]
                      physics:
                          _photoPointers
                              .isEmpty // [OCR 추가]
                          ? null // [OCR 추가]
                          : const NeverScrollableScrollPhysics(), // [OCR 추가]
                      // [OCR 수정] 이름 선택 중에는 스크롤을 유지하고, 다음 입력 단계는 목록 위에서 시작한다.
                      key: ValueKey(
                        'ocr-candidate-list-${_priceIndex ?? 'names'}-$_choosingQuantity',
                      ), // [OCR 수정]
                      padding: const EdgeInsets.all(20), // [OCR 추가]
                      children: [
                        // [OCR 수정] 후보가 많아도 첫 화면에서 자동 입력을 찾도록 선택 옵션을 목록 앞에 둔다.
                        if ((_automatic || _choosingNames) &&
                            widget.editLine == null) // [OCR 수정]
                          _automaticControls(), // [OCR 수정]
                        Text(
                          // [OCR 추가]
                          _automatic
                              ? '첫 상품명·수량·${_isUnitPrice ? '단가' : '금액'} 선택'
                              : heading, // [OCR 수정]
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall, // [OCR 추가]
                        ), // [OCR 추가]
                        const SizedBox(height: 8), // [OCR 추가]
                        if (_automatic) _automaticSeedFields(), // [OCR 추가]
                        if (_automatic || _choosingQuantity)
                          _quantityArrows(), // [OCR 추가]
                        if (!_choosingNames) _numberControls(), // [OCR 수정]
                        if (!_choosingNames && !_automatic) // [OCR 수정]
                          TextButton(
                            // [OCR 추가]
                            onPressed: _previous, // [OCR 추가]
                            child: const Text('이전 선택'), // [OCR 추가]
                          ), // [OCR 추가]
                        const SizedBox(height: 16), // [OCR 추가]
                        Wrap(
                          // [OCR 추가]
                          spacing: 8, // [OCR 추가]
                          runSpacing: 8, // [OCR 추가]
                          children: [
                            // [OCR 추가]
                            for (final candidate in candidates) // [OCR 추가]
                              GestureDetector(
                                // [OCR 추가]
                                onLongPress: () => _edit(candidate), // [OCR 추가]
                                child: OutlinedButton(
                                  // [OCR 추가]
                                  key: ValueKey(
                                    // [OCR 추가]
                                    'ocr-candidate-${candidate.id}', // [OCR 추가]
                                  ), // [OCR 추가]
                                  style: OutlinedButton.styleFrom(
                                    // [OCR 추가]
                                    backgroundColor:
                                        _isSelected(candidate) // [OCR 추가]
                                        ? AppColors
                                              .secondary // [OCR 추가]
                                        : AppColors.surface, // [OCR 추가]
                                    side: BorderSide(
                                      // [OCR 추가]
                                      color:
                                          _isSelected(candidate) // [OCR 추가]
                                          ? AppColors
                                                .primary // [OCR 추가]
                                          : AppColors.border, // [OCR 추가]
                                    ), // [OCR 추가]
                                  ), // [OCR 추가]
                                  onPressed: () =>
                                      _select(candidate), // [OCR 추가]
                                  child: Text(
                                    // [OCR 추가]
                                    _candidateLabel(candidate), // [OCR 수정]
                                  ), // [OCR 추가]
                                ), // [OCR 추가]
                              ), // [OCR 추가]
                          ], // [OCR 추가]
                        ), // [OCR 추가]
                        TextButton.icon(
                          // [OCR 추가]
                          // [OCR 추가]
                          onPressed: () => _regionInput(), // [OCR 추가]
                          icon: const Icon(Icons.crop_free), // [OCR 추가]
                          label: Text(
                            // [OCR 추가]
                            _choosingNames // [OCR 추가]
                                ? '상품명 영역 지정' // [OCR 추가]
                                : _choosingQuantity // [OCR 추가]
                                ? '수량 영역 지정·수정' // [OCR 추가]
                                : '금액 영역 지정·수정', // [OCR 추가]
                          ), // [OCR 추가]
                        ), // [OCR 추가]
                        if (_choosingNames &&
                            _selectedIds.isNotEmpty) // [OCR 추가]
                          TextButton(
                            // [OCR 추가]
                            onPressed: () =>
                                _regionInput(editName: true), // [OCR 추가]
                            child: const Text('선택한 상품명 영역 수정'), // [OCR 추가]
                          ), // [OCR 추가]
                      ], // [OCR 추가]
                    ), // [OCR 추가]
                  ), // [OCR 추가]
                ], // [OCR 추가]
              ), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]
} // [OCR 추가]
