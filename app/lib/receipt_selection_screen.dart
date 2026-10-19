// [OCR 수정] 수동 다중 선택과 첫 상품 기준 자동 선택에서 사진 후보·직접 입력·영역 수정을 처리한다.
import 'receipt_image.dart';
import 'ocr_service.dart';
import 'receipt_automatic.dart';
import 'receipt_column_scan.dart';
import 'receipt_region_screen.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'design_widgets.dart';
import 'models.dart';
import 'receipt_amount.dart';
import 'receipt_ocr.dart';

/// [OCR 추가] OCR 후보를 수동 선택하여 새 검토 초안을 반환한다. 취소는 원본 초안을 변경하지 않는다.
class ReceiptSelectionScreen extends StatefulWidget {
  const ReceiptSelectionScreen({
    super.key,
    required this.draft,
    this.editLine,
    this.pageNumber,
    this.pageCount,
    this.recognizeRegion,
    this.scanRegion,
    this.recognizeQuantity, // [OCR 추가] 병렬 수량 인식도 모의 주입하여 두 필드 표시를 검증한다.
  }); // [OCR 수정]
  final int? pageNumber;
  final int? pageCount;
  final ReceiptLineDraft? editLine;
  final ReceiptDraft draft;
  final Future<String> Function(Uint8List, Rect)? recognizeRegion;
  final Future<String> Function(Uint8List, Rect)? recognizeQuantity;
  final Future<List<ReceiptOcrCandidate>> Function(Uint8List, Rect)? scanRegion;
  @override
  State<ReceiptSelectionScreen> createState() => _ReceiptSelectionScreenState();
}

class _ReceiptSelectionScreenState extends State<ReceiptSelectionScreen> {
  // [OCR 추가] fresh의 접점 추적·목록 정지·사진 변환을 그대로 사용해 사진 조작과 후보 목록 스크롤을 분리한다.
  final _scroll = ScrollController(keepScrollOffset: false);
  final _transform = TransformationController();
  final _photoPointers = <int>{};
  void _trackPhotoPointer(int pointer, bool down) {
    final wasActive = _photoPointers.isNotEmpty;
    if (down) {
      _photoPointers.add(pointer);
    } else {
      _photoPointers.remove(pointer);
    }
    if (wasActive == _photoPointers.isNotEmpty) {
      return;
    }
    if (down && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.offset);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _automaticRevision++;
    _scroll.dispose();
    _transform.dispose();
    super.dispose();
  }

  late List<ReceiptOcrCandidate> _products;
  final _selectedIds = <String>[];
  final _pricesByProduct = <String, List<ReceiptOcrCandidate>>{};
  final _selectedPrices = <String, String>{};
  final _quantitiesByProduct = <String, List<ReceiptOcrCandidate>>{};
  final _selectedQuantities = <String, String>{};
  // [OCR 추가] 후보별 사본만 기록해 같은 원문을 다른 상품에서 골라도 크기 상태를 공유하지 않는다.
  final _quantitySearchAreas = <ReceiptOcrCandidate>{};
  final _changedDirectAmounts = <String>{};
  final _directPrices = <String, int>{};
  final _directQuantities = <String, int>{};
  bool _automatic = true;
  bool _isUnitPrice = false; // [OCR 수정] 기본은 상품 결제금액이며 수량은 두 방식 모두 확인한다.
  bool _choosingQuantity = false;
  bool _finished = false;
  int? _priceIndex;
  Uint8List? _photoBytes;
  Size? _photoSize;
  String _photoError = '';
  late final Future<void> _photoLoading;
  bool _automaticReading = false;
  int _automaticRevision = 0;
  String _automaticProgress = '';
  Rect? _automaticBounds;
  final _automaticFieldBounds = <String, Rect>{};
  final _automaticFieldProgress = <String, String>{};
  final _photoViewport = GlobalKey();
  ReceiptOcrResult? _accumulatedSource;
  ReceiptOcrResult get _source => _accumulatedSource ?? widget.draft.ocrResult!;
  bool get _choosingNames => _priceIndex == null;
  // [OCR 추가] 첫 선택에서는 후보 분류로 원문을 숨기지 않는다. 용도는 사용자가 선택한다.
  List<ReceiptOcrCandidate> get _photoCandidates {
    final candidates = _visibleCandidates;
    // [OCR 추가] 첫 선택 이후에는 기존 같은 열 상품명·수량·금액 후보 좁히기를 유지한다.
    if (!_choosingNames || _selectedIds.isNotEmpty) {
      return candidates;
    }
    return receiptCandidatesWithoutDuplicateNumbers([
      ...candidates,
      ..._source.numbers.where(
        (candidate) => !_source.rows.any(
          (row) => row.tokens.any((token) => token.id == candidate.id),
        ),
      ), // [OCR 추가] 열/부분 OCR에서 새로 읽힌 숫자도 다음 검토·선택에서 표시한다.
      for (final row in _source.rows)
        for (final token in row.tokens)
          if (token.bounds.isFinite &&
              !token.bounds.isEmpty &&
              !candidates.any(
                (candidate) =>
                    candidate.bounds.left <= token.bounds.left &&
                    candidate.bounds.top <= token.bounds.top &&
                    candidate.bounds.right >= token.bounds.right &&
                    candidate.bounds.bottom >= token.bounds.bottom,
              ))
            ReceiptOcrCandidate(
              id: token.id,
              text: token.text,
              bounds: token.bounds,
            ),
    ]); // [OCR 수정] 원문 숫자의 겹친 박스에도 자동 누적과 같은 중복 기준을 적용한다.
  }

