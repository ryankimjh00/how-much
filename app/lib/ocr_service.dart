import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';

class OcrService {
  final ImagePicker _picker = ImagePicker();

  Future<ReceiptDraft?> pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (image == null) return null;
    return recognizePath(image.path);
  }

  Future<List<MemoLineDraft>?> pickMemo(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (image == null) return null;
    return recognizeMemoPath(image.path);
  }

  Future<List<MemoLineDraft>> recognizeMemoPath(String path) async {
    final lines = parseMemoText(await _recognizeText(path));
    if (lines.isEmpty) {
      throw const FormatException('메모에서 상품을 찾지 못했어요. 다시 촬영하거나 직접 입력해주세요.');
    }
    return lines;
  }

  Future<ReceiptDraft> recognizePath(String path) async {
    final draft = parseReceiptText(
      await _recognizeText(path),
      id: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    if (draft.lines.isEmpty) {
      throw const FormatException('영수증을 읽지 못했어요. 다시 촬영하거나 직접 입력해주세요.');
    }
    return draft;
  }

  Future<String> _recognizeText(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
