import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:how_much/app.dart';
import 'package:how_much/app_store.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/design_widgets.dart';
import 'package:how_much/models.dart';
import 'package:how_much/ocr_service.dart';
import 'package:how_much/screens.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('AI_ANT_PHASE', defaultValue: 'capture');
  const photoInput = String.fromEnvironment('AI_ANT_MEMO_PHOTO_BASE64');
  // 제출 검증용 가상 목록은 일반 앱의 기기 기록과 다른 저장 영역을 사용한다.
  SharedPreferences.setPrefix('ai_ant_submission_20261109.');

  testWidgets('제출 화면과 네이티브 저장·재시작을 검증한다', (tester) async {
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    final prefs = await SharedPreferences.getInstance();
    if (phase != 'restore') await prefs.clear();
    final store = AppStore(CloudService(false));
    addTearDown(store.dispose);
    await store.initialize();
    Future<void> settle() async {
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (!store.loading && !store.saving && !store.syncing) break;
      }
      expect(store.canEdit, isTrue);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(HowMuchApp(store: store));
    await settle();
    await binding.convertFlutterSurfaceToImage();
    await settle();

    Future<void> capture(String name) async {
      await settle();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot(name);
    }

    if (phase == 'ocr') {
      await tester.tap(find.text('손글씨 메모도 찍어서 추가해요'));
      await tester.pump(const Duration(seconds: 2));
      await capture('mp4_01_capture_or_select');
      await tester.tap(find.byTooltip('뒤로'));
      await settle();

      final fixture = await _recognizeMemoFixture(photoInput);
      final lines = fixture.lines;
      final recognizedTitles = lines.map((line) => line.title).toList();
      expect(recognizedTitles, containsAll(['우유', '계란', '두부']));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final reviewed = navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => MemoImportScreen(store: store, initialLines: lines),
        ),
      );
      await capture('mp4_02_candidates');
      final milkTile = find.widgetWithText(ListTile, '우유');
      final tofuTile = find.widgetWithText(ListTile, '두부');
      for (final tile in [milkTile, tofuTile]) {
        final checkbox = find.descendant(
          of: tile,
          matching: find.byType(DesignCheckbox),
        );
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await settle();
      }
      await Scrollable.ensureVisible(tester.element(milkTile), alignment: 0.3);
      await settle();
      await capture('mp4_03_selected');
      await tester.tap(
        find.descendant(of: milkTile, matching: find.byTooltip('품목 수정')),
      );
      await settle();
      await tester.enterText(find.byType(TextField).first, '저지방 우유');
      await tester.enterText(find.byType(TextField).at(1), '2');
      await tester.tap(find.text('적용'));
      await capture('mp4_04_edited');
      await tester.tap(find.text('2개를 장보기 목록에 담기'));
      await settle();
      expect(await reviewed, isTrue);
      expect(store.shoppingItems.map((item) => item.title), ['저지방 우유', '두부']);
      expect(store.shoppingItems.first.quantity, 2);
      await capture('mp4_05_imported_offline');
      binding.reportData = {
        ...?binding.reportData,
        'phase': phase,
        if (photoInput.isEmpty) 'fixturePngBase64': base64Encode(fixture.png),
        'input': photoInput.isEmpty
            ? '시험 코드가 생성한 인쇄체 가상 장보기 메모 PNG, 1200×1000px'
            : '저장소의 손글씨 장보기 회귀 표본 사진 JPG, 720×1280px',
        'physicalPaperPhoto': photoInput.isNotEmpty,
        'instructorProvidedFixture': false,
        'previousHandwrittenFailuresResolved': false,
        'recognizedTitles': recognizedTitles,
        'processingMilliseconds': fixture.milliseconds,
        'temporaryPhotoDeleted': true,
        'platform': Platform.operatingSystemVersion,
        'offlineTestRequested': const bool.fromEnvironment('AI_ANT_OFFLINE'),
      };
      return;
    }

    if (phase == 'restore') {
      expect(store.shoppingItems, hasLength(2));
      expect(
        store.shoppingItems
            .singleWhere((item) => item.title == '저지방 우유')
            .completed,
        isTrue,
      );
      expect(find.text('두부'), findsOneWidget);
      expect(find.text('계란'), findsNothing);
      await capture('mp2_09_after_restart');
      binding.reportData = {
        ...?binding.reportData,
        'phase': phase,
        'nativePersistenceVerified': true,
      };
      return;
    }

    expect(find.text('장보기 목록이 비었어요'), findsOneWidget);
    await capture('mp1_01_empty');
    await tester.enterText(find.byType(TextField).first, '우유');
    await capture('mp1_02_add');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
    for (final title in ['계란', '두부']) {
      await tester.enterText(find.byType(TextField).first, title);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
      expect(
        store.shoppingItems.any((item) => item.title == title),
        isTrue,
        reason:
            '$title 추가 후 목록: ${store.shoppingItems.map((item) => item.title)}',
      );
    }
    expect(store.shoppingItems, hasLength(3));
    await capture('mp1_03_list');
    await tester.tap(find.text('우유'));
    await settle();
    expect(store.completedCount, 1);
    await capture('mp1_04_completed');

    await tester.tap(find.byTooltip('우유 메뉴'));
    await settle();
    await tester.tap(find.text('수정'));
    await settle();
    await tester.enterText(find.byType(TextField).at(0), '저지방 우유');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.enterText(find.byType(TextField).at(2), '가상 장보기 목록');
    await capture('mp2_01_edit');
    await tester.tap(find.text('이대로 저장할게요'));
    await settle();
    expect(find.text('저지방 우유'), findsOneWidget);
    await capture('mp2_02_edited');

    await tester.tap(find.byTooltip('계란 메뉴'));
    await settle();
    await tester.tap(find.text('삭제'));
    await settle();
    await capture('mp2_03_delete_confirmation');
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await settle();
    expect(find.text('계란'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await capture('mp2_04_deleted');

    Future<void> selectFilter(String label) async {
      await tester.tap(find.byType(PopupMenuButton<ShoppingFilter>));
      await settle();
      await tester.tap(
        find.widgetWithText(PopupMenuItem<ShoppingFilter>, label),
      );
      await settle();
    }

    await selectFilter('완료');
    expect(find.text('저지방 우유'), findsOneWidget);
    expect(find.text('두부'), findsNothing);
    await capture('mp2_05_filter_completed');
    await selectFilter('살 것');
    expect(find.text('두부'), findsOneWidget);
    expect(find.text('저지방 우유'), findsNothing);
    await capture('mp2_06_filter_active');
    await selectFilter('전체');
    await capture('mp2_07_filter_all');
    await capture('mp2_08_before_restart');
    binding.reportData = {
      ...?binding.reportData,
      'phase': phase,
      'createToggleEditDeleteFiltersVerified': true,
      'visibleItems': store.shoppingItems.map((item) => item.title).toList(),
    };
  });
}

