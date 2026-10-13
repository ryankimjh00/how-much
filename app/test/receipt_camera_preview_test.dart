// [OCR 추가] 모의 카메라·OCR로 미리보기 정지와 취소/실패 후 촬영 복귀를 확인한다.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// [OCR 추가] 이미 설치된 camera의 플랫폼 시험 API만 사용하며 패키지를 추가하지 않는다.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:how_much/app_store.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/screens.dart';
import 'package:how_much/receipt_text_recognizer.dart';
import 'package:how_much/receipt_selection_screen.dart';
import 'receipt_pages_test.dart' show mockReceiptGallery, paddlePageResponse;
import 'receipt_region_test.dart' show regionPhoto;

class PreviewCamera extends CameraPlatform {
  final calls = <String>[];
  final errors = StreamController<CameraErrorEvent>.broadcast();
  @override
  Future<List<CameraDescription>> availableCameras() async => [
    const CameraDescription(
      name: 'test',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    ),
  ];
  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings settings,
  ) async => 1;
  @override
  Future<void> initializeCamera(
    int id, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) => Stream.value(
    CameraInitializedEvent(
      id,
      640,
      480,
      ExposureMode.auto,
      true,
      FocusMode.auto,
      true,
    ),
  );
  @override
  Stream<CameraErrorEvent> onCameraError(int id) => errors.stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Widget buildPreview(int id) => const ColoredBox(color: Colors.black);
  @override
  Future<void> pausePreview(int id) async {
    calls.add('pause');
  }

  @override
  Future<void> resumePreview(int id) async {
    calls.add('resume');
  }

  @override
  Future<void> dispose(int id) async {
    calls.add('dispose');
  }
}

// [OCR 추가] 실제 파일 디코딩 동안 로딩 애니메이션의 가상 시계를 무한히 진행하지 않는다.
Future<void> waitForReceiptState(
  WidgetTester tester,
  bool Function() ready,
) async {
  for (var attempt = 0; attempt < 100 && !ready(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final outcome in [
    'correction-cancel',
    'selection-cancel',
    'ocr-error',
  ]) {
    testWidgets('보정·OCR 미리보기 정지와 촬영 복귀: $outcome', (tester) async {
      final path = await regionPhoto(tester, width: 900, height: 1800);
      final oldPlatform = CameraPlatform.instance;
      final camera = PreviewCamera();
      CameraPlatform.instance = camera;
      final store = AppStore(CloudService(false));
      addTearDown(() {
        CameraPlatform.instance = oldPlatform;
        store.dispose();
      });
      mockReceiptGallery(tester, () async => [path]);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        ReceiptTextRecognizer.channel,
        (call) async {
          if (call.method == 'close') return null;
          expect(camera.calls, [
            'pause',
          ]); // [OCR 추가] 실제 인식 전 정지하고 선택 취소까지 재생하지 않는다.
          if (outcome == 'ocr-error') {
            throw PlatformException(code: 'ocr-failed');
          }
          return paddlePageResponse();
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          ReceiptTextRecognizer.channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ReceiptCaptureScreen(store: store)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('앨범'));
      await waitForReceiptState(tester, () {
        final buttons = find.widgetWithText(TextButton, '원본 사용').evaluate();
        return buttons.isNotEmpty &&
            (buttons.single.widget as TextButton).onPressed != null;
      });
      expect(camera.calls, ['pause']);
      if (outcome == 'correction-cancel') {
        await tester.tap(find.byType(BackButton));
        await waitForReceiptState(
          tester,
          () => camera.calls.contains('resume'),
        );
      } else {
        await tester.tap(find.text('원본 사용'));
        await waitForReceiptState(
          tester,
          () => outcome == 'selection-cancel'
              ? find.byType(ReceiptSelectionScreen).evaluate().isNotEmpty
              : camera.calls.contains('resume'),
        );
        if (outcome == 'selection-cancel') {
          expect(find.byType(ReceiptSelectionScreen), findsOneWidget);
          expect(camera.calls, ['pause']);
          await tester.tap(find.byTooltip('뒤로'));
          await waitForReceiptState(
            tester,
            () => camera.calls.contains('resume'),
          );
        }
      }
      expect(camera.calls, ['pause', 'resume']);
      expect(find.byType(ReceiptCaptureScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(camera.calls.last, 'dispose');
      expect(tester.takeException(), isNull);
    });
  }
}
