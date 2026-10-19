import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'app_theme.dart'; // [OCR 추가]
import 'receipt_perspective.dart'; // [OCR 추가]

/// [OCR 추가] 원본 사진 위에서 자동 모서리를 확인·조정하고 적용한 사진만 반환한다. 뒤로 가면 취소한다.
class ReceiptPerspectiveScreen extends StatefulWidget {
  // [OCR 추가]
  const ReceiptPerspectiveScreen({super.key, required this.bytes}); // [OCR 추가]
  final Uint8List bytes; // [OCR 추가]
  @override // [OCR 추가]
  State<ReceiptPerspectiveScreen> createState() =>
      _ReceiptPerspectiveScreenState(); // [OCR 추가]
} // [OCR 추가]

class _ReceiptPerspectiveScreenState extends State<ReceiptPerspectiveScreen> {
  // [OCR 추가]
  ui.Size? _size; // [OCR 추가]
  List<Offset> _corners = []; // [OCR 추가]
  bool _busy = true; // [OCR 추가]
  String? _error; // [OCR 추가]
  @override // [OCR 추가]
  void initState() {
    super.initState();
    _detect();
  } // [OCR 추가]

  List<Offset> _fullCorners(ui.Size size) => [
    Offset.zero, Offset(size.width - 1, 0), // [OCR 추가]
    Offset(size.width - 1, size.height - 1), Offset(0, size.height - 1),
  ]; // [OCR 추가]
  Future<void> _detect() async {
    // [OCR 추가]
    setState(() {
      _busy = true;
      _error = null;
    }); // [OCR 추가]
    try {
      // [OCR 추가]
      final result = await findReceiptCorners(widget.bytes); // [OCR 추가]
      if (!mounted) return; // [OCR 추가]
      setState(() {
        // [OCR 추가]
        _size = result.size; // [OCR 추가]
        _corners = result.corners ?? _fullCorners(result.size); // [OCR 추가]
        _error = result.corners == null ? '모서리를 직접 맞춰주세요.' : null; // [OCR 추가]
      }); // [OCR 추가]
    } catch (_) {
      // [OCR 추가]
      if (mounted) {
        // [OCR 추가]
        setState(() => _error = '사진을 열지 못했어요. 원본으로 진행할 수 있어요.'); // [OCR 추가]
      } // [OCR 추가]
    } finally {
      if (mounted) setState(() => _busy = false);
    } // [OCR 추가]
  } // [OCR 추가]

  Future<void> _apply() async {
    // [OCR 추가]
    if (_busy || _size == null) return; // [OCR 추가]
    if (!validReceiptCorners(_corners, _size!)) {
      // [OCR 추가]
      setState(() => _error = '네 모서리가 교차하지 않도록 맞춰주세요.'); // [OCR 추가]
      return; // [OCR 추가]
    } // [OCR 추가]
    setState(() {
      _busy = true;
      _error = null;
    }); // [OCR 추가]
    try {
      // [OCR 추가]
      final bytes = await correctReceiptPerspective(
        widget.bytes,
        List.of(_corners),
      ); // [OCR 추가]
      if (mounted) Navigator.pop(context, bytes); // [OCR 추가]
    } catch (_) {
      // [OCR 추가]
      if (mounted) {
        // [OCR 추가]
        setState(
          () => _error = '보정하지 못했어요. 영역을 다시 맞추거나 원본으로 진행해주세요.',
        ); // [OCR 추가]
      } // [OCR 추가]
    } finally {
      if (mounted) setState(() => _busy = false);
    } // [OCR 추가]
  } // [OCR 추가]