  ReceiptOcrCandidate _product(String id) =>
      _products.firstWhere((item) => item.id == id);
  List<ReceiptOcrCandidate> get _visibleCandidates {
    if (_choosingNames) {
      if (_automatic || _selectedIds.isEmpty) return _products;
      final first = _product(_selectedIds.first);
      return receiptProductsBelow(_products, first);
    }
    final product = _product(_selectedIds[_priceIndex!]);
    if (_choosingQuantity) {
      return receiptCandidatesWithoutDuplicateNumbers(
        _quantitiesByProduct[product.id]!,
        selectedId: _selectedQuantities[product.id],
      );
    }
    if (_automatic) {
      return receiptCandidatesWithoutDuplicateNumbers(
        receiptAutomaticAmountsNear(
          _source,
          product,
          quantity: _selectedCandidate(product.id, quantity: true),
          amounts: _pricesByProduct[product.id]!,
        ),
        selectedId: _selectedPrices[product.id],
      );
    }
    return receiptCandidatesWithoutDuplicateNumbers(
      _pricesByProduct[product.id]!,
      selectedId: _selectedPrices[product.id],
    );
  }

  @override
  void initState() {
    super.initState();
    _products = List.of(_source.products);
    // [OCR 추가] 기존 항목은 별도 사본 상태에서 수량 → 금액 순서로 선택한다.
    final edited = widget.editLine;
    if (edited != null) {
      if (edited.ocrQuantity != null) {
        _quantitySearchAreas.add(edited.ocrQuantity!);
      }
      _automatic = false; // [OCR 수정] 기존 항목 편집은 전체 자동을 실행하지 않는다.
      final product = edited.ocrProduct!;
      _products = [product];
      _selectedIds.add(product.id);
      _prepareProductCandidates(product);
      _directQuantities[product.id] = edited.quantity;
      _directPrices[product.id] = edited.ocrInputAmount ?? edited.total;
      _isUnitPrice = edited.ocrAmountIsUnitPrice;
      _priceIndex = 0;
      _choosingQuantity = true;
    }
    _photoLoading = _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    try {
      // [OCR 수정] 공통 함수는 사진과 크기만 읽는다. 화면 종료 확인과 오류 안내는 이 화면에서 처리한다.
      final photo = await loadReceiptPhoto(
        _source.photoPath,
        photoBytes: _source.photoBytes,
      );
      if (!mounted) return;
      final bytes = photo.bytes;
      final size = photo.size;
      setState(() {
        _photoBytes = bytes;
        _photoSize = size;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _photoError = '사진을 열지 못했어요. 아래 후보 버튼으로 선택할 수 있어요.');
      }
    }
  }

  bool _isSelected(ReceiptOcrCandidate candidate) {
    if (_choosingNames) return _selectedIds.contains(candidate.id);
    final selected = _choosingQuantity ? _selectedQuantities : _selectedPrices;
    return selected[_selectedIds[_priceIndex!]] == candidate.id;
  }

  // [OCR 추가] 수동 선택·자동 기준 선택·기존 항목 편집에서 동일한 숫자 후보를 준비한다.
  // 후보 목록만 채우며, 사용자가 고른 값이나 현재 입력 단계는 바꾸지 않는다.
  void _prepareProductCandidates(ReceiptOcrCandidate product) {
    // [OCR 추가] 이전 단계로 돌아왔다가 다시 진행해도 사용자가 수정한 후보를 덮어쓰지 않는다.
    if (_pricesByProduct.containsKey(product.id) &&
        _quantitiesByProduct.containsKey(product.id)) {
      return;
    }
    final candidates = receiptPricesNear(_source, product);
    // [OCR 추가] 원문에서 가까운 숫자를 한 번 찾고 금액·수량용 목록을 따로 만든다.
    // 한쪽 목록의 후보를 수정·추가해도 다른 쪽 목록은 바뀌지 않아야 한다.
    // 수량은 1~999인 숫자만 후보로 제시하며 이 범위에 든다는 이유로 자동 확정하지는 않는다.
    // 한쪽 목록만 이미 있다면 그것은 유지하고 없는 목록만 원문에서 준비한다.
    _pricesByProduct.putIfAbsent(product.id, () => List.of(candidates));
    _quantitiesByProduct.putIfAbsent(
      product.id,
      () => candidates
          .where(
            (candidate) => candidate.number! >= 1 && candidate.number! <= 999,
          )
          .toList(),
    );
  }

  void _prepareAutomaticSeed(ReceiptOcrCandidate product) {
    _prepareProductCandidates(product);
    _priceIndex = 0;
    _choosingQuantity = true;
  }

  void _select(ReceiptOcrCandidate candidate) {
    setState(() {
      // [OCR 추가] 숫자·기호 원문 박스도 상품명으로 선택할 수 있게 선택 상태에 보관한다.
      if (_choosingNames && !_products.any((item) => item.id == candidate.id)) {
        _products.add(candidate);
      }
      if (_choosingNames && _automatic) {
        final wasSelected = _selectedIds.contains(candidate.id);
        _selectedIds.clear();
        if (!wasSelected) {
          _selectedIds.add(candidate.id);
          _prepareAutomaticSeed(candidate);
        }
        return;
      }
      if (_choosingNames) {
        if (_selectedIds.contains(candidate.id)) {
          if (_selectedIds.first == candidate.id) {
            _selectedIds.clear();
          } else {
            _selectedIds.remove(candidate.id);
          }
        } else {
          _selectedIds.add(candidate.id);
        }
        return;
      }
      final id = _selectedIds[_priceIndex!];
      if (_choosingQuantity) {
        // [OCR 수정] 수량만 바꾸어도 독립적으로 선택한 금액은 유지한다. 같은 영역을 두 필드로 쓰는 경우만 해제한다.
        if (_automatic && _selectedPrices[id] == candidate.id) {
          _selectedPrices.remove(id);
          _directPrices.remove(id);
        }
        // [OCR 추가] 눈에 보인 한 글자 박스 여백을 실제 수량 열·부분 OCR의 기준 영역에 반영한다.
        final quantity = _quantityWithSearchArea(candidate);
        final candidates = _quantitiesByProduct[id]!;
        candidates[candidates.indexWhere((item) => item.id == candidate.id)] =
            quantity;
        _selectedQuantities[id] = quantity.id;
        _directQuantities.remove(id);
        if (_automatic) _choosingQuantity = false;
      } else {
        _selectedPrices[id] = candidate.id;
        _directPrices.remove(id);
      }
    });
  }

