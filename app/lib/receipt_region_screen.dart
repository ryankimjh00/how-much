import 'receipt_region_retry.dart'; // [OCR 추가]
import 'dart:io'; // [OCR 추가]
import 'dart:math' as math; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'app_theme.dart'; // [OCR 추가]
import 'design_widgets.dart'; // [OCR 추가]
import 'ocr_service.dart'; // [OCR 추가]

/// [OCR 추가] 적용된 원본 사진 좌표와 검증된 입력값이다. 취소하면 결과를 반환하지 않는다.
class ReceiptRegionValue {
  // [OCR 추가]
  // [OCR 추가]
  const ReceiptRegionValue(this.bounds, this.text); // [OCR 추가]
  final Rect bounds; // [OCR 추가]
  final String text; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 상품명·수량·금액 영역을 사본에서 편집한다. OCR 콜백은 실제 서비스와 실패 테스트에 같은 계약을 사용한다.
class ReceiptRegionScreen extends StatefulWidget {
  // [OCR 추가]
  // [OCR 추가]
  const ReceiptRegionScreen({
    // [OCR 추가]
    super.key, // [OCR 추가]
    required this.photoPath, // [OCR 추가]
    this.photoBytes, // [OCR 추가]
    required this.label, // [OCR 추가]
    this.initialBounds, // [OCR 추가]
    this.initialText = '', // [OCR 추가]
    this.numeric = false, // [OCR 추가]
    this.quantity = false, // [OCR 추가]
    this.date = false, // [OCR 추가]
    this.recognize, // [OCR 추가]
  }); // [OCR 추가]
  final Uint8List? photoBytes; // [OCR 추가]
  final String photoPath; // [OCR 추가]
  final String label; // [OCR 추가]
  final Rect? initialBounds; // [OCR 추가]
  final String initialText; // [OCR 추가]
  final bool numeric; // [OCR 추가]
  final bool quantity; // [OCR 추가]
  final bool date; // [OCR 추가]
  final Future<String> Function(Uint8List, Rect)? recognize; // [OCR 추가]
  @override // [OCR 추가]
  State<ReceiptRegionScreen> createState() => _ReceiptRegionScreenState(); // [OCR 추가]
} // [OCR 추가]

class _ReceiptRegionScreenState extends State<ReceiptRegionScreen> {
  // [OCR 추가]
  // [OCR 추가]
  final _transform = TransformationController(); // [OCR 추가]
  final _viewport = GlobalKey(); // [OCR 추가]
  final _form = GlobalKey<FormState>(); // [OCR 추가]
  late final _text = TextEditingController(
    // [OCR 추가]
    text: widget.initialText, // [OCR 추가]
  ); // [OCR 추가]
  Uint8List? _bytes; // [OCR 추가]
  Size? _size; // [OCR 추가]
  Rect? _bounds; // [OCR 추가]
  Rect? _dragBounds; // [OCR 추가]
  Offset? _dragPoint; // [OCR 추가]
  String _notice = ''; // [OCR 추가]
  bool _reading = false; // [OCR 추가]
  bool _loadFailed = false; // [OCR 추가]
  int _revision = 0; // [OCR 추가]
  int _attempts = 0; // [OCR 추가]
  bool _recognitionBusy = false; // [OCR 추가]
  Rect? _retryBounds; // [OCR 추가]
  Rect? _readingBounds; // [OCR 추가]
  final _candidates = <ReceiptRegionCandidate>[]; // [OCR 수정]
  @override // [OCR 추가]
  void initState() {
    // [OCR 추가]
    super.initState(); // [OCR 추가]
    _load(); // [OCR 추가]
  } // [OCR 추가]

  @override // [OCR 추가]
  void dispose() {
    // [OCR 추가]
    _revision++; // [OCR 추가]
    _text.dispose(); // [OCR 추가]
    _transform.dispose(); // [OCR 추가]
    super.dispose(); // [OCR 추가]
  } // [OCR 추가]

