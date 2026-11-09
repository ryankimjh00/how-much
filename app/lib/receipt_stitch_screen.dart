import 'dart:typed_data';
import 'package:flutter/material.dart';

/// [OCR 추가] OCR 전에 연결 결과를 확인한다. 취소하면 촬영 목록과 장별 선택을 유지한다.
class ReceiptStitchPreviewScreen extends StatelessWidget {
  const ReceiptStitchPreviewScreen({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('이어붙인 영수증')),
    body: Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 8,
            child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, bytes),
                    child: const Text('이 사진으로 인식'),
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