  int? _amountFor(String id) {
    if (_directPrices.containsKey(id)) return _directPrices[id];
    final selected = _selectedPrices[id];
    if (selected == null) return null;
    return _pricesByProduct[id]!
        .firstWhere((candidate) => candidate.id == selected)
        .number;
  }

  int _quantityFor(String id) {
    if (_directQuantities.containsKey(id)) {
      return _directQuantities[id]!;
    }
    final selected = _selectedQuantities[id];
    if (selected == null) return 1; // [OCR 수정] 화면에서 확인할 기본 수량은 1개다.
    return _quantitiesByProduct[id]!
        .firstWhere((candidate) => candidate.id == selected)
        .number!;
  }

  bool get _canContinue {
    if (_automatic) {
      if (_selectedIds.length != 1) return false;
      final id = _selectedIds.single;
      final amount = _selectedCandidate(id);
      final quantity = _selectedCandidate(id, quantity: true);
      if (amount == null || quantity == null) return false;
      // [OCR 추가] 어느 입력 칸을 보고 있어도 세 기준과 현재 좁힌 금액 범위를 확인한다.
      return receiptAutomaticAmountsNear(
        _source,
        _product(id),
        quantity: quantity,
        amounts: _pricesByProduct[id]!,
      ).any((candidate) => candidate.id == amount.id);
    }
    if (_choosingNames) return _selectedIds.isNotEmpty;
    final id = _selectedIds[_priceIndex!];
    if (_choosingQuantity) {
      return true; // [OCR 수정] 기본 1개도 사용자가 확인해 진행할 수 있다.
    }
    return _amountFor(id) != null;
  }

  void _next() {
    if (_finished || _automaticReading || !_canContinue) return;
    if (_automatic) {
      _finishAutomatic();
      return;
    }
    if (_choosingNames) {
      setState(() {
        for (final id in _selectedIds) {
          _prepareProductCandidates(_product(id));
        }
        _priceIndex = 0;
      });
      return;
    }
    if (widget.editLine != null && _choosingQuantity) {
      setState(() => _choosingQuantity = false);
      return;
    }
    if (!_choosingQuantity && widget.editLine == null) {
      // [OCR 수정] 모든 상품의 금액을 연결한 뒤 첫 상품의 수량 단계로 이동한다.
      setState(() {
        if (_priceIndex! < _selectedIds.length - 1) {
          _priceIndex = _priceIndex! + 1;
        } else {
          _priceIndex = 0;
          _choosingQuantity = true;
        }
      });
      return;
    }
    final id = _selectedIds[_priceIndex!];
    try {
      receiptLineFromAmount(
        id: 'check',
        title: _product(id).text,
        amount: _amountFor(id)!,
        isUnitPrice: _isUnitPrice,
        quantity: _quantityFor(id),
      );
    } on FormatException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (_priceIndex! < _selectedIds.length - 1) {
      setState(() {
        _priceIndex = _priceIndex! + 1;
        // [OCR 수정] 수량도 선택된 상품 전체를 차례로 확인한다.
      });
      return;
    }
    final lines = <ReceiptLineDraft>[];
    for (var index = 0; index < _selectedIds.length; index++) {
      final productId = _selectedIds[index];
      lines.add(
        receiptLineFromAmount(
          id: 'manual-ocr-$index',
          title: _product(productId).text,
          amount: _amountFor(productId)!,
          isUnitPrice: _isUnitPrice,
          quantity: _quantityFor(productId),
        ),
      );
    }
    // [OCR 추가] 상품명·선택 금액만 별도 박스로 남긴다. 직접 입력한 금액은 추정 박스를 만들지 않는다.
    for (var i = 0; i < lines.length; i++) {
      final id = _selectedIds[i];
      lines[i].ocrProduct = _product(id);
      lines[i].ocrAmountIsUnitPrice = _isUnitPrice;
      lines[i].ocrInputAmount = _amountFor(id);
      lines[i].ocrQuantity =
          _selectedCandidate(id, quantity: true) ??
          widget.editLine?.ocrQuantity;
      final selected = _selectedPrices[id];
      if (selected != null) {
        lines[i].ocrAmount = _pricesByProduct[id]!.firstWhere(
          (candidate) => candidate.id == selected,
        );
      } else if (!_changedDirectAmounts.contains(id)) {
        lines[i].ocrAmount = widget.editLine?.ocrAmount;
      }
    }
    _returnLines(lines);
  }

  void _returnLines(List<ReceiptLineDraft> lines) {
    if (_finished) return; // [OCR 추가] 건너뛰기 연속 입력으로 다음 화면까지 닫히지 않게 한다.
    _finished = true;
    Navigator.pop(
      context,
      ReceiptDraft(
        id: widget.draft.id,
        store: widget.draft.store,
        purchasedOn: widget.draft.purchasedOn,
        lines: lines,
        condition: widget.draft.condition,
        share: widget.draft.share,
        ocrResult: _source,
      ),
    );
  }

