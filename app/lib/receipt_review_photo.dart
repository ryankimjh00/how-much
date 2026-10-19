import 'receipt_image.dart'; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'package:flutter/gestures.dart'; // [OCR 추가]
import 'package:flutter/material.dart'; // [OCR 추가]
import 'receipt_ocr.dart'; // [OCR 추가]

/// [OCR 추가] 원본 사진 좌표로 상품명·금액 박스를 그린다. 확대 제스처는 고정된 사진 안에서만 처리한다.
class ReceiptReviewPhoto extends StatefulWidget {
  // [OCR 추가]
  // [OCR 추가]
  const ReceiptReviewPhoto({
    // [OCR 추가]
    super.key, // [OCR 추가]
    required this.path, // [OCR 추가]
    this.photoBytes, // [OCR 추가]
    required this.regions, // [OCR 추가]
    this.onInteractionChanged, // [OCR 추가]
  }); // [OCR 추가]
  final ValueChanged<bool>? onInteractionChanged; // [OCR 추가]
  final Uint8List? photoBytes; // [OCR 추가]
  final String path; // [OCR 추가]
  final List<ReceiptOcrCandidate> regions; // [OCR 추가]
  @override // [OCR 추가]
  State<ReceiptReviewPhoto> createState() => _ReceiptReviewPhotoState(); // [OCR 추가]
} // [OCR 추가]

class _ReceiptReviewPhotoState extends State<ReceiptReviewPhoto> {
  // [OCR 추가] fresh처럼 실제 접점이 모두 끝난 뒤에만 목록 잠금을 해제한다. 취소·터치패드 종료도 같은 방식으로 처리한다.
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
    widget.onInteractionChanged?.call(_photoPointers.isNotEmpty); // [OCR 추가]
  } // [OCR 추가]

  @override // [OCR 추가]
  void dispose() {
    // [OCR 추가]
    // [OCR 추가]
    _transform.dispose(); // [OCR 추가]
    super.dispose(); // [OCR 추가]
  } // [OCR 추가]

  // [OCR 추가]
  // [OCR 추가]
  Uint8List? _bytes; // [OCR 추가]
  Size? _size; // [OCR 추가]
  bool _failed = false; // [OCR 추가]
  @override // [OCR 추가]
  void initState() {
    // [OCR 추가]
    super.initState(); // [OCR 추가]
    _load(); // [OCR 추가]
  } // [OCR 추가]

  Future<void> _load() async {
    // [OCR 추가]
    // [OCR 추가]
    try {
      // [OCR 추가]
      // [OCR 추가]
      // [OCR 수정] 인식에 사용한 사진 바이트를 우선 읽어 초록 박스와 사진의 좌표 기준을 맞춘다.
      // 사진을 못 읽어도 목록은 수정할 수 있도록 오류 안내는 이 위젯에서 따로 처리한다.
      final photo = await loadReceiptPhoto(
        // [OCR 수정]
        widget.path,
        photoBytes: widget.photoBytes,
      );
      if (!mounted) return; // [OCR 추가]
      final bytes = photo.bytes; // [OCR 수정]
      final size = photo.size; // [OCR 수정]
      setState(() {
        // [OCR 추가]
        _bytes = bytes; // [OCR 추가]
        _size = size; // [OCR 추가]
      }); // [OCR 추가]
    } catch (_) {
      // [OCR 추가]
      if (mounted) setState(() => _failed = true); // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]

  @override // [OCR 추가]
  Widget build(BuildContext context) {
    // [OCR 추가]
    // [OCR 추가]
    if (_failed) {
      // [OCR 추가]
      // [OCR 추가]
      return const Center(
        // [OCR 추가]
        child: Text('사진을 열지 못했어요. 아래 항목은 수정할 수 있어요.'), // [OCR 추가]
      ); // [OCR 추가]
    } // [OCR 추가]
    if (_size == null) {
      // [OCR 추가]
      // [OCR 추가]
      return const Center(child: CircularProgressIndicator()); // [OCR 추가]
    } // [OCR 추가]
    return LayoutBuilder(
      // [OCR 추가]
      builder: (context, constraints) {
        // [OCR 추가]
        // [OCR 추가]
        // [OCR 수정] fresh처럼 가로폭에 맞춘다. 긴 영수증을 전체 축소하면 기본 배율에서 이동할 여지가 없어진다.
        final scale = constraints.maxWidth / _size!.width; // [OCR 수정]
        return Listener(
          // [OCR 추가]
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
              // [OCR 추가]
              width: _size!.width * scale, // [OCR 추가]
              height: _size!.height * scale, // [OCR 추가]
              child: Stack(
                // [OCR 추가]
                // [OCR 추가]
                children: [
                  // [OCR 추가]
                  // [OCR 추가]
                  // [OCR 추가]
                  Positioned.fill(
                    // [OCR 추가]
                    // [OCR 추가]
                    child: Image.memory(_bytes!, fit: BoxFit.fill), // [OCR 추가]
                  ), // [OCR 추가]
                  for (final region in {
                    // [OCR 추가]
                    // [OCR 추가]
                    for (final region in widget.regions) // [OCR 추가]
                      region.id: region, // [OCR 추가]
                  }.values) // [OCR 추가]
                    Positioned(
                      // [OCR 추가]
                      // [OCR 추가]
                      key: ValueKey('review-region-${region.id}'), // [OCR 추가]
                      left: region.bounds.left * scale, // [OCR 추가]
                      top: region.bounds.top * scale, // [OCR 추가]
                      width: region.bounds.width * scale, // [OCR 추가]
                      height: region.bounds.height * scale, // [OCR 추가]
                      child: IgnorePointer(
                        // [OCR 추가]
                        // [OCR 추가]
                        child: DecoratedBox(
                          // [OCR 추가]
                          // [OCR 추가]
                          decoration: BoxDecoration(
                            // [OCR 추가]
                            // [OCR 추가]
                            border: Border.all(
                              // [OCR 추가]
                              color: Colors.green, // [OCR 추가]
                              width: 1, // [OCR 추가]
                            ), // [OCR 추가]
                          ), // [OCR 추가]
                        ), // [OCR 추가]
                      ), // [OCR 추가]
                    ), // [OCR 추가]
                ], // [OCR 추가]
              ), // [OCR 추가]
            ), // [OCR 수정]
          ), // [OCR 추가]
        ); // [OCR 추가]
      }, // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]
} // [OCR 추가]