  @override // [OCR 추가]
  Widget build(BuildContext context) => PopScope(
    // [OCR 추가]
    canPop: !_busy, // [OCR 추가]
    child: Scaffold(
      // [OCR 추가]
      appBar: AppBar(title: const Text('영수증 모양 보정')), // [OCR 추가]
      body: SafeArea(
        child: Column(
          children: [
            // [OCR 추가]
            Expanded(
              child: _size == null
                  ? Center(
                      child: _busy
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.broken_image_outlined),
                    ) // [OCR 수정]
                  : // [OCR 추가]
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // [OCR 추가]
                        final fitted = applyBoxFit(
                          BoxFit.contain,
                          _size!,
                          Size(
                            constraints.maxWidth - 48,
                            constraints.maxHeight - 48,
                          ),
                        ).destination; // [OCR 추가]
                        return Center(
                          child: SizedBox(
                            width: fitted.width,
                            height: fitted.height, // [OCR 추가]
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // [OCR 추가]
                                Positioned.fill(
                                  child: Image.memory(
                                    widget.bytes,
                                    fit: BoxFit.fill,
                                  ),
                                ), // [OCR 추가]
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _CornersPainter(
                                        _corners,
                                        _size!,
                                      ),
                                    ),
                                  ),
                                ), // [OCR 추가]
                                for (
                                  var index = 0;
                                  index < 4;
                                  index++
                                ) // [OCR 추가]
                                  Positioned(
                                    left:
                                        _corners[index].dx /
                                            _size!.width *
                                            fitted.width -
                                        22, // [OCR 추가]
                                    top:
                                        _corners[index].dy /
                                            _size!.height *
                                            fitted.height -
                                        22, // [OCR 추가]
                                    child: GestureDetector(
                                      key: ValueKey(
                                        'perspective-corner-$index',
                                      ), // [OCR 추가]
                                      behavior:
                                          HitTestBehavior.opaque, // [OCR 추가]
                                      onPanUpdate: _busy
                                          ? null
                                          : (details) => setState(() {
                                              // [OCR 추가]
                                              final point =
                                                  _corners[index] +
                                                  Offset(
                                                    details.delta.dx *
                                                        _size!.width /
                                                        fitted
                                                            .width, // [OCR 추가]
                                                    details.delta.dy *
                                                        _size!.height /
                                                        fitted.height,
                                                  ); // [OCR 추가]
                                              _corners[index] = Offset(
                                                point.dx.clamp(
                                                  0,
                                                  _size!.width - 1,
                                                ),
                                                point.dy.clamp(
                                                  0,
                                                  _size!.height - 1,
                                                ),
                                              ); // [OCR 추가]
                                              _error = null; // [OCR 추가]
                                            }), // [OCR 추가]
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          // [OCR 추가]
                                          color: AppColors.surface,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.primary,
                                            width: 2,
                                          ),
                                        ), // [OCR 추가]
                                        child: Icon(
                                          Icons.open_with,
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ), // [OCR 추가]
                              ],
                            ),
                          ),
                        ); // [OCR 추가]
                      },
                    ),
            ), // [OCR 추가]
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!),
              ), // [OCR 추가]
            if (_busy) const LinearProgressIndicator(), // [OCR 추가]
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  // [OCR 추가]
                  TextButton(
                    onPressed: _busy ? null : _detect,
                    child: const Text('자동 찾기'),
                  ), // [OCR 추가]
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(context, widget.bytes),
                    child: const Text('원본 사용'),
                  ), // [OCR 추가]
                  FilledButton(
                    onPressed: _busy || _size == null ? null : _apply,
                    child: const Text('보정 적용'),
                  ), // [OCR 추가]
                ],
              ),
            ), // [OCR 추가]
          ],
        ),
      ), // [OCR 추가]
    ), // [OCR 추가]
  ); // [OCR 추가]
} // [OCR 추가]

class _CornersPainter extends CustomPainter {
  // [OCR 추가]
  _CornersPainter(this.corners, this.photoSize); // [OCR 추가]
  final List<Offset> corners; // [OCR 추가]
  final ui.Size photoSize; // [OCR 추가]
  @override // [OCR 추가]
  void paint(Canvas canvas, Size size) {
    // [OCR 추가]
    final path = Path(); // [OCR 추가]
    for (var index = 0; index < corners.length; index++) {
      // [OCR 추가]
      final point = Offset(
        corners[index].dx / photoSize.width * size.width,
        corners[index].dy / photoSize.height * size.height,
      ); // [OCR 추가]
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      } // [OCR 추가]
    } // [OCR 추가]
    path.close(); // [OCR 추가]
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    ); // [OCR 추가]
  } // [OCR 추가]

  @override // [OCR 추가]
  bool shouldRepaint(covariant _CornersPainter oldDelegate) => true; // [OCR 추가]
} // [OCR 추가]