Future<({List<MemoLineDraft> lines, List<int> png, List<int> milliseconds})>
_recognizeMemoFixture(String photoInput) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  final text = TextPainter(
    text: const TextSpan(
      text: '우유 2개\n\n계란\n\n두부',
      style: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 72,
        height: 1.5,
        color: Colors.black,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 1000);
  text.paint(canvas, const Offset(100, 80));
  final picture = recorder.endRecording();
  final image = await picture.toImage(1200, 1000);
  final bytes = photoInput.isEmpty
      ? (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List()
      : base64Decode(photoInput);
  image.dispose();
  picture.dispose();
  text.dispose();
  final directory = await Directory.systemTemp.createTemp('ai-ant-memo-');
  final milliseconds = <int>[];
  var lines = <MemoLineDraft>[];
  try {
    for (var attempt = 0; attempt < 3; attempt++) {
      final photo = await File(
        '${directory.path}/memo.${photoInput.isEmpty ? 'png' : 'jpg'}',
      ).writeAsBytes(bytes);
      final stopwatch = Stopwatch()..start();
      // 정답을 인식기에 전달하거나 네이티브 OCR을 모의 구현으로 바꾸지 않는다.
      lines = await OcrService().recognizeMemoPath(
        photo.path,
        deleteAfterReading: true,
      );
      milliseconds.add(stopwatch.elapsedMilliseconds);
      expect(await photo.exists(), isFalse);
    }
  } finally {
    await directory.delete(recursive: true);
  }
  return (lines: lines, png: bytes, milliseconds: milliseconds);
}