  Future<void> _load() async {
    // [OCR 추가]
    // [OCR 추가]
    try {
      // [OCR 추가]
      // [OCR 추가]
      final bytes = // [OCR 추가]
          widget.photoBytes ?? // [OCR 추가]
          await File(widget.photoPath).readAsBytes(); // [OCR 수정]
      final codec = await ui.instantiateImageCodec(bytes); // [OCR 추가]
      late final Size size; // [OCR 추가]
      try {
        // [OCR 추가]
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
        _bytes = bytes; // [OCR 추가]
        _size = size; // [OCR 추가]
        if (widget.initialBounds != null && widget.initialBounds!.isFinite) {
          // [OCR 추가]
          _bounds = _clamp(widget.initialBounds!); // [OCR 추가]
        } // [OCR 추가]
      }); // [OCR 추가]
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // [OCR 추가]
        // [OCR 추가]
        if (!mounted || _bounds == null || _viewport.currentContext == null) {
          // [OCR 추가]
          return; // [OCR 추가]
        } // [OCR 추가]
        final viewport = // [OCR 추가]
            _viewport.currentContext!.findRenderObject()! // [OCR 추가]
                as RenderBox; // [OCR 추가]
        final scale = viewport.size.width / size.width; // [OCR 추가]
        final offset =
            (_bounds!.center.dy * scale - viewport.size.height / 2) // [OCR 추가]
                .clamp(
                  // [OCR 추가]
                  0.0, // [OCR 추가]
                  math.max(
                    0.0,
                    size.height * scale - viewport.size.height,
                  ), // [OCR 추가]
                ); // [OCR 추가]
        _transform.value = Matrix4.translationValues(
          // [OCR 추가]
          0, // [OCR 추가]
          -offset.toDouble(), // [OCR 추가]
          0, // [OCR 추가]
        ); // [OCR 추가]
      }); // [OCR 추가]
    } catch (_) {
      // [OCR 추가]
      if (mounted) {
        // [OCR 추가]
        setState(() {
          // [OCR 추가]
          _loadFailed = true; // [OCR 추가]
          _notice = '사진을 열지 못했어요. 이전 화면에서 직접 입력해주세요.'; // [OCR 추가]
        }); // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]

  Rect _clamp(Rect rect) {
    // [OCR 추가]
    // [OCR 추가]
    final size = _size!; // [OCR 추가]
    final width = rect
        .width // [OCR 추가]
        .clamp(math.min(2.0, size.width), size.width) // [OCR 추가]
        .toDouble(); // [OCR 추가]
    final height = rect
        .height // [OCR 추가]
        .clamp(math.min(2.0, size.height), size.height) // [OCR 추가]
        .toDouble(); // [OCR 추가]
    return Rect.fromLTWH(
      // [OCR 추가]
      rect.left.clamp(0.0, size.width - width).toDouble(), // [OCR 추가]
      rect.top.clamp(0.0, size.height - height).toDouble(), // [OCR 추가]
      width, // [OCR 추가]
      height, // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  // [OCR 추가] 이유: 화면 확대·이동과 손잡이 이동을 모두 역변환해 원본 좌표에서 계산한다.
  Offset _sourcePoint(Offset global) {
    // [OCR 추가]
    // [OCR 추가]
    final viewport = // [OCR 추가]
        _viewport.currentContext!.findRenderObject()! as RenderBox; // [OCR 추가]
    return _transform.toScene(viewport.globalToLocal(global)) / // [OCR 추가]
        (viewport.size.width / _size!.width); // [OCR 추가]
  } // [OCR 추가]

  void _change(Rect bounds) {
    // [OCR 추가]
    // [OCR 추가]
    setState(() {
      // [OCR 추가]
      // [OCR 추가]
      _bounds = _clamp(bounds); // [OCR 추가]
      _revision++; // [OCR 추가]
      _reading = false; // [OCR 추가]
      _readingBounds = null; // [OCR 추가]
      _retryBounds = null; // [OCR 추가]
      _attempts = 0; // [OCR 추가]
      _candidates.clear(); // [OCR 추가]
      _text.clear(); // [OCR 추가]
      _notice = '영역이 바뀌었어요. 다시 읽거나 직접 입력해주세요.'; // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  void _dragStart(DragStartDetails details) {
    // [OCR 추가]
    _dragBounds = _bounds; // [OCR 추가]
    _dragPoint = _sourcePoint(details.globalPosition); // [OCR 추가]
  } // [OCR 추가]

  void _dragUpdate(DragUpdateDetails details, [int? corner]) {
    // [OCR 추가]
    // [OCR 추가]
    if (_dragBounds == null || _dragPoint == null) return; // [OCR 추가]
    final delta = // [OCR 추가]
        _sourcePoint(details.globalPosition) - _dragPoint!; // [OCR 추가]
    final bounds = _dragBounds!; // [OCR 추가]
    if (corner == null) {
      // [OCR 추가]
      _change(bounds.shift(delta)); // [OCR 추가]
      return; // [OCR 추가]
    } // [OCR 추가]
    final left =
        corner
            .isEven // [OCR 추가]
        ? (bounds.left + delta.dx)
              .clamp(0.0, bounds.right - 2)
              .toDouble() // [OCR 추가]
        : bounds.left; // [OCR 추가]
    final right =
        corner
            .isOdd // [OCR 추가]
        ? (bounds.right + delta.dx) // [OCR 추가]
              .clamp(bounds.left + 2, _size!.width) // [OCR 추가]
              .toDouble() // [OCR 추가]
        : bounds.right; // [OCR 추가]
    final top =
        corner <
            2 // [OCR 추가]
        ? (bounds.top + delta.dy)
              .clamp(0.0, bounds.bottom - 2)
              .toDouble() // [OCR 추가]
        : bounds.top; // [OCR 추가]
    final bottom =
        corner >=
            2 // [OCR 추가]
        ? (bounds.bottom + delta.dy) // [OCR 추가]
              .clamp(bounds.top + 2, _size!.height) // [OCR 추가]
              .toDouble() // [OCR 추가]
        : bounds.bottom; // [OCR 추가]
    _change(Rect.fromLTRB(left, top, right, bottom)); // [OCR 추가]
  } // [OCR 추가]

  String? _validate(String? input) => receiptRegionValueError(
    // [OCR 추가]
    input ?? '',
    numeric: widget.numeric,
    quantity: widget.quantity, // [OCR 추가]
    date: widget.date, // [OCR 추가]
  ); // [OCR 추가]

  void _chooseCandidate(ReceiptRegionCandidate candidate) {
    // [OCR 추가]
    setState(() {
      // [OCR 추가]
      _bounds = candidate.bounds; // [OCR 추가]
      _text.text = candidate.text; // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  Future<void> _read() async {
    // [OCR 추가]
    if (_recognitionBusy || _bounds == null || _bytes == null) {
      // [OCR 수정]
      return; // [OCR 수정]
    } // [OCR 수정]
    final revision = ++_revision; // [OCR 추가]
    final base = _retryBounds ??= _bounds!; // [OCR 추가]
    final firstAttempt = _attempts; // [OCR 추가]
    setState(() {
      // [OCR 추가]
      _recognitionBusy = true; // [OCR 추가]
      _reading = true; // [OCR 추가]
      _candidates.clear(); // [OCR 추가]
      _text.clear(); // [OCR 추가]
      _notice = '$_attempts회 인식 · 성공 0회'; // [OCR 추가]
    }); // [OCR 추가]
    try {
      // [OCR 추가]
      final result = await readReceiptRegionRepeatedly(
        // [OCR 추가]
        photoBytes: _bytes!,
        photoSize: _size!,
        bounds: base, // [OCR 추가]
        recognize: widget.recognize ?? OcrService().recognizeRegion, // [OCR 추가]
        isCurrent: () => mounted && revision == _revision, // [OCR 추가]
        numeric: widget.numeric,
        quantity: widget.quantity,
        date: widget.date, // [OCR 추가]
        firstAttempt: firstAttempt, // [OCR 추가]
        onAttempt: (bounds, attempts, successes) {
          // [OCR 추가]
          setState(() {
            // [OCR 추가]
            _readingBounds = bounds; // [OCR 추가]
            _attempts = firstAttempt + attempts; // [OCR 추가]
            _notice = '$_attempts회 인식 · 성공 $successes회'; // [OCR 추가]
          }); // [OCR 추가]
        }, // [OCR 추가]
      ); // [OCR 추가]
      if (!mounted || revision != _revision || result == null) {
        // [OCR 수정]
        return; // [OCR 수정]
      } // [OCR 수정]
      setState(() {
        // [OCR 추가]
        _readingBounds = null; // [OCR 추가]
        _candidates.addAll(result.candidates); // [OCR 수정]
        if (result.candidates.isNotEmpty) {
          // [OCR 추가]
          _bounds = result.candidates.first.bounds; // [OCR 추가]
          _text.text = result.candidates.first.text; // [OCR 추가]
        } // [OCR 추가]
        // [OCR 추가] 실패한 이전 숫자는 복원하지 않고 이번에 실제로 읽힌 후보만 제시한다.
        _notice =
            result
                .candidates
                .isEmpty // [OCR 추가]
            ? '$_attempts회 인식 · 읽지 못했어요. 다시 읽거나 직접 입력해주세요.' // [OCR 추가]
            : '$_attempts회 인식 · 성공 ${result.successes}회'; // [OCR 추가]
      }); // [OCR 추가]
    } finally {
      // [OCR 추가]
      if (mounted) {
        // [OCR 추가]
        setState(() {
          // [OCR 추가]
          _recognitionBusy = false; // [OCR 추가]
          if (revision == _revision) _reading = false; // [OCR 추가]
        }); // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]

  List<ReceiptRegionCandidate> get _rankedCandidates => // [OCR 수정]
      _candidates.take(3).toList(); // [OCR 수정]

  Widget _photo() => LayoutBuilder(
    // [OCR 추가]
    builder: (context, constraints) {
      // [OCR 추가]
      // [OCR 추가]
      final scale = constraints.maxWidth / _size!.width; // [OCR 추가]
      final displayBounds = _readingBounds ?? _bounds; // [OCR 추가]
      final rect =
          displayBounds ==
              null // [OCR 추가]
          ? null // [OCR 추가]
          : Rect.fromLTRB(
              // [OCR 추가]
              displayBounds.left * scale, // [OCR 추가]
              displayBounds.top * scale, // [OCR 추가]
              displayBounds.right * scale, // [OCR 추가]
              displayBounds.bottom * scale, // [OCR 추가]
            ); // [OCR 추가]
      return ClipRect(
        // [OCR 추가]
        child: SizedBox.expand(
          // [OCR 추가]
          key: _viewport, // [OCR 추가]
          child: Stack(
            // [OCR 추가]
            children: [
              // [OCR 추가]
              // [OCR 추가]
              InteractiveViewer(
                // [OCR 추가]
                key: const ValueKey('region-photo'), // [OCR 추가]
                transformationController: _transform, // [OCR 추가]
                constrained: false, // [OCR 추가]
                alignment: Alignment.topLeft, // [OCR 추가]
                minScale: 1, // [OCR 추가]
                maxScale: 6, // [OCR 추가]
                child: GestureDetector(
                  // [OCR 추가]
                  key: const ValueKey('region-canvas'), // [OCR 추가]
                  behavior: HitTestBehavior.opaque, // [OCR 추가]
                  onTapUp: (details) {
                    // [OCR 추가]
                    // [OCR 추가]
                    final point = _sourcePoint(
                      // [OCR 추가]
                      details.globalPosition, // [OCR 추가]
                    ); // [OCR 추가]
                    _change(
                      // [OCR 추가]
                      Rect.fromCenter(
                        // [OCR 추가]
                        center: point, // [OCR 추가]
                        width: // [OCR 추가]
                            _bounds?.width ?? // [OCR 추가]
                            _size!.width *
                                (widget.numeric ? .1 : .35), // [OCR 추가]
                        height:
                            _bounds?.height ?? _size!.width * .06, // [OCR 추가]
                      ), // [OCR 추가]
                    ); // [OCR 추가]
                  }, // [OCR 추가]
                  child: SizedBox(
                    // [OCR 추가]
                    width: constraints.maxWidth, // [OCR 추가]
                    height: _size!.height * scale, // [OCR 추가]
                    child: Image.memory(_bytes!, fit: BoxFit.fill), // [OCR 추가]
                  ), // [OCR 추가]
                ), // [OCR 추가]
              ), // [OCR 추가]
              // [OCR 추가] 이유: 이동 손잡이는 사진 확대 제스처와 경쟁하지 않는 별도 레이어로 표시한다.
              AnimatedBuilder(
                animation: _transform, // [OCR 수정]
                builder: (context, child) {
                  // [OCR 수정] 긴 사진을 이동해도 화면에 보이는 손잡이의 터치 영역이 사진 밖으로 잘리지 않게 한다.
                  final screenRect = rect == null
                      ? null
                      : MatrixUtils.transformRect(_transform.value, rect);
                  return Stack(
                    clipBehavior: Clip.none, // [OCR 수정]
                    children: [
                      if (screenRect != null) ...[
                        // [OCR 추가]
                        // [OCR 추가]
                        Positioned.fromRect(
                          // [OCR 추가]
                          rect: screenRect, // [OCR 추가]
                          child: GestureDetector(
                            // [OCR 추가]
                            key: const ValueKey('region-box'), // [OCR 추가]
                            behavior: HitTestBehavior.opaque, // [OCR 추가]
                            onPanStart: _dragStart, // [OCR 추가]
                            onPanUpdate: _dragUpdate, // [OCR 추가]
                            child: DecoratedBox(
                              // [OCR 추가]
                              decoration: BoxDecoration(
                                // [OCR 추가]
                                color: Colors.green.withValues(
                                  alpha: .05,
                                ), // [OCR 추가]
                                border: Border.all(
                                  // [OCR 추가]
                                  color: Colors.green, // [OCR 추가]
                                  width: 1, // [OCR 추가]
                                ), // [OCR 추가]
                              ), // [OCR 추가]
                            ), // [OCR 추가]
                          ), // [OCR 추가]
                        ), // [OCR 추가]
                        for (var corner = 0; corner < 4; corner++) // [OCR 추가]
                          Positioned(
                            // [OCR 추가]
                            // [OCR 수정] fresh처럼 손잡이를 각 모서리 바깥에 둔다. 작은 수량 박스 안에 겹치면 마지막 손잡이가 다른 모서리의 터치를 가로챈다.
                            left: // [OCR 추가]
                            corner.isEven
                                ? screenRect.left -
                                      28 // [OCR 수정]
                                : screenRect.right, // [OCR 수정]
                            top: // [OCR 추가]
                            corner < 2
                                ? screenRect.top -
                                      28 // [OCR 수정]
                                : screenRect.bottom, // [OCR 수정]
                            child: GestureDetector(
                              // [OCR 추가]
                              key: ValueKey(
                                'region-handle-$corner',
                              ), // [OCR 추가]
                              behavior: HitTestBehavior.opaque, // [OCR 추가]
                              onPanStart: _dragStart, // [OCR 추가]
                              onPanUpdate:
                                  (details) => // [OCR 추가]
                                      _dragUpdate(details, corner), // [OCR 추가]
                              // [OCR 수정] 사진 위에서도 보이는 불투명 배경과 테두리를 사용하고 작은 박스의 글자는 가리지 않는다.
                              child: SizedBox(
                                // [OCR 수정]
                                width: 28, // [OCR 수정]
                                height: 28, // [OCR 수정]
                                child: DecoratedBox(
                                  // [OCR 수정]
                                  decoration: BoxDecoration(
                                    // [OCR 수정]
                                    color: AppColors.surface, // [OCR 수정]
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 2,
                                    ), // [OCR 수정]
                                    borderRadius: BorderRadius.circular(
                                      4,
                                    ), // [OCR 수정]
                                    boxShadow: const [
                                      // [OCR 추가]
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ), // [OCR 추가]
                                    ], // [OCR 추가]
                                  ), // [OCR 수정]
                                  child: const Icon(
                                    Icons.open_in_full,
                                    size: 16,
                                    color: AppColors.primary,
                                  ), // [OCR 수정]
                                ), // [OCR 수정]
                              ), // [OCR 수정]
                            ), // [OCR 추가]
                          ), // [OCR 추가]
                      ], // [OCR 추가]
                    ], // [OCR 수정]
                  ); // [OCR 수정]
                }, // [OCR 수정]
              ), // [OCR 추가]
            ], // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ); // [OCR 추가]
    }, // [OCR 추가]
  ); // [OCR 추가]
  @override // [OCR 추가]
  Widget build(BuildContext context) => Scaffold(
    // [OCR 추가]
    // [OCR 추가]
    appBar: AppBar(
      // [OCR 추가]
      leading: const DesignBackButton(), // [OCR 추가]
      title: Text('${widget.label} 영역'), // [OCR 추가]
    ), // [OCR 추가]
    body: SafeArea(
      // [OCR 추가]
      child: Column(
        // [OCR 추가]
        children: [
          // [OCR 추가]
          // [OCR 추가]
          Expanded(
            // [OCR 추가]
            flex: 3, // [OCR 추가]
            child:
                _loadFailed // [OCR 추가]
                ? Center(child: Text(_notice)) // [OCR 추가]
                : _size ==
                      null // [OCR 추가]
                ? const Center(child: CircularProgressIndicator()) // [OCR 추가]
                : _photo(), // [OCR 추가]
          ), // [OCR 추가]
          Flexible(
            // [OCR 추가]
            flex: 2, // [OCR 추가]
            child: SingleChildScrollView(
              // [OCR 추가]
              padding: const EdgeInsets.all(16), // [OCR 추가]
              child: Form(
                // [OCR 추가]
                key: _form, // [OCR 추가]
                child: Column(
                  // [OCR 추가]
                  mainAxisSize: MainAxisSize.min, // [OCR 추가]
                  children: [
                    // [OCR 추가]
                    // [OCR 추가]
                    if (_notice.isNotEmpty) Text(_notice), // [OCR 추가]
                    if (!_reading && _candidates.isNotEmpty) // [OCR 추가]
                      Wrap(
                        // [OCR 추가]
                        spacing: 8, // [OCR 추가]
                        children: [
                          // [OCR 추가]
                          for (final candidate in _rankedCandidates) // [OCR 추가]
                            OutlinedButton(
                              // [OCR 추가]
                              key: ValueKey(
                                'region-candidate-${_rankedCandidates.indexOf(candidate)}',
                              ), // [OCR 추가]
                              onPressed: () =>
                                  _chooseCandidate(candidate), // [OCR 추가]
                              child: Text(
                                '${candidate.text} (${candidate.hits}회)',
                              ), // [OCR 추가]
                            ), // [OCR 추가]
                        ], // [OCR 추가]
                      ), // [OCR 추가]
                    TextFormField(
                      // [OCR 추가]
                      key: const ValueKey('region-value'), // [OCR 추가]
                      controller: _text, // [OCR 추가]
                      enabled: !_reading, // [OCR 추가]
                      validator: _validate, // [OCR 추가]
                      keyboardType:
                          widget
                              .numeric // [OCR 추가]
                          ? TextInputType
                                .number // [OCR 추가]
                          : TextInputType.text, // [OCR 추가]
                      decoration: InputDecoration(
                        labelText: widget.label,
                      ), // [OCR 추가]
                    ), // [OCR 추가]
                    const SizedBox(height: 8), // [OCR 추가]
                    Row(
                      // [OCR 추가]
                      children: [
                        // [OCR 추가]
                        // [OCR 추가]
                        Expanded(
                          // [OCR 추가]
                          child: OutlinedButton(
                            // [OCR 추가]
                            onPressed:
                                _bounds == null ||
                                    _recognitionBusy // [OCR 수정]
                                ? null // [OCR 추가]
                                : _read, // [OCR 추가]
                            child: Text(
                              _reading ? '읽는 중…' : '영역 다시 읽기',
                            ), // [OCR 추가]
                          ), // [OCR 추가]
                        ), // [OCR 추가]
                        const SizedBox(width: 8), // [OCR 추가]
                        Expanded(
                          // [OCR 추가]
                          child: FilledButton(
                            // [OCR 추가]
                            onPressed:
                                _bounds == null ||
                                    _reading // [OCR 추가]
                                ? null // [OCR 추가]
                                : () {
                                    // [OCR 추가]
                                    if (_form.currentState!.validate()) {
                                      // [OCR 추가]
                                      Navigator.pop(
                                        // [OCR 추가]
                                        context, // [OCR 추가]
                                        ReceiptRegionValue(
                                          // [OCR 추가]
                                          _bounds!, // [OCR 추가]
                                          widget.date
                                              ? receiptRegionDate(_text.text)!
                                              : _text.text.trim(), // [OCR 수정]
                                        ), // [OCR 추가]
                                      ); // [OCR 추가]
                                    } // [OCR 추가]
                                  }, // [OCR 추가]
                            child: const Text('적용'), // [OCR 추가]
                          ), // [OCR 추가]
                        ), // [OCR 추가]
                      ], // [OCR 추가]
                    ), // [OCR 추가]
                  ], // [OCR 추가]
                ), // [OCR 추가]
              ), // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ], // [OCR 추가]
      ), // [OCR 추가]
    ), // [OCR 추가]
  ); // [OCR 추가]
} // [OCR 추가]