  Future<void> _finishAutomatic() async {
    if (_automaticReading || _finished) return;
    final id = _selectedIds.single;
    final seed = ReceiptAutomaticSeed(
      product: _product(id),
      amount: _selectedCandidate(id)!,
      quantity: _selectedCandidate(id, quantity: true),
      isUnitPrice: _isUnitPrice,
      includeQuantity: true,
    );
    final revision = ++_automaticRevision;
    bool isCurrent() => mounted && !_finished && revision == _automaticRevision;
    setState(() {
      _automaticReading = true;
      _automaticBounds = null;
      _automaticFieldBounds.clear();
      _automaticFieldProgress.clear();
      _automaticProgress = '자동 선택 영역을 읽고 있어요';
    });
    try {
      // [OCR 추가] 사진 로딩 중 누르면 로딩 완료를 기다려 보정 사진과 OCR 좌표를 같은 기준으로 사용한다.
      await _photoLoading;
      if (!isCurrent()) return;
      final List<ReceiptLineDraft>? lines;
      if (_photoBytes == null || _photoSize == null) {
        // [OCR 추가] 사진을 열 수 없다는 기존 오류를 유지하며 기존 OCR 후보는 검토할 수 있게 남긴다.
        lines = automaticReceiptLines(_source, seed, products: _products);
      } else {
        // [OCR 추가] 열 탐색도 반복 OCR과 같은 프레임/터치 처리 대기를 사용한다.
        Future<void> prepareRead() async {
          // [OCR 수정] 프레임이 중지되어도 박스 표시 대기가 OCR을 막지 않게 최대 150ms만 기다린다.
          await WidgetsBinding.instance.endOfFrame.timeout(
            const Duration(milliseconds: 150),
            onTimeout: () {},
          );
          // [OCR 수정] 플랫폼 OCR을 연속 호출하기 전에 렌더링/터치 이벤트가 처리될 시간을 준다.
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        // [OCR 추가] 모의 부분 OCR 주입 시 열 탐색도 별도로 주입해 실제 인식과 섞지 않는다.
        Future<List<ReceiptLineDraft>?> readWithSession(
          ReceiptRegionSession? session,
        ) async {
          final scanRegion =
              widget.scanRegion ??
              (widget.recognizeRegion == null
                  ? (Uint8List bytes, Rect bounds) =>
                        session!.recognizeRegionRows(bounds)
                  : null);
          return await readAutomaticReceiptLines(
            source: _source,
            onCandidates: (result) {
              if (!isCurrent()) return;
              _accumulatedSource = result;
              _products = List.of(result.products);
            },
            seed: seed,
            products: _products,
            photoBytes: _photoBytes!,
            photoSize: _photoSize!,
            scanRegion: scanRegion == null
                ? null
                : (bytes, bounds) async {
                    await prepareRead();
                    if (!isCurrent()) return [];
                    return await scanRegion(bytes, bounds);
                  },
            recognize: (bytes, bounds) async {
              await prepareRead();
              if (!isCurrent()) return '';
              final recognize =
                  widget.recognizeRegion ??
                  (Uint8List bytes, Rect bounds) =>
                      session!.recognizeRegion(bounds);
              return await recognize(bytes, bounds);
            },
            recognizeQuantity:
                widget.recognizeQuantity ??
                (session?.quantitySession == null
                    ? null
                    : (bytes, bounds) async {
                        await prepareRead();
                        if (!isCurrent()) return '';
                        return await session!.quantitySession!
                            .recognizeQuantityRegion(
                              bounds,
                              // [OCR 추가] 사용자가 지정한 수량·금액 간격으로 같은 행의 가격 문맥까지 포함한다.
                              horizontalContext: seed.quantity == null
                                  ? 0
                                  : (seed.amount.bounds.right -
                                            seed.quantity!.bounds.right)
                                        .abs(),
                            );
                      }),
            isCurrent: isCurrent,
            onProductShown: prepareRead,
            onProgress: (item, total, field, attempts, successes, bounds) {
              if (!isCurrent()) return;
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
              });
              // [OCR 추가] 두 박스의 합친 범위를 따라가 한쪽 갱신마다 사진이 좌우로 흔들리지 않게 한다.
              final visible = _automaticFieldBounds.values.fold<Rect?>(
                null,
                (combined, rect) =>
                    combined == null ? rect : combined.expandToInclude(rect),
              );
              _followAutomaticBounds(visible ?? bounds);
            },
          );
        }

        // [OCR 수정] 실제 자동 선택만 한 장 전용 세션으로 감싼다. 모의 OCR은 네이티브 인식과 섞지 않는다.
        if (widget.recognizeRegion == null) {
          lines = await OcrService().withReceiptRegionSession(
            _photoBytes!,
            readWithSession,
            parallelQuantity: true,
          );
        } else {
          lines = await readWithSession(null);
        }
      }
      if (!isCurrent() || lines == null) return;
      _returnLines(lines);
    } on FormatException catch (error) {
      if (!mounted || !isCurrent()) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted || !isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자동 선택을 완료하지 못했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted && revision == _automaticRevision) {
        // [OCR 수정] 완료로 화면을 닫을 때도 박스를 지운다.
        setState(() {
          _automaticReading = false;
          _automaticProgress = '';
          _automaticBounds = null;
          _automaticFieldBounds.clear();
          _automaticFieldProgress.clear();
        });
      }
    }
  }

  void _previous() {
    if (_automatic) {
      setState(() {
        if (!_choosingQuantity) {
          _choosingQuantity = true;
        } else {
          _priceIndex = null;
          _choosingQuantity = false;
        }
      });
      return;
    }
    if (widget.editLine != null) {
      if (_choosingQuantity) {
        Navigator.pop(context);
        return;
      }
      setState(() => _choosingQuantity = true);
      return;
    }
    setState(() {
      if (_choosingQuantity && _priceIndex == 0) {
        _choosingQuantity = false;
        _priceIndex = _selectedIds.length - 1;
        return;
      }
      if (_priceIndex == 0) {
        _priceIndex = null;
        return;
      }
      _priceIndex = _priceIndex! - 1;
    });
  }

  Future<String?> _askValue(
    String title,
    String initial, {
    bool name = false,
    bool quantity = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final formKey = GlobalKey<FormState>();
    var label = '금액 (원)';
    if (quantity) label = '수량 (개)';
    if (name) label = '상품명'; // [OCR 추가]
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: TextFormField(
              key: const ValueKey('ocr-edit-value'),
              controller: controller,
              autofocus: true,
              keyboardType: name ? TextInputType.text : TextInputType.number,
              decoration: InputDecoration(labelText: label),
              validator: (text) {
                final value = (text ?? '').trim();
                if (name) {
                  if (value.isEmpty || value.length > 50) {
                    return '상품명은 1~50자로 입력해주세요.';
                  }
                  return null;
                }
                final number = receiptSelectionAmount(value);
                if (quantity) {
                  if (number == null || number < 1 || number > 999) {
                    return '수량은 1~999개로 입력해주세요.';
                  }
                  return null;
                }
                if (number == null) {
                  return '0~9,999,999원의 정수로 입력해주세요.';
                }
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
    // [OCR 수정] 이유: 대화상자의 종료 애니메이션 동안 입력 컨트롤러를 유지한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return edited;
  }

  Future<void> _edit(ReceiptOcrCandidate candidate) async {
    final name = _choosingNames;
    final quantity = _choosingQuantity;
    final id = name ? null : _selectedIds[_priceIndex!];
    var title = '금액 수정';
    if (name) title = '상품명 수정';
    if (quantity) title = '수량 수정';
    final edited = await _askValue(
      title,
      // [OCR 수정] 이유: 숫자 후보 수정창은 이미 검증한 값으로 시작해 원·통화 기호 때문에 그대로 적용이 실패하지 않게 한다.
      name
          ? candidate.text
          : NumberFormat.decimalPattern('ko_KR').format(candidate.number!),
      name: name,
      quantity: quantity,
    );
    if (!mounted || edited == null) return;
    setState(() {
      List<ReceiptOcrCandidate> candidates;
      if (name) {
        candidates = _products;
      } else if (quantity) {
        candidates = _quantitiesByProduct[id]!;
      } else {
        candidates = _pricesByProduct[id]!;
      }
      final index = candidates.indexWhere((item) => item.id == candidate.id);
      final updated = ReceiptOcrCandidate(
        id: candidate.id,
        text: edited,
        bounds: candidate.bounds,
        number: name ? null : receiptSelectionAmount(edited),
      );
      // [OCR 추가] 원문 박스 수정은 적용한 경우에만 후보에 추가한다. 취소하면 원본 표시를 유지한다.
      if (quantity && _quantitySearchAreas.contains(candidate)) {
        _quantitySearchAreas.add(updated);
      }
      if (index < 0 && name) {
        candidates.add(updated);
      } else {
        candidates[index] = updated;
      }
    });
  }

  Future<void> _directInput() async {
    final quantity = _choosingQuantity;
    final id = _selectedIds[_priceIndex!];
    final current = quantity ? _quantityFor(id) : _amountFor(id);
    final edited = await _askValue(
      quantity ? '수량 직접 입력' : '금액 직접 입력',
      current?.toString() ?? '',
      quantity: quantity,
    );
    if (!mounted || edited == null) return;
    setState(() {
      if (quantity) {
        _directQuantities[id] = receiptSelectionAmount(edited)!;
        _selectedQuantities.remove(id);
      } else {
        _changedDirectAmounts.add(id);
        _directPrices[id] = receiptSelectionAmount(edited)!;
        _selectedPrices.remove(id);
      }
    });
  }

  ReceiptOcrCandidate? _selectedCandidate(String id, {bool quantity = false}) {
    final selected = quantity ? _selectedQuantities[id] : _selectedPrices[id];
    if (selected == null) return null;
    final candidates = quantity
        ? _quantitiesByProduct[id]!
        : _pricesByProduct[id]!;
    final candidate = candidates.firstWhere(
      (candidate) => candidate.id == selected,
    );
    if (!quantity || !_directQuantities.containsKey(id)) {
      return candidate;
    }
    // [OCR 추가] 화살표로 고친 수량은 선택한 사진 좌표를 유지해 자동 행 연결에 사용한다.
    return ReceiptOcrCandidate(
      id: candidate.id,
      text: '${_directQuantities[id]}',
      bounds: candidate.bounds,
      number: _directQuantities[id],
    );
  }

  Future<void> _regionInput({bool editName = false}) async {
    final names = _choosingNames;
    final quantity = _choosingQuantity;
    // [OCR 수정] 사진에서 어느 영역을 고칠지와 입력칸에 무엇을 보여줄지를 함께 정한다.
    // candidate는 기존 박스 위치이고 current는 현재 값이다. 직접 고친 값이 있어 둘의 글자가 다를 수 있다.
    String? id;
    ReceiptOcrCandidate? candidate;
    final String label;
    final String? current;
    if (names) {
      // [OCR 추가] 새 이름 영역은 빈 상태에서 시작하고 기존 이름 수정은 마지막 선택의 위치·글자를 복원한다.
      if (editName) {
        id = _selectedIds.last;
        candidate = _product(id);
      }
      label = '상품명';
      current = candidate?.text;
    } else {
      id = _selectedIds[_priceIndex!];
      candidate = _selectedCandidate(id, quantity: quantity);
      // [OCR 추가] 이번 선택의 박스가 없을 때만 기존 항목의 위치를 사용한다.
      // 입력칸의 숫자는 별도로 가져와 화살표나 직접 입력으로 바꾼 현재 값을 보여준다.
      if (quantity) {
        candidate ??= widget.editLine?.ocrQuantity;
        label = '수량';
        current = _quantityFor(id).toString();
      } else {
        candidate ??= widget.editLine?.ocrAmount;
        label = '금액';
        current = _amountFor(id)?.toString();
      }
    }
    final value = await Navigator.push<ReceiptRegionValue>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptRegionScreen(
          photoPath: _source.photoPath,
          photoBytes: _source.photoBytes,
          label: label,
          numeric: !names,
          quantity: quantity,
          initialBounds: candidate?.bounds,
          initialText: current ?? '',
        ),
      ),
    );
    // [OCR 추가] 적용한 결과만 후보에 반영한다. 편집을 취소하거나 원래 화면이 닫혔다면 그대로 둔다.
    if (!mounted || value == null) return;
    final updated = ReceiptOcrCandidate(
      id: candidate?.id ?? 'region-${DateTime.now().microsecondsSinceEpoch}',
      text: value.text,
      bounds: value.bounds,
      number: names ? null : receiptSelectionAmount(value.text),
    );
    setState(() {
      if (names) {
        if (candidate == null) {
          _products.add(updated);
          if (_automatic) _selectedIds.clear();
          _selectedIds.add(updated.id);
          if (_automatic) _prepareAutomaticSeed(updated);
        } else {
          _products[_products.indexWhere((item) => item.id == candidate!.id)] =
              updated;
        }
        return;
      }
      final candidates = quantity
          ? _quantitiesByProduct[id]!
          : _pricesByProduct[id]!;
      final index = candidates.indexWhere((item) => item.id == updated.id);
      if (index < 0) {
        candidates.add(updated);
      } else {
        candidates[index] = updated;
      }
      if (quantity) {
        // [OCR 추가] 직접 지정·수정한 영역은 확인한 크기 그대로 사용하며 표시 여백을 다시 더하지 않는다.
        _quantitySearchAreas.add(updated);
        _selectedQuantities[id!] = updated.id;
        _directQuantities.remove(id);
        if (_automatic) {
          _choosingQuantity =
              false; // [OCR 수정] 영역으로 확정한 수량도 후보 선택과 같이 금액 단계로 진행한다.
        }
      } else {
        _selectedPrices[id!] = updated.id;
        _directPrices.remove(id);
        _changedDirectAmounts.remove(id);
      }
    });
  }

  String get _actionLabel {
    if (_automatic) return '끝까지 자동 선택';
    if (_choosingNames) {
      return '상품명 선택 완료 (${_selectedIds.length}개)';
    }
    if (widget.editLine != null) {
      return _choosingQuantity ? '금액 선택으로' : '수정 적용';
    }
    final last = _priceIndex == _selectedIds.length - 1;
    if (!_choosingQuantity) return last ? '수량 확인' : '다음 상품 금액';
    if (last && widget.pageNumber != null) {
      return widget.pageNumber! < widget.pageCount! ? '다음 장 선택' : '모든 항목 검토';
    }
    return last ? '선택한 항목 검토' : '다음 상품 수량';
  }

  String get _heading {
    if (_choosingNames) {
      if (_automatic) return '첫 상품명·수량·금액 선택';
      return '상품명 전체 수동 선택';
    }
    final product = _product(_selectedIds[_priceIndex!]);
    final kind = _choosingQuantity ? '수량 선택' : '금액 선택';
    return '${_priceIndex! + 1}/${_selectedIds.length} · ${product.text} $kind';
  }

  String _candidateLabel(ReceiptOcrCandidate candidate) {
    if (_choosingNames) return candidate.text;
    if (_choosingQuantity) return '${candidate.number}개';
    return '${NumberFormat.decimalPattern('ko_KR').format(candidate.number)}원';
  }

  Widget _amountModeChoices() => SwitchListTile(
    key: const ValueKey('ocr-unit-price-toggle'),
    contentPadding: EdgeInsets.zero,
    title: const Text('단가로 입력하기'),
    value: _isUnitPrice,
    onChanged: (value) => setState(() => _isUnitPrice = value),
  );

  Widget _selectionModeButton(String label, bool automatic) {
    final selected = _automatic == automatic;
    return Expanded(
      child: OutlinedButton(
        key: ValueKey(automatic ? 'ocr-automatic-names' : 'ocr-manual-names'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: selected ? AppColors.primary : AppColors.surface,
          foregroundColor: selected ? Colors.white : null,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        // [OCR 추가] 수동으로 고른 여러 상품을 자동 기준 하나로 조용히 축소하지 않는다.
        onPressed: automatic && _selectedIds.length > 1
            ? null
            : () => setState(() {
                _automatic = automatic;
                _priceIndex = null; // [OCR 추가] 수동 전환 시 여러 이름부터 선택한다.
                _choosingQuantity = false;
                if (automatic && _selectedIds.isNotEmpty) {
                  _prepareAutomaticSeed(_product(_selectedIds.single));
                }
              }),
        child: Text(label),
      ),
    );
  }

  Widget _automaticControls() => Column(
    children: [
      // [OCR 추가] 같은 폭의 두 선택 버튼과 간격을 합쳐 단가 버튼 전체 폭에 맞춘다.
      Row(
        children: [
          _selectionModeButton('상품 수동 선택', false),
          const SizedBox(width: 8),
          _selectionModeButton('자동 선택', true),
        ],
      ),
      const SizedBox(height: 8),
      _amountModeChoices(),
    ],
  );

  String _seedFieldLabel(String field, String? id) {
    if (id == null) return field == '수량' ? '수량\n1' : field;
    if (field == '상품명') return '$field\n${_product(id).text}';
    if (field == '수량') return '$field\n${_quantityFor(id)}';
    return '$field\n${_amountFor(id) ?? '—'}';
  }

  Widget _automaticSeedFields() {
    final id = _selectedIds.isEmpty ? null : _selectedIds.single;
    return Row(
      children: [
        for (final field in ['상품명', '수량', _isUnitPrice ? '단가' : '금액'])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: OutlinedButton(
                key: ValueKey('ocr-seed-${field == '단가' ? '금액' : field}'),
                onPressed: field != '상품명' && id == null
                    ? null
                    : () => setState(() {
                        _priceIndex = field == '상품명' ? null : 0;
                        _choosingQuantity = field == '수량';
                      }),
                child: Text(
                  _seedFieldLabel(field, id),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _changeQuantity(String id, int change) {
    final value = _quantityFor(id) + change;
    if (value < 1 || value > 999) return;
    setState(() => _directQuantities[id] = value);
  }

  Widget _quantityArrows() {
    final id = _selectedIds.isEmpty ? null : _selectedIds[_priceIndex ?? 0];
    final value = id == null ? 1 : _quantityFor(id);
    // [OCR 수정] 터치 범위와 버튼 경계를 항상 보여주고 제한 수량에서는 색으로 비활성 상태를 구분한다.
    final arrowStyle = IconButton.styleFrom(
      backgroundColor: AppColors.secondary,
      foregroundColor: AppColors.primary,
      disabledBackgroundColor: AppColors.surface,
      disabledForegroundColor: AppColors.muted,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const ValueKey('ocr-quantity-down'),
          style: arrowStyle,
          tooltip: '수량 줄이기',
          onPressed: id == null || value <= 1
              ? null
              : () => _changeQuantity(id, -1),
          icon: const Icon(Icons.arrow_downward),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('$value개', key: const ValueKey('ocr-quantity-value')),
        ),
        IconButton(
          key: const ValueKey('ocr-quantity-up'),
          style: arrowStyle,
          tooltip: '수량 늘리기',
          onPressed: id == null || value >= 999
              ? null
              : () => _changeQuantity(id, 1),
          icon: const Icon(Icons.arrow_upward),
        ),
      ],
    );
  }

  Widget _numberControls() {
    final id = _selectedIds[_priceIndex!];
    final current = _choosingQuantity ? _quantityFor(id) : _amountFor(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_automatic && _priceIndex == 0 && !_choosingQuantity)
          _amountModeChoices(),
        if (current != null)
          Text(
            _choosingQuantity
                ? '선택한 수량: $current개'
                : '선택한 금액: ${NumberFormat.decimalPattern('ko_KR').format(current)}원',
          ),
        TextButton(
          onPressed: _directInput,
          child: Text(_choosingQuantity ? '수량 직접 입력' : '금액 직접 입력'),
        ),
      ],
    );
  }

  Widget _selectedNamesSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택한 상품명 ${_selectedIds.length}개',
            key: const ValueKey('ocr-selected-name-count'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_selectedIds.isNotEmpty)
            SizedBox(
              height: 48,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final id in _selectedIds)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(_product(id).text),
                          onDeleted: () => _select(_product(id)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // [OCR 추가] 확대 배율은 유지하고 현재 영역이 화면 밖일 때만 사진을 이동한다. 읽는 원본 좌표는 변경하지 않는다.
  void _followAutomaticBounds(Rect bounds) {
    final viewport = _photoViewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize || _photoSize == null) {
      return;
    }
    final fitScale = viewport.size.width / _photoSize!.width;
    final rect = Rect.fromLTRB(
      bounds.left * fitScale,
      bounds.top * fitScale,
      bounds.right * fitScale,
      bounds.bottom * fitScale,
    );
    final shown = MatrixUtils.transformRect(_transform.value, rect);
    var dx = 0.0;
    var dy = 0.0;
    if (shown.left < 12 || shown.right > viewport.size.width - 12) {
      dx = viewport.size.width / 2 - shown.center.dx;
    }
    if (shown.top < 12 || shown.bottom > viewport.size.height - 12) {
      dy = viewport.size.height / 2 - shown.center.dy;
    }
    if (dx == 0 && dy == 0) return;
    final matrix = _transform.value.clone();
    final zoom = matrix.getMaxScaleOnAxis();
    matrix.storage[12] = (matrix.storage[12] + dx).clamp(
      -math.max(0.0, _photoSize!.width * fitScale * zoom - viewport.size.width),
      0.0,
    );
    matrix.storage[13] = (matrix.storage[13] + dy).clamp(
      -math.max(
        0.0,
        _photoSize!.height * fitScale * zoom - viewport.size.height,
      ),
      0.0,
    );
    _transform.value = matrix;
  }

  // [OCR 추가] 원문 표시와 수량 검색이 같은 여백을 사용한다. 확정한 수량 영역에는 중복 적용하지 않는다.
  Rect _candidatePhotoBounds(ReceiptOcrCandidate candidate, double scale) {
    if (candidate.text.trim().runes.length != 1 ||
        _quantitySearchAreas.contains(candidate)) {
      return candidate.bounds;
    }
    return candidate.bounds
        .inflate(4 / scale)
        .intersect(Offset.zero & _photoSize!);
  }

  ReceiptOcrCandidate _quantityWithSearchArea(ReceiptOcrCandidate candidate) {
    final viewport = _photoViewport.currentContext?.findRenderObject();
    if (_photoSize == null || viewport is! RenderBox || !viewport.hasSize) {
      return candidate;
    }
    final bounds = _candidatePhotoBounds(
      candidate,
      viewport.size.width / _photoSize!.width,
    );
    if (bounds == candidate.bounds) return candidate;
    final quantity = ReceiptOcrCandidate(
      id: candidate.id,
      text: candidate.text,
      number: candidate.number,
      bounds: bounds,
      isMergedName: candidate.isMergedName,
    );
    _quantitySearchAreas.add(quantity);
    return quantity;
  }

  Widget _photoCandidateBox(ReceiptOcrCandidate candidate, double scale) {
    final photoBounds = _candidatePhotoBounds(candidate, scale);
    final bounds = Rect.fromLTRB(
      photoBounds.left * scale,
      photoBounds.top * scale,
      photoBounds.right * scale,
      photoBounds.bottom * scale,
    );
    return Positioned(
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
      child: Semantics(
        label: candidate.text,
        button: true,
        selected: _isSelected(candidate),
        child: GestureDetector(
          key: ValueKey('ocr-box-${candidate.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _select(candidate),
          onLongPress: () => _edit(candidate),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isSelected(candidate)
                    ? AppColors.primary
                    : AppColors.muted,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo() {
    if (_photoBytes == null) {
      return Center(
        child: Text(
          _photoError.isEmpty ? '사진을 준비하고 있어요.' : _photoError,
          textAlign: TextAlign.center,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = _photoSize!;
        // [OCR 수정] fresh처럼 가로폭에 맞춘다. 긴 영수증을 전체 축소하면 기본 배율에서 이동할 여지가 없어진다.
        final scale = constraints.maxWidth / size.width;
        return Listener(
          key: _photoViewport,
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _trackPhotoPointer(event.pointer, true),
          onPointerUp: (event) => _trackPhotoPointer(event.pointer, false),
          onPointerCancel: (event) => _trackPhotoPointer(event.pointer, false),
          onPointerPanZoomStart: (event) =>
              _trackPhotoPointer(event.pointer, true),
          onPointerPanZoomEnd: (event) =>
              _trackPhotoPointer(event.pointer, false),
          // [OCR 추가] fresh와 같이 사진의 휠 이벤트를 목록이 다시 처리하지 않게 소비한다.
          onPointerSignal: (event) => GestureBinding
              .instance
              .pointerSignalResolver
              .register(event, (_) {}),
          child: InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            alignment: Alignment.topLeft,
            minScale: 1,
            maxScale: 6,
            child: SizedBox(
              width: size.width * scale,
              height: size.height * scale,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.memory(_photoBytes!, fit: BoxFit.fill),
                  ),
                  for (final candidate in _photoCandidates)
                    _photoCandidateBox(candidate, scale),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _visibleCandidates;
    final hasSelection = _canContinue;
    final heading = _heading;
    return Scaffold(
      appBar: AppBar(
        leading: const DesignBackButton(),
        leadingWidth: 68,
        titleSpacing: 8,
        title: Text(
          widget.pageNumber == null
              ? '영수증 항목 선택'
              : '영수증 항목 선택 (${widget.pageNumber}/${widget.pageCount}장)',
        ),
        actions: [
          if (widget.pageNumber != null)
            TextButton(
              onPressed: _automaticReading ? null : () => _returnLines([]),
              child: const Text('이 장 건너뛰기'),
            ),
        ],
      ),
      bottomNavigationBar: BottomAction(
        label: _automaticReading ? '자동 선택 중…' : _actionLabel,
        onPressed: hasSelection && !_automaticReading ? _next : null,
      ),
      body: AbsorbPointer(
        // [OCR 추가] 반복 인식 중에는 기준을 바꾸지 않고 뒤로 가기로 취소한다.
        absorbing: _automaticReading,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  SizedBox(
                    height: math.min(
                      280,
                      MediaQuery.sizeOf(context).height * .32,
                    ),
                    child: _photo(),
                  ),
                  if (_automaticReading) ...[
                    const LinearProgressIndicator(minHeight: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Text(
                        [
                          _automaticProgress,
                          ..._automaticFieldProgress.values,
                        ].join('\n'),
                        key: const ValueKey('ocr-automatic-progress'),
                      ),
                    ),
                  ],
                  if (_choosingNames && !_automatic) _selectedNamesSummary(),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      physics: _photoPointers.isEmpty
                          ? null
                          : const NeverScrollableScrollPhysics(),
                      // [OCR 수정] 이름 선택 중에는 스크롤을 유지하고, 다음 입력 단계는 목록 위에서 시작한다.
                      key: ValueKey(
                        'ocr-candidate-list-${_priceIndex ?? 'names'}-$_choosingQuantity',
                      ),
                      padding: const EdgeInsets.all(20),
                      children: [
                        // [OCR 수정] 후보가 많아도 첫 화면에서 자동 입력을 찾도록 선택 옵션을 목록 앞에 둔다.
                        if ((_automatic || _choosingNames) &&
                            widget.editLine == null)
                          _automaticControls(),
                        Text(
                          _automatic
                              ? '첫 상품명·수량·${_isUnitPrice ? '단가' : '금액'} 선택'
                              : heading,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        if (_automatic) _automaticSeedFields(),
                        if (_automatic || _choosingQuantity) _quantityArrows(),
                        if (!_choosingNames) _numberControls(),
                        if (!_choosingNames && !_automatic)
                          TextButton(
                            onPressed: _previous,
                            child: const Text('이전 선택'),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final candidate in candidates)
                              GestureDetector(
                                onLongPress: () => _edit(candidate),
                                child: OutlinedButton(
                                  key: ValueKey(
                                    'ocr-candidate-${candidate.id}',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: _isSelected(candidate)
                                        ? AppColors.secondary
                                        : AppColors.surface,
                                    side: BorderSide(
                                      color: _isSelected(candidate)
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  onPressed: () => _select(candidate),
                                  child: Text(_candidateLabel(candidate)),
                                ),
                              ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => _regionInput(),
                          icon: const Icon(Icons.crop_free),
                          label: Text(
                            _choosingNames
                                ? '상품명 영역 지정'
                                : _choosingQuantity
                                ? '수량 영역 지정·수정'
                                : '금액 영역 지정·수정',
                          ),
                        ),
                        if (_choosingNames && _selectedIds.isNotEmpty)
                          TextButton(
                            onPressed: () => _regionInput(editName: true),
                            child: const Text('선택한 상품명 영역 수정'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
