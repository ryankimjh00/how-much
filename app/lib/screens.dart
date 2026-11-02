import 'receipt_region_retry.dart'; // [OCR 추가]
import 'receipt_perspective_screen.dart'; // [OCR 추가]
import 'dart:io'; // [OCR 추가]
import 'receipt_pages.dart'; // [OCR 추가]
import 'receipt_region_screen.dart'; // [OCR 추가]
import 'receipt_ocr.dart'; // [OCR 추가]
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'app_store.dart';
import 'app_theme.dart';
import 'cloud_service.dart';
import 'models.dart';
import 'ocr_service.dart';
import 'design_widgets.dart';
import 'price_screen.dart';
import 'receipt_review_photo.dart'; // [OCR 추가]
import 'receipt_selection_screen.dart'; // [OCR 추가]

final _won = NumberFormat.decimalPattern('ko_KR');

String _formatWon(num value) => '${_won.format(value.round())}원';

void _showError(BuildContext context, Object error) {
  final message = error
      .toString()
      .replaceFirst('FormatException: ', '')
      .replaceFirst('Bad state: ', '');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _showAccount(BuildContext context, AppStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => ListenableBuilder(
      listenable: store,
      builder: (_, _) => _AccountSheet(store: store),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _draft = TextEditingController();
  int _tab = 0;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_draft.text.trim().isEmpty) return;
    try {
      await widget.store.addItem(_draft.text);
      _draft.clear();
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tab == 1) {
      return HistoryScreen(
        store: widget.store,
        onShopping: () => setState(() => _tab = 0),
      );
    }
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        if (store.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final items = store.visibleShoppingItems;
        final count = store.shoppingItems.length;
        final remaining = count - store.completedCount;
        return Scaffold(
          bottomNavigationBar: DesignNavigation(
            index: 0,
            onChanged: (tab) => setState(() => _tab = tab),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Row(
                      children: [
                        Text(
                          '얼마였지?',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(width: 4),
                        const DesignIcon('IconLeaf'),
                        const Spacer(),
                        IconButton.outlined(
                          tooltip: '계정 · 동기화',
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          onPressed: () => _showAccount(context, store),
                          icon: const DesignIcon('IconUser'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '오늘은 뭘 살까요?',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(fontSize: 27),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '생각난 순간 바로 적어두면 돼요.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    PaperCard(
                      color: AppColors.note,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DesignIcon('IconSpark'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '장보기 $count개',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    remaining == 0 && count > 0
                                        ? '모두 챙겼어요!'
                                        : '아직 $remaining개 남았어요',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${store.completedCount} / $count',
                              style: const TextStyle(
                                fontFamily: 'Jua',
                                fontSize: 23,
                                color: AppColors.coral,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _draft,
                            enabled: store.canEdit,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _add(),
                            decoration: const InputDecoration(
                              hintText: '상품명 입력',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: FilledButton(
                            onPressed: store.canEdit ? _add : null,
                            child: Semantics(
                              label: '추가',
                              child: const DesignIcon('IconPlus'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ReceiptCaptureScreen(store: store, memo: true),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              DesignIcon('IconCamera'),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '손글씨 메모도 찍어서 추가해요',
                                  style: TextStyle(
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DesignIcon('IconChevron'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '살 것',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        PopupMenuButton<ShoppingFilter>(
                          tooltip: '목록 필터',
                          onSelected: store.setFilter,
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: ShoppingFilter.all,
                              child: Text('전체'),
                            ),
                            PopupMenuItem(
                              value: ShoppingFilter.active,
                              child: Text('살 것'),
                            ),
                            PopupMenuItem(
                              value: ShoppingFilter.completed,
                              child: Text('완료'),
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              '$remaining개',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const _EmptyShopping()
                    else
                      PaperCard(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < items.length;
                              index++
                            ) ...[
                              if (index > 0)
                                const Padding(
                                  padding: EdgeInsets.only(left: 52, right: 16),
                                  child: Divider(height: 1),
                                ),
                              _ShoppingItemCard(
                                store: store,
                                item: items[index],
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      '하나씩 체크하면 다음에도 기억해둘게요.',
                      style: TextStyle(
                        fontFamily: 'Gaegu',
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    if (store.error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _MessageBox(message: store.error, error: true),
                    ],
                    if (store.conflicts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => _showAccount(context, store),
                        child: Text('동기화 충돌 ${store.conflicts.length}건 확인'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShoppingItemCard extends StatelessWidget {
  const _ShoppingItemCard({required this.store, required this.item});

  final AppStore store;
  final AppRow item;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: !store.canEdit
            ? null
            : () async {
                try {
                  await store.toggleItem(item);
                } catch (error) {
                  if (context.mounted) _showError(context, error);
                }
              },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            children: [
              DesignCheckbox(
                value: item.completed,
                onChanged: !store.canEdit
                    ? null
                    : (_) async {
                        try {
                          await store.toggleItem(item);
                        } catch (error) {
                          if (context.mounted) _showError(context, error);
                        }
                      },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: item.completed
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                    if (item.note.isNotEmpty)
                      Text(
                        item.note,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Text(
                '${item.quantity ?? 1}개',
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              PopupMenuButton<String>(
                tooltip: '${item.title} 메뉴',
                icon: const DesignIcon('IconMore'),
                enabled: store.canEdit,
                onSelected: (value) async {
                  if (value == 'edit') {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ItemEditorScreen(store: store, item: item),
                      ),
                    );
                  } else if (value == 'delete') {
                    try {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('상품을 삭제할까요?'),
                          content: Text(
                            '${item.title} 항목만 삭제합니다. 저장된 구매 기록은 유지됩니다.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      await store.deleteItem(item);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.title} 삭제 완료'),
                          action: SnackBarAction(
                            label: '되돌리기',
                            onPressed: () async {
                              try {
                                await store.restoreItem(item);
                              } catch (error) {
                                if (context.mounted) _showError(context, error);
                              }
                            },
                          ),
                        ),
                      );
                    } catch (error) {
                      if (context.mounted) _showError(context, error);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyShopping extends StatelessWidget {
  const _EmptyShopping();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 42,
            color: AppColors.checked,
          ),
          const SizedBox(height: 12),
          Text(
            '장보기 목록이 비었어요',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '생각난 상품을 적거나 메모를 찍어주세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? AppColors.errorSurface : AppColors.secondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: error ? AppColors.error : AppColors.body),
      ),
    );
  }
}

class ItemEditorScreen extends StatefulWidget {
  const ItemEditorScreen({super.key, required this.store, this.item});

  final AppStore store;
  final AppRow? item;

  @override
  State<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

class _ItemEditorScreenState extends State<ItemEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _quantity;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item?.title ?? '');
    _quantity = TextEditingController(text: '${widget.item?.quantity ?? 1}');
    _note = TextEditingController(text: widget.item?.note ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final quantity = positiveInteger(_quantity.text);
      if (widget.item == null) {
        await widget.store.addItem(
          _title.text,
          quantity: quantity,
          note: _note.text,
        );
      } else {
        await widget.store.updateItem(
          widget.item!,
          title: _title.text,
          quantity: quantity,
          note: _note.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _delete() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('상품을 삭제할까요?'),
          content: const Text('저장된 구매 기록은 유지돼요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.store.deleteItem(widget.item!);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  void _changeQuantity(int delta) {
    final next = (int.tryParse(_quantity.text) ?? 1) + delta;
    if (next >= 1 && next <= 999) setState(() => _quantity.text = '$next');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        titleSpacing: 8,
        leading: const DesignBackButton(),
        title: Text(widget.item == null ? '상품 추가' : '상품 수정'),
      ),
      bottomNavigationBar: BottomAction(
        label: widget.item == null ? '목록에 담을게요' : '이대로 저장할게요',
        onPressed: widget.store.canEdit ? _save : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.item == null
                  ? '무엇을 담을까요?'
                  : '${widget.item!.title}, 이렇게 담을까요?',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontSize: 25),
            ),
            const SizedBox(height: 4),
            const Text(
              '수량이나 메모를 편하게 고쳐주세요.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            const Text('상품명'),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              maxLength: 50,
              decoration: const InputDecoration(
                hintText: '상품명',
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            const Text('수량'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '수량 줄이기',
                    onPressed: () => _changeQuantity(-1),
                    icon: const Icon(Icons.remove, color: AppColors.coral),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '수량 늘리기',
                    onPressed: () => _changeQuantity(1),
                    icon: const DesignIcon('IconPlus', screen: '34-171'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text('메모 (선택)'),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLength: 80,
              decoration: const InputDecoration(
                hintText: '예: 저지방으로',
                counterText: '',
              ),
            ),
            if (widget.item != null) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.store.canEdit ? _delete : null,
                  child: const Text(
                    '목록에서 지우기',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ReceiptCaptureScreen extends StatefulWidget {
  const ReceiptCaptureScreen({
    super.key,
    required this.store,
    this.memo = false,
  });

  final AppStore store;
  final bool memo;

  @override
  State<ReceiptCaptureScreen> createState() => _ReceiptCaptureScreenState();
}

class _ReceiptCaptureScreenState extends State<ReceiptCaptureScreen>
    with WidgetsBindingObserver {
  final _ocr = OcrService();
  int _cameraSession = 0;
  CameraController? _camera;
  bool _busy = false;
  bool _torch = false;
  bool _previewPausedForReceipt =
      false; // [OCR 추가] 보정·OCR·선택·검토 동안 촬영 미리보기를 멈춘다.
  String _cameraError = '';
  String get _busyLabel {
    // [OCR 추가]
    if (_collectingPhotos) return '사진을 추가하고 있어요'; // [OCR 추가]
    if (widget.memo) return '메모를 읽고 있어요'; // [OCR 추가]
    return '영수증을 읽고 있어요'; // [OCR 추가]
  } // [OCR 추가]

  bool _collectingPhotos = false; // [OCR 추가]
  final _recognizedPages = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
  bool _multiReceipt = false; // [OCR 추가]
  int _multiSession = 0; // [OCR 추가]
  final _pageSelections = <ReceiptPhotoPage, ReceiptDraft>{}; // [OCR 추가]
  final _receiptParts = <ReceiptPhotoPage>[]; // [OCR 추가]

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraSession++;
    _multiSession++; // [OCR 추가] 화면 종료 뒤 도착한 인식 결과를 버린다.
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    } else if (state == AppLifecycleState.inactive) {
      _cameraSession++;
      _camera?.dispose();
      _camera = null;
    }
  }

  Future<void> _initializeCamera() async {
    final session = ++_cameraSession;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('cameraUnavailable', '사용 가능한 카메라가 없습니다.');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || session != _cameraSession) return controller.dispose();
      await _camera?.dispose();
      setState(() {
        _camera = controller;
        _cameraError = '';
      });
      if (_previewPausedForReceipt) {
        await _setReceiptPreviewPaused(
          true,
        ); // [OCR 추가] 앨범 복귀 후 늦게 준비된 카메라도 멈춘다.
      }
    } catch (_) {
      if (mounted && session == _cameraSession) {
        setState(() => _cameraError = '카메라 권한이 필요해요. 설정에서 허용하거나 앨범에서 선택해주세요.');
      }
    }
  }

  // [OCR 추가] 숨은 미리보기가 OCR과 CPU·렌더링 자원을 경쟁하지 않게 한다.
  // 이미 촬영한 뒤에만 정지하고, 취소·실패로 촬영 화면에 돌아오면 다시 재생한다.
  Future<void> _setReceiptPreviewPaused(bool paused) async {
    _previewPausedForReceipt = paused;
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    try {
      if (paused) {
        await camera.pausePreview();
      } else {
        await camera.resumePreview();
      }
    } on CameraException {
      // 카메라가 수명 주기 전환 중 종료되어도 읽힌 사진과 OCR 결과를 버리지 않는다.
      if (!paused && mounted) await _initializeCamera();
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    if (_multiReceipt) {
      // [OCR 추가]
      // [OCR 추가]
      await _collectParts(
        // [OCR 추가]
        () async => [
          // [OCR 추가]
          ReceiptPhotoPage(path: (await camera.takePicture()).path), // [OCR 추가]
        ], // [OCR 추가]
      ); // [OCR 추가]
      return; // [OCR 추가]
    } // [OCR 추가]
    if (widget.memo) {
      await _recognizeMemo(
        () async => _ocr.recognizeMemoPath((await camera.takePicture()).path),
      );
      return;
    }
    await _recognize(
      () async => _recognizeCorrectedReceipt(
        (await camera.takePicture()).path,
      ), // [OCR 수정]
    );
  }

  Future<void> _gallery() async {
    if (widget.memo) {
      await _recognizeMemo(() => _ocr.pickMemo(ImageSource.gallery));
      return;
    }
    // [OCR 수정] 앨범에서 한 장만 선택하면 즉시 처리하고, 여러 장은 모은 뒤 장별로 처리한다.
    await _collectParts(
      () => _ocr.pickReceiptPages(limit: 10 - _receiptParts.length),
      allowSingleReceipt: true, // [OCR 추가]
    ); // [OCR 수정]
  }

  // [OCR 추가] 촬영을 모두 마친 뒤에만 보정한다. 계정 전환·화면 종료 후의 결과는 폐기한다.
  Future<Uint8List?> _correctReceiptPhoto(Uint8List original) async {
    // [OCR 추가]
    if (!mounted) return null; // [OCR 추가]
    final account = widget.store.cloud.accountId; // [OCR 추가]
    final corrected = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        // [OCR 추가]
        builder: (_) => ReceiptPerspectiveScreen(bytes: original), // [OCR 추가]
      ),
    ); // [OCR 추가]
    if (!mounted || account != widget.store.cloud.accountId) {
      // [OCR 추가]
      return null; // [OCR 추가]
    } // [OCR 추가]
    return corrected; // [OCR 추가]
  } // [OCR 추가]

  Future<ReceiptDraft?> _recognizeCorrectedReceipt(String path) async {
    // [OCR 추가] 사진 촬영이 끝난 뒤, 사진 디코딩과 보정 화면을 열기 전에 정지한다.
    await _setReceiptPreviewPaused(true);
    final bytes = await _correctReceiptPhoto(
      await File(path).readAsBytes(),
    ); // [OCR 추가]
    if (bytes == null) return null; // [OCR 추가]
    return _ocr.recognizePath(
      path,
      allowManualRegions: true,
      photoBytes: bytes,
    ); // [OCR 추가]
  } // [OCR 추가]

  Future<void> _collectParts(
    // [OCR 추가]
    Future<List<ReceiptPhotoPage>> Function() action, { // [OCR 수정]
    bool allowSingleReceipt = false, // [OCR 추가]
  }) async {
    // [OCR 추가]
    // [OCR 추가]
    if (_busy || _receiptParts.length >= 10) return; // [OCR 추가]
    final session = _multiSession; // [OCR 추가]
    final account = widget.store.cloud.accountId; // [OCR 추가]
    setState(() {
      // [OCR 추가]
      _busy = true; // [OCR 추가]
      _collectingPhotos = true; // [OCR 추가]
    }); // [OCR 추가]
    try {
      // [OCR 추가]
      final parts = await action(); // [OCR 추가]
      if (!mounted || // [OCR 추가]
          session != _multiSession || // [OCR 추가]
          account != widget.store.cloud.accountId) {
        // [OCR 추가]
        return; // [OCR 추가]
      } // [OCR 추가]
      if (parts.isEmpty) return; // [OCR 추가] 앨범 취소 시 기존 사진과 촬영 모드를 유지한다.
      // [OCR 수정] 여러 장 모드에서만 이어 모으고 한 장 모드의 사진은 별도로 처리한다.
      if (allowSingleReceipt &&
          !_multiReceipt &&
          _receiptParts.isEmpty &&
          parts.length == 1) {
        setState(() => _collectingPhotos = false); // [OCR 추가]
        await _recognize(
          () => _recognizeCorrectedReceipt(parts.single.path),
        ); // [OCR 추가] 기존 한 장 보정·선택·검토와 취소·계정 전환 보호를 재사용한다.
        return; // [OCR 추가]
      }
      setState(() {
        _multiReceipt = true; // [OCR 추가] 사진이 추가된 뒤에만 장별 처리 화면으로 전환한다.
        _receiptParts.addAll(
          parts.take(10 - _receiptParts.length),
        ); // [OCR 수정] 선택기에서 제한을 지원하지 않아도 합계 10장을 넘기지 않는다.
      }); // [OCR 수정]
    } catch (error) {
      // [OCR 추가]
      if (mounted && session == _multiSession) {
        _showError(context, error); // [OCR 추가]
      }
    } finally {
      // [OCR 추가]
      if (mounted && session == _multiSession) {
        setState(() {
          // [OCR 추가]
          _busy = false; // [OCR 추가]
          _collectingPhotos = false; // [OCR 추가]
        }); // [OCR 추가]
      }
    } // [OCR 추가]
  } // [OCR 추가]

  Future<void> _finishParts() async {
    // [OCR 추가]
    // [OCR 추가]
    if (_busy || _receiptParts.isEmpty) return; // [OCR 추가]
    final session = _multiSession; // [OCR 추가]
    final account = widget.store.cloud.accountId; // [OCR 추가]
    setState(() => _busy = true); // [OCR 추가]
    try {
      await _setReceiptPreviewPaused(true); // [OCR 추가] 캐시된 장을 선택할 때도 미리보기는 멈춘다.
      if (!mounted ||
          session != _multiSession ||
          account != widget.store.cloud.accountId) {
        return; // [OCR 추가] 미리보기 정지 중 화면 종료·계정 변경을 확인한다.
      }
      final draft = await selectReceiptPages(
        // [OCR 추가]
        context, // [OCR 추가]
        List.unmodifiable(_receiptParts), // [OCR 추가]
        selections: _pageSelections, // [OCR 추가]
        recognizedPages: _recognizedPages, // [OCR 추가]
        recognize:
            (page) => // [OCR 추가]
                _recognizeCorrectedReceipt(page.path), // [OCR 수정]
        isCurrent:
            () => // [OCR 추가]
                mounted && // [OCR 추가]
                session == _multiSession && // [OCR 추가]
                account == widget.store.cloud.accountId, // [OCR 추가]
      ); // [OCR 수정]
      if (draft == null || // [OCR 추가]
          !mounted || // [OCR 추가]
          session != _multiSession || // [OCR 추가]
          account != widget.store.cloud.accountId) {
        // [OCR 추가]
        return; // [OCR 추가]
      }
      final saved = await Navigator.push<bool>(
        // [OCR 추가]
        context, // [OCR 추가]
        MaterialPageRoute(
          builder:
              (_) => // [OCR 추가]
              ReceiptReviewScreen(
                store: widget.store,
                draft: draft,
              ), // [OCR 추가]
        ), // [OCR 추가]
      ); // [OCR 수정] 모든 장의 선택이 끝난 뒤에만 한 번 검토하고 저장한다.
      if (saved == true && mounted) Navigator.pop(context); // [OCR 추가]
    } catch (error) {
      // [OCR 추가]
      if (mounted && session == _multiSession) {
        _showError(context, error); // [OCR 추가]
      }
    } finally {
      // [OCR 추가]
      if (mounted && session == _multiSession) {
        await _setReceiptPreviewPaused(
          false,
        ); // [OCR 추가] 여러 장 처리 취소·실패 후 촬영을 재개한다.
        if (mounted && session == _multiSession) {
          setState(() => _busy = false); // [OCR 추가]
        }
      }
    } // [OCR 추가]
  } // [OCR 추가]

  void _startReceipt({required bool multi}) {
    // [OCR 추가] 새 영수증·모드 전환은 사진과 OCR/선택 캐시를 함께 비워 이전 장이 섞이지 않게 한다.
    if (_busy) return;
    setState(() {
      _multiSession++; // [OCR 추가] 이전 영수증의 늦은 결과도 적용하지 않는다.
      _multiReceipt = multi;
      _receiptParts.clear();
      _recognizedPages.clear();
      _pageSelections.clear();
    });
  }

  void _movePart(int index, int direction) {
    // [OCR 추가]
    // [OCR 추가]
    final target = index + direction; // [OCR 추가]
    if (_busy || target < 0 || target >= _receiptParts.length) {
      return; // [OCR 추가]
    }
    setState(
      () => _receiptParts.insert(target, _receiptParts.removeAt(index)),
    ); // [OCR 추가]
  } // [OCR 추가]

  Widget _partControls() => Column(
    // [OCR 추가]
    // [OCR 추가]
    children: [
      // [OCR 추가]
      if (_receiptParts.isNotEmpty) // [OCR 추가]
        SizedBox(
          // [OCR 추가]
          height: 90, // [OCR 추가]
          child: ListView(
            // [OCR 추가]
            scrollDirection: Axis.horizontal, // [OCR 추가]
            children: [
              // [OCR 추가]
              for (var i = 0; i < _receiptParts.length; i++) // [OCR 추가]
                SizedBox(
                  // [OCR 추가]
                  width: 110, // [OCR 추가]
                  child: Column(
                    // [OCR 추가]
                    children: [
                      // [OCR 추가]
                      Expanded(
                        // [OCR 추가]
                        child: Image.file(
                          // [OCR 추가]
                          // [OCR 추가]
                          File(
                            // [OCR 추가]
                            _receiptParts[i].path, // [OCR 추가]
                          ), // [OCR 수정] 촬영 원본을 미리보기만 한다.
                          errorBuilder: (_, _, _) => const Icon(
                            // [OCR 추가]
                            Icons.broken_image_outlined, // [OCR 추가]
                          ), // [OCR 추가] 미리보기 실패가 모아둔 사진을 제거하지 않는다.
                          cacheWidth: 160, // [OCR 추가] 여러 장의 미리보기는 작은 크기로 디코딩한다.
                          fit: BoxFit.contain, // [OCR 추가]
                        ), // [OCR 추가]
                      ), // [OCR 추가]
                      Row(
                        // [OCR 추가]
                        mainAxisAlignment: MainAxisAlignment.center, // [OCR 추가]
                        children: [
                          // [OCR 추가]
                          IconButton(
                            // [OCR 추가]
                            tooltip: '앞으로 이동', // [OCR 추가]
                            onPressed:
                                _busy ||
                                    i ==
                                        0 // [OCR 추가]
                                ? null // [OCR 추가]
                                : () => _movePart(i, -1), // [OCR 추가]
                            icon: const Icon(Icons.chevron_left), // [OCR 추가]
                            visualDensity: VisualDensity.compact, // [OCR 추가]
                          ), // [OCR 추가]
                          Text(
                            // [OCR 추가]
                            '${i + 1}', // [OCR 추가]
                            style: const TextStyle(
                              color: Colors.white,
                            ), // [OCR 추가]
                          ), // [OCR 추가]
                          IconButton(
                            // [OCR 추가]
                            tooltip: '사진 제거', // [OCR 추가]
                            onPressed:
                                _busy // [OCR 추가]
                                ? null // [OCR 추가]
                                : () => // [OCR 추가]
                                  setState(() {
                                    // [OCR 추가]
                                    _pageSelections.remove(
                                      _receiptParts[i], // [OCR 추가]
                                    ); // [OCR 추가]
                                    _recognizedPages.remove(
                                      // [OCR 추가]
                                      _receiptParts[i],
                                    ); // [OCR 추가]
                                    _receiptParts.removeAt(i); // [OCR 추가]
                                  }), // [OCR 추가]
                            icon: const Icon(Icons.close), // [OCR 추가]
                            visualDensity: VisualDensity.compact, // [OCR 추가]
                          ), // [OCR 추가]
                        ], // [OCR 추가]
                      ), // [OCR 추가]
                    ], // [OCR 추가]
                  ), // [OCR 추가]
                ), // [OCR 추가]
            ], // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      TextButton(
        // [OCR 추가] 같은 여러 장 모드에서도 다른 영수증을 새로 시작할 수 있다.
        key: const ValueKey('receipt-start-new'),
        onPressed: _busy || _receiptParts.isEmpty
            ? null
            : () => _startReceipt(multi: true),
        child: const Text('새 영수증'),
      ),
      TextButton(
        // [OCR 추가]
        key: const ValueKey('receipt-finish-parts'), // [OCR 추가]
        onPressed: _busy || _receiptParts.isEmpty
            ? null
            : _finishParts, // [OCR 추가]
        child: Text('촬영 완료 (${_receiptParts.length}장)'), // [OCR 추가]
      ), // [OCR 추가]
    ], // [OCR 추가]
  ); // [OCR 추가]

  Future<void> _recognizeMemo(
    Future<List<MemoLineDraft>?> Function() action,
  ) async {
    setState(() => _busy = true);
    try {
      final lines = await action();
      if (lines == null || !mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MemoImportScreen(store: widget.store, initialLines: lines),
        ),
      );
      if (saved == true && mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recognize(Future<ReceiptDraft?> Function() action) async {
    final account =
        widget.store.cloud.accountId; // [OCR 추가] 보정·인식 도중 계정이 바뀌면 초안을 열지 않는다.
    setState(() => _busy = true);
    try {
      final draft = await action();
      if (draft != null && mounted && account == widget.store.cloud.accountId) {
        // [OCR 수정]
        await _openReview(draft); // [OCR 수정]
      } // [OCR 수정]
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) {
        await _setReceiptPreviewPaused(
          false,
        ); // [OCR 추가] 보정·선택·검토 취소와 OCR 실패 모두 촬영 화면을 복구한다.
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _openReview(ReceiptDraft draft) async {
    var reviewDraft = draft; // [OCR 추가]
    if (draft.ocrResult != null) {
      // [OCR 추가]
      // [OCR 추가] 선택 취소는 파서 초안이나 저장 기록을 바꾸지 않는다. 직접 입력은 기존 화면으로 보낸다.
      final selected = await Navigator.of(context).push<ReceiptDraft>(
        // [OCR 추가]
        MaterialPageRoute(
          builder: (_) => ReceiptSelectionScreen(draft: draft),
        ), // [OCR 추가]
      ); // [OCR 추가]
      if (!mounted || selected == null) return; // [OCR 추가]
      reviewDraft = selected; // [OCR 추가]
    } // [OCR 추가]
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiptReviewScreen(
          store: widget.store,
          draft: reviewDraft,
        ), // [OCR 수정]
      ),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      final torch = !_torch;
      await camera.setFlashMode(torch ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torch = torch);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final screen = widget.memo ? '34-77' : '34-203';
    return Scaffold(
      backgroundColor: AppColors.camera,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '뒤로',
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: DesignIcon('IconBack', screen: screen),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.memo ? '메모 찍기' : '영수증 찍기',
                          style: const TextStyle(
                            fontFamily: 'Jua',
                            color: AppColors.surface,
                            fontSize: 23,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _torch ? '플래시 끄기' : '플래시 켜기',
                        onPressed: camera == null || _busy
                            ? null
                            : _toggleTorch,
                        icon: DesignIcon('IconFlash', screen: screen),
                      ),
                    ],
                  ),
                ),
                if (!widget.memo) // [OCR 추가]
                  Padding(
                    // [OCR 추가]
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ), // [OCR 추가]
                    child: Row(
                      // [OCR 추가]
                      children: [
                        // [OCR 추가]
                        for (final multi in [false, true]) // [OCR 추가]
                          Expanded(
                            // [OCR 추가]
                            child: OutlinedButton(
                              // [OCR 추가]
                              onPressed:
                                  _busy // [OCR 추가]
                                  ? null // [OCR 추가]
                                  : () {
                                      // [OCR 수정] 이미 선택한 모드를 다시 누르면 현재 촬영 목록을 유지한다.
                                      if (_multiReceipt != multi) {
                                        _startReceipt(multi: multi);
                                      }
                                    }, // [OCR 수정]
                              style: OutlinedButton.styleFrom(
                                // [OCR 추가]
                                backgroundColor:
                                    _multiReceipt ==
                                        multi // [OCR 추가]
                                    ? AppColors
                                          .primary // [OCR 추가]
                                    : null, // [OCR 추가]
                                foregroundColor: Colors.white, // [OCR 추가]
                              ), // [OCR 추가]
                              child: Text(
                                // [OCR 추가]
                                multi ? '여러 장 찍기' : '한 장', // [OCR 추가]
                              ), // [OCR 추가]
                            ), // [OCR 추가]
                          ), // [OCR 추가]
                      ], // [OCR 추가]
                    ), // [OCR 추가]
                  ), // [OCR 추가]
                if (_multiReceipt) _partControls(), // [OCR 추가]
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Text(
                    widget.memo
                        ? '메모 한 장이면 장보기 준비 끝!'
                        : '영수증이 반듯하게 보이면 더 잘 읽어요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Jua',
                      fontSize: 16,
                      color: AppColors.surface,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(42, 8, 42, 32),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFD9D0C0),
                          width: 8,
                        ),
                      ),
                      child: camera != null && camera.value.isInitialized
                          ? CameraPreview(camera)
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  _cameraError.isEmpty
                                      ? '카메라를 준비하고 있어요.'
                                      : _cameraError,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                Container(
                  color: const Color(0xFF4B2A1B),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          DesignIcon('IconLock', screen: screen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.memo
                                  ? '사진은 저장하지 않고 글씨만 읽어요'
                                  : '개인정보는 촬영 전에 가려주세요',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFE7B79A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _CameraAction(
                            iconName: 'IconGallery',
                            screen: screen,
                            label: '앨범',
                            onTap:
                                _busy ||
                                    (_multiReceipt &&
                                        _receiptParts.length >= 10) // [OCR 추가]
                                ? null // [OCR 추가]
                                : _gallery, // [OCR 수정] 연결 가능한 최대 장수를 넘겨 선택하지 않는다.
                          ),
                          Semantics(
                            button: true,
                            label: widget.memo ? '메모 촬영' : '영수증 촬영',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap:
                                  _busy ||
                                      (_multiReceipt &&
                                          _receiptParts.length >=
                                              10) || // [OCR 추가]
                                      camera == null ||
                                      !camera.value.isInitialized
                                  ? null
                                  : _capture,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFFA323),
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _CameraAction(
                            iconName: 'IconEdit',
                            screen: screen,
                            label: '직접 입력',
                            onTap: _busy ? null : _manual,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.camera.withValues(alpha: 0.92),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 18),
                        Text(
                          _busyLabel, // [OCR 수정]
                          style: const TextStyle(
                            fontFamily: 'Jua',
                            fontSize: 23,
                            color: AppColors.surface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _manual() async {
    if (widget.memo) {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MemoImportScreen(store: widget.store),
        ),
      );
      if (saved == true && mounted) Navigator.pop(context);
      return;
    }
    await _openReview(
      ReceiptDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        store: '',
        purchasedOn: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        lines: [ReceiptLineDraft(id: 'manual-0', title: '')],
      ),
    );
  }
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({
    required this.iconName,
    required this.screen,
    required this.label,
    this.onTap,
  });
  final String iconName;
  final String screen;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        height: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DesignIcon(iconName, screen: screen),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(color: AppColors.surface, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({required this.store});

  final AppStore store;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  final _recovery = TextEditingController();
  bool _busy = false;
  bool _needsRecoveryCode = false;
  String _error = '';

  @override
  void dispose() {
    _recovery.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool requiresIdleStore = true,
  }) async {
    if (_busy ||
        (requiresIdleStore && (widget.store.saving || widget.store.syncing))) {
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await action();
    } catch (error) {
      _error = CloudService.readableError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createRecoveryAccount() async {
    final code = await widget.store.cloud.createRecoveryAccount();
    if (mounted) await _showRecoveryCode(code, newlyCreated: true);
    await widget.store.reloadForCurrentAccount();
    if (await widget.store.hasGuestData()) await widget.store.importGuestData();
    await widget.store.sync();
  }

  Future<void> _viewRecoveryCode() async {
    final code = await widget.store.cloud.readRecoveryCode();
    if (!mounted) return;
    if (code == null) {
      setState(() => _needsRecoveryCode = true);
      return;
    }
    await _showRecoveryCode(code);
  }

  Future<void> _restoreRecoveryAccount() async {
    final cloud = widget.store.cloud;
    await cloud.restoreRecoveryAccount(
      _recovery.text,
      expectedAccountId: cloud.accountId,
    );
    if (mounted) {
      _recovery.clear();
      setState(() => _needsRecoveryCode = false);
    }
    await widget.store.reloadForCurrentAccount();
    await widget.store.sync();
  }

  Future<void> _showRecoveryCode(
    String code, {
    bool newlyCreated = false,
  }) async {
    if (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: !newlyCreated,
        builder: (context) => PopScope(
          canPop: !newlyCreated,
          child: AlertDialog(
            title: Text(newlyCreated ? '복구 코드를 보관해주세요' : '복구 코드'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('다른 기기에서 같은 기록을 열 때 필요해요. 계정 메뉴에서 다시 확인할 수 있어요.'),
                  const SizedBox(height: 16),
                  SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('코드를 아는 사람은 기록에 접근할 수 있어요. 안전한 곳에 보관해주세요.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('복구 코드를 복사했어요.')),
                    );
                  }
                },
                child: const Text('코드 복사'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(newlyCreated ? '코드를 보관했어요' : '닫기'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = widget.store.cloud;
    final connected = cloud.accountId != null;
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '계정 · 동기화',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!widget.store.cloudConfigured) ...[
                const _MessageBox(
                  message:
                      '동기화 서버 설정 없이 실행 중입니다. 장보기와 구매 기록은 이 기기에 안전하게 저장됩니다.',
                ),
                const SizedBox(height: 12),
                const Text('다른 기기로 기록을 옮기는 기능은 준비 중이에요.'),
              ] else if (connected) ...[
                _MessageBox(
                  message: '${cloud.accountLabel}에 연결했어요. 기록은 자동으로 동기화돼요.',
                ),
                if (cloud.usesRecoveryCode) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () =>
                              _run(_viewRecoveryCode, requiresIdleStore: false),
                    icon: const Icon(Icons.key),
                    label: const Text('복구 코드 다시 보기'),
                  ),
                ],
                if (cloud.sessionExpired || _needsRecoveryCode) ...[
                  const SizedBox(height: 12),
                  Text(
                    cloud.sessionExpired
                        ? '세션이 만료됐어요. 기록을 유지하며 복구 코드로 다시 연결해주세요.'
                        : '이 기기에 보관한 복구 코드가 없어요. 보관한 코드를 입력해 다시 연결하면 다음부터 확인할 수 있어요. 코드를 잃어버렸다면 로그아웃하지 마세요.',
                  ),
                  TextField(
                    controller: _recovery,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: '보관한 복구 코드'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(_restoreRecoveryAccount),
                    child: const Text('복구 코드로 다시 연결'),
                  ),
                ],
                if (cloud.usesRecoveryCode)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '새 기기에서는 복구 코드를 입력해주세요. 로그아웃하면 이 기기에 보관한 코드도 지워져요.',
                    ),
                  ),
                if (widget.store.conflicts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final conflict in widget.store.conflicts) ...[
                    _SyncConflictCard(
                      conflict: conflict,
                      busy: _busy,
                      onResolve: (useLocal) => _run(() async {
                        await widget.store.resolveConflict(
                          conflict.group,
                          useLocal: useLocal,
                        );
                        if (useLocal) await widget.store.sync();
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(widget.store.sync),
                  icon: widget.store.syncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('지금 동기화'),
                ),
                if (widget.store.rows.isEmpty && widget.store.conflicts.isEmpty)
                  FutureBuilder<bool>(
                    future: widget.store.hasGuestData(),
                    builder: (context, snapshot) {
                      if (snapshot.data != true) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await widget.store.importGuestData();
                                  await widget.store.sync();
                                }),
                          child: const Text('이 기기의 기존 기록 가져오기'),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await widget.store.cloud.signOut();
                          await widget.store.reloadForCurrentAccount();
                          if (mounted) {
                            _recovery.clear();
                            setState(() => _needsRecoveryCode = false);
                          }
                        }),
                  child: const Text('로그아웃'),
                ),
              ] else ...[
                const Text('가입 없이 이 기기 기록을 보관하고, 다른 기기에서도 이어 써요.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : () => _run(_createRecoveryAccount),
                  child: const Text('복구 코드 만들고 기록 연결'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _recovery,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: '보관한 복구 코드',
                    hintText: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(_restoreRecoveryAccount),
                  child: const Text('기존 기록 복원'),
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 10),
                _MessageBox(message: _error, error: true),
              ],
              if (widget.store.syncMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  widget.store.syncMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncConflictCard extends StatelessWidget {
  const _SyncConflictCard({
    required this.conflict,
    required this.busy,
    required this.onResolve,
  });

  final SyncConflictGroup conflict;
  final bool busy;
  final ValueChanged<bool> onResolve;

  @override
  Widget build(BuildContext context) {
    String label(AppRow? row) => row == null
        ? '삭제됨'
        : '${row.deleted ? '삭제 · ' : ''}${row.title}${row.quantity == null ? '' : ' ${row.quantity}개'}';
    return Card(
      color: AppColors.errorSurface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '동기화 충돌',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in conflict.entries)
              Text(
                '이 기기: ${label(entry.local)}\n서버: ${label(entry.remote)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => onResolve(false),
                    child: const Text('서버 변경 사용'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => onResolve(true),
                    child: const Text('이 기기 변경 사용'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MemoImportScreen extends StatefulWidget {
  const MemoImportScreen({
    super.key,
    required this.store,
    this.initialLines = const [],
  });
  final AppStore store;
  final List<MemoLineDraft> initialLines;

  @override
  State<MemoImportScreen> createState() => _MemoImportScreenState();
}

class _MemoImportScreenState extends State<MemoImportScreen> {
  late final List<MemoLineDraft> _lines;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lines = [...widget.initialLines];
  }

  Future<void> _edit(MemoLineDraft line) async {
    final title = TextEditingController(text: line.title);
    final quantity = TextEditingController(text: '${line.quantity}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메모 품목 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 50,
              decoration: const InputDecoration(labelText: '상품명'),
            ),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '수량'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        line.title = title.text;
        line.quantity = int.tryParse(quantity.text) ?? 0;
      });
    }
    title.dispose();
    quantity.dispose();
  }

  Future<void> _addLine() async {
    final line = MemoLineDraft(title: '', selected: true);
    await _edit(line);
    if (line.title.trim().isNotEmpty && mounted) {
      setState(() => _lines.add(line));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.addMemoItems(_lines);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _lines.where((line) => line.selected).length;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        titleSpacing: 8,
        leading: const DesignBackButton(),
        title: const Text('메모 확인'),
      ),
      bottomNavigationBar: BottomAction(
        label: '$count개를 장보기 목록에 담기',
        onPressed: _saving || count == 0 ? null : _save,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _lines.isEmpty ? '무엇을 살까요?' : '잘 읽었어요!',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontSize: 27),
            ),
            const SizedBox(height: 4),
            const Text(
              '목록에 담기 전, 한 번만 봐주세요.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppColors.note,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const DesignIcon('IconSpark', screen: '34-119'),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${_lines.length}개 품목을 찾았어요')),
                  IconButton(
                    tooltip: '다시 찍기',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const DesignIcon('IconRedo', screen: '34-119'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PaperCard(
              child: Column(
                children: [
                  for (var index = 0; index < _lines.length; index++) ...[
                    if (index > 0)
                      const Padding(
                        padding: EdgeInsets.only(left: 52, right: 16),
                        child: Divider(height: 1),
                      ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: DesignCheckbox(
                        screen: '34-119',
                        value: _lines[index].selected,
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => _lines[index].selected = value,
                              ),
                      ),
                      title: Text(
                        _lines[index].title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_lines[index].quantity}개',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          IconButton(
                            tooltip: '품목 수정',
                            onPressed: _saving
                                ? null
                                : () => _edit(_lines[index]),
                            icon: const DesignIcon(
                              'IconEdit',
                              screen: '34-119',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => Navigator.pop(context),
              icon: const DesignIcon('IconCamera', screen: '34-119'),
              label: const Text('다시 찍기'),
            ),
            TextButton(
              onPressed: _saving ? null : _addLine,
              child: const Text('품목 직접 추가'),
            ),
            const Text(
              '필요 없는 품목은 체크를 끄면 돼요.',
              style: TextStyle(
                fontFamily: 'Gaegu',
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiptReviewScreen extends StatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.store,
    required this.draft,
  });

  final AppStore store;
  final ReceiptDraft draft;

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late final TextEditingController _store;
  late final TextEditingController _date;
  late final TextEditingController _condition;
  final _receiptScroll = ScrollController(); // [OCR 추가]
  bool _photoInteracting = false; // [OCR 추가]
  // [OCR 추가] fresh처럼 사진 조작 시작 시 진행 중인 목록 스크롤을 멈추고 마지막 접점 종료 후 해제한다.
  void _photoInteractionChanged(bool active) {
    // [OCR 추가]
    // [OCR 추가]
    if (active && _receiptScroll.hasClients) {
      // [OCR 추가]
      _receiptScroll.jumpTo(_receiptScroll.offset); // [OCR 추가]
    } // [OCR 추가]
    setState(() => _photoInteracting = active); // [OCR 추가]
  } // [OCR 추가]

  final _dateRegions =
      <int, ReceiptRegionValue>{}; // [OCR 추가] 장마다 마지막으로 적용한 날짜 영역을 복원한다.
  int _photoIndex = 0; // [OCR 추가]
  // [OCR 추가] 사진 전환과 상품 목록에서 같은 장을 같은 이름으로 표시한다.
  String _receiptPageLabel(int index) {
    const labels = [
      '첫째 장', // [OCR 수정] 순서 표현과 의존 명사인 장을 띄어 쓴다.
      '둘째 장', // [OCR 수정]
      '셋째 장', // [OCR 수정]
      '넷째 장', // [OCR 수정]
      '다섯째 장', // [OCR 수정]
      '여섯째 장', // [OCR 수정]
      '일곱째 장', // [OCR 수정]
      '여덟째 장', // [OCR 수정]
      '아홉째 장', // [OCR 수정]
      '열째 장', // [OCR 수정]
    ];
    return index < labels.length
        ? labels[index]
        : '${index + 1}번째 장'; // [OCR 수정]
  }

  ReceiptOcrResult? get _activePhoto => // [OCR 추가]
      widget.draft.ocrForPage(_photoIndex); // [OCR 추가]
  ReceiptOcrResult? _photoForLine(ReceiptLineDraft line) => // [OCR 추가]
      widget.draft.ocrForPage(line.receiptPhotoIndex); // [OCR 추가]
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store = TextEditingController(text: widget.draft.store);
    _date = TextEditingController(text: widget.draft.purchasedOn);
    _condition = TextEditingController(text: widget.draft.condition);
  }

  @override
  void dispose() {
    _receiptScroll.dispose(); // [OCR 추가]
    _store.dispose();
    _date.dispose();
    _condition.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      _date.text = DateFormat('yyyy-MM-dd').format(selected);
    }
  }

  Future<void> _editDateRegion() async {
    // [OCR 추가] 결과를 적용하기 전에는 날짜와 이전 영역을 변경하지 않는다.
    final photo = _activePhoto; // [OCR 추가]
    if (photo == null) return; // [OCR 추가]
    final page = _photoIndex; // [OCR 추가]
    final previous = _dateRegions[page]; // [OCR 추가]
    Rect? initialBounds = previous?.bounds; // [OCR 추가]
    if (initialBounds == null) {
      for (final row in photo.rows) {
        if (receiptRegionDate(row.text) != null) {
          initialBounds = row.bounds; // [OCR 추가] 전체 OCR의 날짜 줄을 시작 영역으로 제시한다.
          break; // [OCR 추가]
        }
      }
    } // [OCR 추가]
    final result = await Navigator.push<ReceiptRegionValue>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptRegionScreen(
          photoPath: photo.photoPath, // [OCR 추가]
          photoBytes: photo.photoBytes, // [OCR 추가]
          label: '구매일', // [OCR 추가]
          date: true, // [OCR 추가]
          initialBounds: initialBounds, // [OCR 추가]
          initialText: _date.text, // [OCR 추가]
        ),
      ),
    ); // [OCR 추가]
    if (!mounted || result == null) return; // [OCR 추가]
    setState(() {
      _date.text = result.text; // [OCR 추가]
      _dateRegions[page] = result; // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  Future<void> _addLine() async {
    // [OCR 수정]
    // [OCR 추가]
    final line = ReceiptLineDraft(
      // [OCR 수정]
      id: 'manual-${DateTime.now().microsecondsSinceEpoch}', // [OCR 수정]
      title: '', // [OCR 수정]
      receiptPhotoIndex: _photoIndex, // [OCR 추가]
    ); // [OCR 추가]
    await _editLine(line, widget.draft.lines.length); // [OCR 추가]
    if (!mounted || line.title.trim().isEmpty) return; // [OCR 추가]
    setState(() => widget.draft.lines.add(line)); // [OCR 추가]
  } // [OCR 추가]

  // [OCR 추가] OCR에서 돌아온 결과만 적용하므로 취소 시 항목과 기존 박스를 모두 유지한다.
  Future<void> _selectFromReceipt([ReceiptLineDraft? existing]) async {
    // [OCR 수정]
    // [OCR 추가]
    final photoIndex = existing?.receiptPhotoIndex ?? _photoIndex; // [OCR 추가]
    final photo = widget.draft.ocrForPage(photoIndex); // [OCR 추가]
    if (photo == null) return; // [OCR 추가]
    setState(() => _photoIndex = photoIndex); // [OCR 추가]
    final pageDraft = ReceiptDraft(
      // [OCR 추가]
      id: widget.draft.id, // [OCR 추가]
      store: widget.draft.store, // [OCR 추가]
      purchasedOn: widget.draft.purchasedOn, // [OCR 추가]
      lines: [], // [OCR 추가]
      condition: widget.draft.condition, // [OCR 추가]
      share: widget.draft.share, // [OCR 추가]
      ocrResult: photo, // [OCR 추가]
    ); // [OCR 추가] 수정 대상 장만 후보로 제공한다.
    final selected = await Navigator.push<ReceiptDraft>(
      // [OCR 수정]
      context, // [OCR 수정]
      MaterialPageRoute(
        // [OCR 수정]
        // [OCR 추가]
        builder: (_) => ReceiptSelectionScreen(
          // [OCR 수정]
          draft: pageDraft, // [OCR 수정]
          editLine: existing, // [OCR 수정]
        ), // [OCR 추가]
      ),
    ); // [OCR 추가]
    if (!mounted || selected == null) return; // [OCR 추가]
    setState(() {
      // [OCR 수정]
      // [OCR 추가]
      if (existing == null) {
        // [OCR 수정]
        // [OCR 추가]
        for (final line in selected.lines) {
          // [OCR 수정]
          // [OCR 추가]
          widget.draft.lines.add(
            // [OCR 수정]
            ReceiptLineDraft(
              // [OCR 수정]
              // [OCR 추가]
              id: 'receipt-${DateTime.now().microsecondsSinceEpoch}-${widget.draft.lines.length}', // [OCR 추가]
              title: line.title, // [OCR 수정]
              quantity: line.quantity, // [OCR 수정]
              total: line.total, // [OCR 추가]
              ocrProduct: line.ocrProduct, // [OCR 수정]
              ocrAmount: line.ocrAmount, // [OCR 추가]
              ocrQuantity: line.ocrQuantity, // [OCR 추가]
              ocrAmountIsUnitPrice: line.ocrAmountIsUnitPrice, // [OCR 추가]
              ocrInputAmount: line.ocrInputAmount, // [OCR 추가]
              selected: line.selected, // [OCR 추가]
              ocrNotice: line.ocrNotice, // [OCR 추가]
              receiptPhotoIndex: photoIndex, // [OCR 추가]
            ), // [OCR 수정]
          ); // [OCR 추가]
        } // [OCR 추가]
      } else {
        // [OCR 수정]
        // [OCR 추가]
        final line = selected.lines.single; // [OCR 추가]
        existing.quantity = line.quantity; // [OCR 추가]
        existing.total = line.total; // [OCR 추가]
        existing.ocrProduct = line.ocrProduct; // [OCR 추가]
        existing.ocrAmount = line.ocrAmount; // [OCR 추가]
        existing.ocrQuantity = line.ocrQuantity; // [OCR 추가]
        existing.ocrAmountIsUnitPrice = line.ocrAmountIsUnitPrice; // [OCR 추가]
        existing.ocrInputAmount = line.ocrInputAmount; // [OCR 추가]
        existing.ocrNotice = ''; // [OCR 추가]
      } // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  Future<void> _editSpec(ReceiptLineDraft line) async {
    final current = line.spec ?? ProductSpec(identity: line.title);
    final identity = TextEditingController(text: current.identity);
    final volume = TextEditingController(
      text: current.volume?.toString() ?? '',
    );
    final unit = TextEditingController(text: current.unit);
    final pack = TextEditingController(text: '${current.packCount}');
    var conditionKnown = current.conditionKnown;
    var allocated = current.allocated;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('가격 비교 조건'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: identity,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: '확인한 제품명'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: volume,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: '낱개 용량'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unit,
                        maxLength: 12,
                        decoration: const InputDecoration(
                          labelText: '단위 (mL, g 등)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pack,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '한 포장당 낱개 수'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: conditionKnown,
                  onChanged: (value) =>
                      setDialogState(() => conditionKnown = value ?? false),
                  title: const Text('할인 조건 확인 완료'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: allocated,
                  onChanged: (value) =>
                      setDialogState(() => allocated = value ?? false),
                  title: const Text('전체 할인을 상품별 금액에 반영함'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        line.spec = ProductSpec(
          identity: identity.text.trim(),
          volume: double.tryParse(volume.text),
          unit: unit.text.trim(),
          packCount: int.tryParse(pack.text) ?? 1,
          conditionKnown: conditionKnown,
          allocated: allocated,
        );
      });
    }
    identity.dispose();
    volume.dispose();
    unit.dispose();
    pack.dispose();
  }

  Future<void> _save() async {
    widget.draft.store = _store.text;
    widget.draft.purchasedOn = _date.text;
    widget.draft.condition = _condition.text;
    final warnings = widget.store.receiptWarnings(widget.draft);
    if (warnings.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('구매 내용을 다시 확인해주세요'),
          content: Text(
            warnings.map((warning) => '• ${warning.message}').join('\n\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('다시 검토'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('별도 구매로 저장'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _saving = true);
    try {
      await widget.store.saveReceipt(widget.draft);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editNameRegion(ReceiptLineDraft edited) async {
    // [OCR 추가]
    // [OCR 추가]
    final result = await Navigator.push<ReceiptRegionValue>(
      // [OCR 추가]
      context, // [OCR 추가]
      MaterialPageRoute(
        // [OCR 추가]
        builder: (_) => ReceiptRegionScreen(
          // [OCR 추가]
          // [OCR 추가]
          photoPath: _photoForLine(edited)!.photoPath, // [OCR 수정]
          photoBytes: _photoForLine(edited)!.photoBytes, // [OCR 수정]
          label: '상품명', // [OCR 추가]
          initialBounds: edited.ocrProduct?.bounds, // [OCR 추가]
          initialText: edited.title, // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
    if (!mounted || result == null) return; // [OCR 추가]
    edited.title = result.text; // [OCR 추가]
    edited.ocrProduct = ReceiptOcrCandidate(
      // [OCR 추가]
      id: // [OCR 추가]
          edited.ocrProduct?.id ?? // [OCR 추가]
          'region-${DateTime.now().microsecondsSinceEpoch}', // [OCR 추가]
      text: result.text, // [OCR 추가]
      bounds: result.bounds, // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  Future<void> _editLine(ReceiptLineDraft line, int index) async {
    // [OCR 수정]
    // [OCR 수정]
    final items = widget
        .store
        .shoppingItems // [OCR 수정]
        .where((item) => !item.completed) // [OCR 수정]
        .toList(); // [OCR 수정]
    // [OCR 수정] 이유: 키보드 입력은 사본에만 반영하고 확인 없이 닫으면 기존 수량·금액을 유지한다.
    final edited = ReceiptLineDraft(
      // [OCR 수정]
      id: line.id, // [OCR 수정]
      title: line.title, // [OCR 수정]
      quantity: line.quantity, // [OCR 수정]
      total: line.total, // [OCR 수정]
      selected: line.selected, // [OCR 수정]
      itemId: line.itemId, // [OCR 수정]
      spec: line.spec, // [OCR 수정]
      ocrProduct: line.ocrProduct, // [OCR 추가]
      ocrAmount: line.ocrAmount, // [OCR 추가]
      ocrQuantity: line.ocrQuantity, // [OCR 추가]
      ocrAmountIsUnitPrice: line.ocrAmountIsUnitPrice, // [OCR 추가]
      ocrInputAmount: line.ocrInputAmount, // [OCR 추가]
      receiptPhotoIndex: line.receiptPhotoIndex, // [OCR 추가] 사본에서도 원래 사진을 참조한다.
    ); // [OCR 수정]
    final confirmed = await showModalBottomSheet<bool>(
      // [OCR 수정]
      context: context, // [OCR 수정]
      useSafeArea: true, // [OCR 수정]
      isScrollControlled: true, // [OCR 수정]
      builder: (sheetContext) => StatefulBuilder(
        // [OCR 수정]
        builder: (sheetContext, setSheetState) => Padding(
          // [OCR 수정]
          // [OCR 수정]
          padding: EdgeInsets.fromLTRB(
            // [OCR 수정]
            20, // [OCR 수정]
            20, // [OCR 수정]
            20, // [OCR 수정]
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom, // [OCR 수정]
          ), // [OCR 수정]
          child: SingleChildScrollView(
            // [OCR 수정]
            child: Column(
              // [OCR 수정]
              mainAxisSize: MainAxisSize.min, // [OCR 수정]
              children: [
                // [OCR 수정]
                // [OCR 수정]
                _ReceiptLineCard(
                  // [OCR 수정]
                  line: edited, // [OCR 수정]
                  items: items, // [OCR 수정]
                  index: index, // [OCR 수정]
                  onChanged: () => setSheetState(() {}), // [OCR 수정]
                  onEditSpec: () async {
                    // [OCR 수정]
                    await _editSpec(edited); // [OCR 수정]
                    if (sheetContext.mounted) setSheetState(() {}); // [OCR 수정]
                  }, // [OCR 수정]
                  onDelete: () {
                    // [OCR 수정]
                    setState(
                      () => _removeReceiptLine(line),
                    ); // [OCR 수정] // [OCR 수정]
                    Navigator.pop(sheetContext, false); // [OCR 수정]
                  }, // [OCR 수정]
                ), // [OCR 수정]
                if (_photoForLine(edited) != null) // [OCR 추가]
                  TextButton(
                    // [OCR 추가]
                    onPressed: () async {
                      // [OCR 추가]
                      await _editNameRegion(edited); // [OCR 추가]
                      if (sheetContext.mounted) {
                        // [OCR 수정]
                        setSheetState(() {}); // [OCR 추가]
                      } // [OCR 수정]
                    }, // [OCR 추가]
                    child: const Text('상품명 영역 수정'), // [OCR 추가]
                  ), // [OCR 추가]
                const SizedBox(height: 12), // [OCR 수정]
                Row(
                  // [OCR 수정]
                  children: [
                    // [OCR 수정]
                    // [OCR 수정]
                    TextButton(
                      // [OCR 수정]
                      onPressed: () =>
                          Navigator.pop(sheetContext, false), // [OCR 수정]
                      child: const Text('취소'), // [OCR 수정]
                    ), // [OCR 수정]
                    const SizedBox(width: 12), // [OCR 수정]
                    Expanded(
                      // [OCR 수정]
                      child: FilledButton(
                        // [OCR 수정]
                        onPressed: () {
                          // [OCR 수정]
                          // [OCR 수정]
                          if (edited.title.trim().isEmpty || // [OCR 수정]
                              edited.title.trim().length > 50 || // [OCR 수정]
                              edited.quantity < 1 || // [OCR 수정]
                              edited.quantity > 999 || // [OCR 수정]
                              edited.total < 0 || // [OCR 수정]
                              edited.total > 9999999) {
                            // [OCR 수정]
                            // [OCR 수정]
                            _showError(
                              // [OCR 수정]
                              sheetContext, // [OCR 수정]
                              const FormatException(
                                // [OCR 수정]
                                '상품명·수량(1~999개)·결제금액을 확인해주세요.', // [OCR 수정]
                              ), // [OCR 수정]
                            ); // [OCR 수정]
                            return; // [OCR 수정]
                          } // [OCR 수정]
                          edited.selected =
                              true; // [OCR 추가] 유효한 수정 확인은 해당 항목도 선택한다.
                          Navigator.pop(sheetContext, true); // [OCR 수정]
                        }, // [OCR 수정]
                        child: const Text('확인했어요'), // [OCR 수정]
                      ), // [OCR 수정]
                    ), // [OCR 수정]
                  ], // [OCR 수정]
                ), // [OCR 수정]
              ], // [OCR 수정]
            ), // [OCR 수정]
          ), // [OCR 수정]
        ), // [OCR 수정]
      ), // [OCR 수정]
    ); // [OCR 수정]
    if (!mounted || confirmed != true) return; // [OCR 수정]
    setState(() {
      // [OCR 수정]
      // [OCR 수정]
      line.ocrProduct = edited.ocrProduct; // [OCR 추가]
      // [OCR 수정] 이유: 수량 변경은 단가 입력 상태를 유지하고, 총액 직접 수정만 총액 입력으로 전환한다. 취소한 사본은 적용하지 않는다.
      line.ocrAmountIsUnitPrice = edited.ocrAmountIsUnitPrice; // [OCR 수정]
      line.ocrInputAmount = edited.ocrInputAmount; // [OCR 수정]
      line.ocrNotice = ''; // [OCR 추가]
      line.title = edited.title; // [OCR 추가]
      line.quantity = edited.quantity; // [OCR 수정]
      line.total = edited.total; // [OCR 수정]
      // [OCR 수정] 이 편집창에서 구성품을 개별 확정하면 기준 상품과 별개의 구매 항목으로 취급한다.
      // 현재 항목의 부모 ID만 지우므로 기준 상품과 다른 구성품의 관계·선택 상태는 바뀌지 않는다.
      // 취소한 경우에는 위에서 이미 반환하므로 기존 세트 관계도 그대로 유지된다.
      line.setParentId = ''; // [OCR 수정]
      line.selected = edited.selected; // [OCR 수정]
      line.itemId = edited.itemId; // [OCR 수정]
      line.spec = edited.spec; // [OCR 수정]
    }); // [OCR 수정]
  } // [OCR 수정]

  bool _canJoinSet(ReceiptLineDraft source, ReceiptLineDraft target) {
    // [OCR 추가]
    if (_saving || source == target || target.setParentId.isNotEmpty) {
      // [OCR 수정]
      return false; // [OCR 추가]
    } // [OCR 수정]
    // [OCR 추가] 세트 중첩·순환을 만들거나 이미 묶인 구성품을 잃지 않는다.
    return !widget.draft.lines.any(
      (line) => line.setParentId == source.id,
    ); // [OCR 추가]
  } // [OCR 추가]

  void _joinSet(ReceiptLineDraft source, ReceiptLineDraft target) {
    // [OCR 추가]
    if (!_canJoinSet(source, target)) return; // [OCR 추가]
    setState(() {
      // [OCR 추가]
      source.setParentId = target.id; // [OCR 추가]
      source.selected = target.selected; // [OCR 추가]
      final lines = widget.draft.lines; // [OCR 추가]
      lines.remove(source); // [OCR 추가]
      var index = lines.indexOf(target) + 1; // [OCR 추가]
      while (index < lines.length && lines[index].setParentId == target.id) {
        // [OCR 추가]
        index++; // [OCR 추가]
      } // [OCR 추가]
      lines.insert(index, source); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]

  void _removeReceiptLine(ReceiptLineDraft line) {
    // [OCR 추가]
    // [OCR 추가] 기준 상품 삭제는 구성품을 삭제하지 않고 독립 항목으로 돌린다.
    for (final child in widget.draft.lines.where(
      (child) => child.setParentId == line.id,
    )) {
      // [OCR 추가]
      child.setParentId = ''; // [OCR 추가]
    } // [OCR 추가]
    widget.draft.lines.remove(line); // [OCR 추가]
  } // [OCR 추가]

  void _selectSetLine(ReceiptLineDraft line, bool selected) {
    // [OCR 추가]
    line.selected = selected; // [OCR 추가]
    for (final child in widget.draft.lines.where(
      (child) => child.setParentId == line.id,
    )) {
      // [OCR 추가]
      child.selected = selected; // [OCR 추가]
    } // [OCR 추가]
    if (selected && line.setParentId.isNotEmpty) {
      // [OCR 추가]
      widget.draft.lines
              .firstWhere((parent) => parent.id == line.setParentId)
              .selected =
          true; // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]

  Widget _setReceiptTile(ReceiptLineDraft line, Widget tile) {
    // [OCR 추가]
    return DragTarget<ReceiptLineDraft>(
      // [OCR 추가]
      key: ValueKey('ocr-set-target-${line.id}'), // [OCR 추가]
      onWillAcceptWithDetails: (details) =>
          _canJoinSet(details.data, line), // [OCR 추가]
      onAcceptWithDetails: (details) =>
          _joinSet(details.data, line), // [OCR 추가]
      builder: (context, candidates, rejected) => Material(
        // [OCR 추가]
        color: candidates.isEmpty
            ? Colors.transparent
            : AppColors.secondary, // [OCR 추가]
        child: Padding(
          // [OCR 수정] 드롭 강조도 Material에서 그려 기존 터치 효과를 가리지 않는다.
          padding: EdgeInsets.only(
            left: line.setParentId.isEmpty ? 0 : 16,
          ), // [OCR 추가]
          child: LongPressDraggable<ReceiptLineDraft>(
            // [OCR 추가]
            key: ValueKey('ocr-set-drag-${line.id}'), // [OCR 추가]
            data: line, // [OCR 추가]
            maxSimultaneousDrags: _saving ? 0 : 1, // [OCR 추가]
            feedback: Material(
              // [OCR 추가]
              color: AppColors.surface, // [OCR 추가]
              elevation: 4, // [OCR 추가]
              borderRadius: BorderRadius.circular(12), // [OCR 추가]
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(line.title),
              ), // [OCR 추가]
            ), // [OCR 추가]
            childWhenDragging: Opacity(opacity: .35, child: tile), // [OCR 추가]
            child: Column(
              // [OCR 추가]
              children: [
                // [OCR 추가]
                tile, // [OCR 추가]
                if (line.setParentId.isNotEmpty) // [OCR 추가]
                  TextButton(
                    // [OCR 추가]
                    key: ValueKey('ocr-set-unlink-${line.id}'), // [OCR 추가]
                    onPressed: _saving
                        ? null
                        : () =>
                              setState(() => line.setParentId = ''), // [OCR 추가]
                    child: const Text('세트 해제'), // [OCR 추가]
                  ), // [OCR 추가]
              ], // [OCR 추가]
            ), // [OCR 추가]
          ), // [OCR 추가]
        ), // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  String _reviewSubtitle(ReceiptLineDraft line) {
    // [OCR 추가]
    // [OCR 추가]
    final price =
        line.unitPrice ==
            null // [OCR 추가]
        ? '수량·금액을 확인해주세요' // [OCR 추가]
        : '개당 ${_formatWon(line.unitPrice!)} · ${line.quantity}개'; // [OCR 추가]
    if (line.setParentId.isNotEmpty) {
      // [OCR 추가]
      final parent = widget.draft.lines.firstWhere(
        (parent) => parent.id == line.setParentId,
      ); // [OCR 추가]
      return '${parent.title} 세트 구성품\n$price'; // [OCR 추가]
    } // [OCR 추가]
    if (line.ocrNotice.isEmpty) return price; // [OCR 추가]
    return '${line.ocrNotice}\n$price'; // [OCR 추가]
  } // [OCR 추가]

  @override
  Widget build(BuildContext context) {
    final lines = widget.draft.lines;
    final count = lines.where((line) => line.selected).length;
    final total = lines
        .where((line) => line.selected)
        .fold<int>(0, (sum, line) => sum + line.total);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        titleSpacing: 8,
        leading: const DesignBackButton(),
        title: const Text('영수증 확인'),
      ),
      bottomNavigationBar: BottomAction(
        label: _saving ? '저장하고 있어요…' : '구매 기록에 남길게요',
        onPressed: _saving || count == 0 ? null : _save,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          // [OCR 수정]
          builder: (context, constraints) => Column(
            // [OCR 수정]
            children: [
              // [OCR 수정]
              // [OCR 수정]
              if (widget.draft.ocrPages.length > 1) // [OCR 추가]
                Row(
                  // [OCR 추가]
                  mainAxisAlignment: MainAxisAlignment.center, // [OCR 추가]
                  children: [
                    // [OCR 추가]
                    IconButton(
                      // [OCR 추가]
                      key: const ValueKey('receipt-previous-photo'), // [OCR 추가]
                      tooltip: '이전 사진', // [OCR 추가]
                      onPressed:
                          _saving ||
                              _photoIndex ==
                                  0 // [OCR 추가]
                          ? null // [OCR 추가]
                          : () => setState(() {
                              // [OCR 추가]
                              _photoIndex--; // [OCR 추가]
                              _photoInteracting = false; // [OCR 추가]
                            }), // [OCR 추가]
                      icon: const Icon(Icons.chevron_left), // [OCR 추가]
                    ), // [OCR 추가]
                    Text(
                      // [OCR 추가]
                      '${_receiptPageLabel(_photoIndex)} / 총 ${widget.draft.ocrPages.length}장', // [OCR 수정]
                    ), // [OCR 추가]
                    IconButton(
                      // [OCR 추가]
                      key: const ValueKey('receipt-next-photo'), // [OCR 추가]
                      tooltip: '다음 사진', // [OCR 추가]
                      onPressed: // [OCR 추가]
                          _saving || // [OCR 추가]
                              _photoIndex ==
                                  widget.draft.ocrPages.length -
                                      1 // [OCR 추가]
                          ? null // [OCR 추가]
                          : () => setState(() {
                              // [OCR 추가]
                              _photoIndex++; // [OCR 추가]
                              _photoInteracting = false; // [OCR 추가]
                            }), // [OCR 추가]
                      icon: const Icon(Icons.chevron_right), // [OCR 추가]
                    ), // [OCR 추가]
                  ], // [OCR 추가]
                ), // [OCR 추가]
              if (_activePhoto != null) // [OCR 추가]
                SizedBox(
                  // [OCR 수정]
                  height: (constraints.maxHeight * .35).clamp(
                    // [OCR 수정]
                    0.0, // [OCR 수정]
                    240.0, // [OCR 수정]
                  ), // [OCR 추가]
                  child: ReceiptReviewPhoto(
                    onInteractionChanged: _photoInteractionChanged, // [OCR 추가]
                    // [OCR 수정]
                    key: ValueKey(
                      // [OCR 추가]
                      'receipt-review-photo-$_photoIndex', // [OCR 추가]
                    ), // [OCR 추가] 장 전환 시 확대 상태를 초기화한다.
                    path: _activePhoto!.photoPath, // [OCR 수정]
                    photoBytes: _activePhoto!.photoBytes, // [OCR 수정]
                    regions: [
                      // [OCR 수정]
                      // [OCR 추가]
                      for (final line in lines.where(
                        // [OCR 수정]
                        (line) => // [OCR 추가]
                            line.selected && // [OCR 추가]
                            line.receiptPhotoIndex == _photoIndex, // [OCR 수정]
                      )) ...[
                        // [OCR 수정]
                        // [OCR 추가]
                        if (line.ocrProduct != null) // [OCR 수정]
                          line.ocrProduct!, // [OCR 추가]
                        if (line.ocrAmount != null) line.ocrAmount!, // [OCR 추가]
                      ], // [OCR 추가]
                    ], // [OCR 수정]
                  ), // [OCR 추가]
                ), // [OCR 추가]
              Expanded(
                // [OCR 수정]
                child: ListView(
                  controller: _receiptScroll, // [OCR 추가]
                  physics:
                      _photoInteracting // [OCR 추가]
                      ? const NeverScrollableScrollPhysics() // [OCR 추가]
                      : null, // [OCR 추가]
                  // [OCR 수정]
                  // [OCR 수정]
                  padding: const EdgeInsets.all(20), // [OCR 수정]
                  children: [
                    Text(
                      // [OCR 수정]
                      '가격만 한번 확인해 주세요', // [OCR 수정]
                      style:
                          Theme.of(
                            // [OCR 수정]
                            context, // [OCR 수정]
                          ).textTheme.headlineLarge?.copyWith(
                            fontSize: 25,
                          ), // [OCR 수정]
                    ), // [OCR 수정]
                    const SizedBox(height: 4), // [OCR 수정]
                    const Text(
                      // [OCR 수정]
                      '다르면 해당 금액만 톡 눌러 고치면 돼요.', // [OCR 수정]
                      style: TextStyle(color: AppColors.muted), // [OCR 수정]
                    ), // [OCR 수정]
                    const SizedBox(height: 24), // [OCR 수정]
                    const Text('어디서 샀나요?'), // [OCR 수정]
                    const SizedBox(height: 8), // [OCR 수정]
                    TextField(
                      // [OCR 수정]
                      controller: _store, // [OCR 수정]
                      maxLength: 50, // [OCR 수정]
                      decoration: const InputDecoration(
                        // [OCR 수정]
                        counterText: '', // [OCR 수정]
                        prefixIcon: Padding(
                          // [OCR 수정]
                          padding: EdgeInsets.all(14), // [OCR 수정]
                          child: DesignIcon(
                            'IconStore',
                            screen: '34-248',
                          ), // [OCR 수정]
                        ), // [OCR 수정]
                      ), // [OCR 수정]
                    ), // [OCR 수정]
                    const SizedBox(height: 20), // [OCR 수정]
                    Row(
                      children: [
                        const Expanded(child: Text('언제 샀나요?')), // [OCR 수정]
                        if (_activePhoto != null)
                          TextButton(
                            key: const ValueKey(
                              'receipt-date-region',
                            ), // [OCR 추가]
                            onPressed: _saving
                                ? null
                                : _editDateRegion, // [OCR 추가]
                            child: const Text('영수증에서 날짜 수정'), // [OCR 추가]
                          ), // [OCR 추가]
                      ],
                    ), // [OCR 수정]
                    const SizedBox(height: 8), // [OCR 수정]
                    TextField(
                      // [OCR 수정]
                      controller: _date, // [OCR 수정]
                      readOnly: true, // [OCR 수정]
                      onTap: _pickDate, // [OCR 수정]
                      decoration: const InputDecoration(
                        // [OCR 수정]
                        prefixIcon: Padding(
                          // [OCR 수정]
                          padding: EdgeInsets.all(14), // [OCR 수정]
                          child: DesignIcon(
                            'IconCalendar',
                            screen: '34-248',
                          ), // [OCR 수정]
                        ), // [OCR 수정]
                      ), // [OCR 수정]
                    ), // [OCR 수정]
                    const SizedBox(height: 24), // [OCR 수정]
                    Row(
                      // [OCR 수정]
                      children: [
                        // [OCR 수정]
                        Expanded(
                          // [OCR 수정]
                          child: Text(
                            // [OCR 수정]
                            '산 품목', // [OCR 수정]
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall, // [OCR 수정]
                          ),
                        ),
                        Text(
                          // [OCR 수정]
                          '$count개', // [OCR 수정]
                          style: const TextStyle(
                            color: AppColors.muted,
                          ), // [OCR 수정]
                        ), // [OCR 수정]
                      ], // [OCR 수정]
                    ), // [OCR 수정]
                    const SizedBox(height: 12), // [OCR 수정]
                    PaperCard(
                      // [OCR 수정]
                      child: Material(
                        // [OCR 수정]
                        // [OCR 추가]
                        // [OCR 추가] 기존 카드 장식을 유지하면서 ListTile와 터치 효과의 Material 조상을 제공한다.
                        type: MaterialType.transparency, // [OCR 추가]
                        child: Column(
                          // [OCR 수정]
                          children: [
                            // [OCR 수정]
                            for (
                              // [OCR 수정]
                              var index = 0; // [OCR 수정]
                              index < lines.length; // [OCR 수정]
                              index++ // [OCR 수정]
                            ) ...[
                              // [OCR 수정]
                              if (index > 0) // [OCR 수정]
                                const Padding(
                                  // [OCR 수정]
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ), // [OCR 수정]
                                  child: Divider(height: 1), // [OCR 수정]
                                ), // [OCR 수정]
                              _setReceiptTile(
                                lines[index],
                                ListTile(
                                  // [OCR 수정]
                                  leading: Checkbox(
                                    // [OCR 수정]
                                    value: lines[index].selected, // [OCR 수정]
                                    onChanged:
                                        _saving // [OCR 수정]
                                        ? null // [OCR 수정]
                                        : (value) => setState(
                                            // [OCR 수정]
                                            () => _selectSetLine(
                                              lines[index],
                                              value ?? false,
                                            ), // [OCR 수정]
                                          ), // [OCR 수정]
                                  ), // [OCR 추가]
                                  onTap:
                                      _saving // [OCR 수정]
                                      ? null // [OCR 수정]
                                      : () => _editLine(
                                          lines[index],
                                          index,
                                        ), // [OCR 수정]
                                  title: Text(
                                    // [OCR 수정]
                                    lines[index]
                                            .title
                                            .isEmpty // [OCR 수정]
                                        ? '상품명을 입력해주세요' // [OCR 수정]
                                        : lines[index].title, // [OCR 수정]
                                    style: TextStyle(
                                      // [OCR 수정]
                                      fontSize: 14, // [OCR 수정]
                                      color:
                                          lines[index]
                                              .selected // [OCR 수정]
                                          ? AppColors
                                                .ink // [OCR 수정]
                                          : AppColors.muted, // [OCR 수정]
                                    ), // [OCR 수정]
                                  ), // [OCR 수정]
                                  subtitle: Text(
                                    widget.draft.ocrPages.length >
                                            1 // [OCR 추가]
                                        ? '${_receiptPageLabel(lines[index].receiptPhotoIndex)} · ${_reviewSubtitle(lines[index])}' // [OCR 수정]
                                        : _reviewSubtitle(
                                            // [OCR 추가]
                                            lines[index], // [OCR 추가]
                                          ), // [OCR 수정]
                                  ), // [OCR 수정]
                                  trailing: Row(
                                    // [OCR 수정]
                                    mainAxisSize: MainAxisSize.min, // [OCR 수정]
                                    children: [
                                      // [OCR 수정]
                                      Text(
                                        // [OCR 수정]
                                        lines[index]
                                                .selected // [OCR 수정]
                                            ? _formatWon(
                                                lines[index].total,
                                              ) // [OCR 수정]
                                            : '제외', // [OCR 수정]
                                        style: const TextStyle(
                                          // [OCR 수정]
                                          fontWeight:
                                              FontWeight.w700, // [OCR 수정]
                                        ), // [OCR 수정]
                                      ), // [OCR 수정]
                                      const SizedBox(width: 8), // [OCR 수정]
                                      const DesignIcon(
                                        // [OCR 수정]
                                        'IconEdit', // [OCR 수정]
                                        screen: '34-248', // [OCR 수정]
                                      ), // [OCR 수정]
                                    ], // [OCR 수정]
                                  ), // [OCR 수정]
                                ),
                              ), // [OCR 수정]
                              if (_photoForLine(lines[index]) != // [OCR 추가]
                                      null && // [OCR 수정]
                                  lines[index].ocrProduct != null) // [OCR 추가]
                                TextButton(
                                  // [OCR 수정]
                                  onPressed:
                                      _saving // [OCR 수정]
                                      ? null // [OCR 수정]
                                      : () => _selectFromReceipt(
                                          lines[index],
                                        ), // [OCR 수정]
                                  child: const Text('영수증에서 수정'), // [OCR 수정]
                                ), // [OCR 추가]
                            ], // [OCR 수정]
                          ], // [OCR 수정]
                        ), // [OCR 수정]
                      ), // [OCR 추가]
                    ), // [OCR 수정]
                    const SizedBox(height: 20), // [OCR 수정]
                    PaperCard(
                      // [OCR 수정]
                      color: AppColors.note, // [OCR 수정]
                      child: Padding(
                        // [OCR 수정]
                        padding: const EdgeInsets.all(16), // [OCR 수정]
                        child: Row(
                          // [OCR 수정]
                          children: [
                            const Expanded(
                              // [OCR 수정]
                              child: Text(
                                // [OCR 수정]
                                '모두 합쳐', // [OCR 수정]
                                style: TextStyle(fontSize: 13), // [OCR 수정]
                              ),
                            ),
                            Text(
                              // [OCR 수정]
                              _formatWon(total), // [OCR 수정]
                              style: const TextStyle(
                                // [OCR 수정]
                                fontFamily: 'Jua', // [OCR 수정]
                                fontSize: 23, // [OCR 수정]
                                color: AppColors.coral, // [OCR 수정]
                              ), // [OCR 수정]
                            ), // [OCR 수정]
                          ],
                        ),
                      ),
                    ), // [OCR 수정]
                    TextButton.icon(
                      // [OCR 수정]
                      onPressed: _saving ? null : _addLine, // [OCR 수정]
                      icon: const Icon(Icons.add), // [OCR 수정]
                      label: const Text('품목 추가'), // [OCR 수정]
                    ), // [OCR 수정]
                    if (_activePhoto != null) // [OCR 추가]
                      TextButton.icon(
                        // [OCR 수정]
                        onPressed: _saving
                            ? null
                            : () => _selectFromReceipt(), // [OCR 수정]
                        icon: const Icon(Icons.receipt_long), // [OCR 수정]
                        label: const Text('영수증에서 항목 추가'), // [OCR 수정]
                      ), // [OCR 추가]
                    ExpansionTile(
                      // [OCR 수정]
                      title: const Text(
                        // [OCR 수정]
                        '가격 비교·공유 설정', // [OCR 수정]
                        style: TextStyle(fontSize: 14), // [OCR 수정]
                      ), // [OCR 수정]
                      children: [
                        // [OCR 수정]
                        TextField(
                          // [OCR 수정]
                          controller: _condition, // [OCR 수정]
                          maxLength: 120, // [OCR 수정]
                          decoration: const InputDecoration(
                            // [OCR 수정]
                            labelText: '할인 조건 (선택)', // [OCR 수정]
                          ), // [OCR 수정]
                        ), // [OCR 수정]
                        SwitchListTile(
                          // [OCR 수정]
                          contentPadding: EdgeInsets.zero, // [OCR 수정]
                          value: widget.draft.share, // [OCR 수정]
                          onChanged:
                              _saving // [OCR 수정]
                              ? null // [OCR 수정]
                              : (value) => // [OCR 수정]
                                setState(
                                  () => widget.draft.share = value,
                                ), // [OCR 수정]
                          title: const Text('비교 가능한 가격을 익명 공개'), // [OCR 수정]
                          subtitle: const Text(
                            '계정 정보와 원본 사진은 공개하지 않아요.',
                          ), // [OCR 수정]
                        ), // [OCR 수정]
                      ], // [OCR 수정]
                    ), // [OCR 수정]
                  ],
                ), // [OCR 수정]
              ), // [OCR 수정]
            ], // [OCR 수정]
          ), // [OCR 수정]
        ), // [OCR 수정]
      ),
    );
  }
}

class _ReceiptLineCard extends StatelessWidget {
  const _ReceiptLineCard({
    required this.line,
    required this.items,
    required this.index,
    required this.onChanged,
    required this.onEditSpec,
    required this.onDelete,
  });

  final ReceiptLineDraft line;
  final List<AppRow> items;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onEditSpec;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: line.selected,
                  onChanged: (value) {
                    line.selected = value ?? false;
                    onChanged();
                  },
                ),
                Expanded(
                  child: Text(
                    '항목 ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: '항목 삭제',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('receipt-title-${line.id}'),
              initialValue: line.title,
              maxLength: 50,
              decoration: const InputDecoration(labelText: '상품명'),
              onChanged: (value) => line.title = value,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ReceiptQuantityEditor(
                    // [OCR 수정]
                    lineId: line.id, // [OCR 추가]
                    quantity: line.quantity, // [OCR 추가]
                    onChanged: (value) {
                      // [OCR 수정]
                      line.quantity = value; // [OCR 수정]
                      // [OCR 수정] 단가 입력은 수량을 바꿔도 단가를 유지하고 결제금액을 계산한다.
                      if (line.ocrAmountIsUnitPrice &&
                          line.ocrInputAmount != null) {
                        line.total =
                            line.ocrInputAmount! * line.quantity; // [OCR 수정]
                      }
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    // [OCR 수정] 이유: 수량 변경으로 계산한 총액을 입력칸에도 반영하되 총액을 타이핑할 때는 필드를 다시 만들지 않는다.
                    key: ValueKey(
                      // [OCR 수정]
                      'receipt-total-${line.id}-${line.quantity}', // [OCR 수정]
                    ), // [OCR 수정]
                    initialValue: '${line.total}',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: '상품 결제금액'),
                    onChanged: (value) {
                      line.total = int.tryParse(value) ?? -1; // [OCR 수정]
                      // [OCR 추가] 이유: 총액 직접 수정 뒤에는 수량을 바꿔도 총액을 유지하며 개당 가격을 계산한다.
                      line.ocrAmountIsUnitPrice = false; // [OCR 추가]
                      line.ocrInputAmount = line.total; // [OCR 추가]
                      onChanged();
                    }, // [OCR 수정]
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              line.unitPrice == null
                  ? '개당 가격: 수량·금액을 확인해주세요'
                  : '개당 가격: ${_formatWon(line.unitPrice!)}',
            ), // [OCR 수정]
            const SizedBox(height: 8), // [OCR 수정]
            DropdownButtonFormField<String>(
              initialValue: items.any((item) => item.id == line.itemId)
                  ? line.itemId
                  : '',
              decoration: const InputDecoration(labelText: '장보기 항목 연결'),
              items: [
                const DropdownMenuItem(value: '', child: Text('연결 없이 가격만 기록')),
                ...items.map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.title} · ${item.quantity ?? 1}개'),
                  ),
                ),
              ],
              onChanged: (value) => line.itemId = value ?? '',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onEditSpec,
                icon: const Icon(Icons.tune),
                label: Text(
                  line.spec?.isComparable == true
                      ? '가격 비교 조건 완료'
                      : '제품·용량 조건 입력',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [OCR 추가] 입력 중인 글자를 유지하며 버튼으로 바꾼 수량도 같은 입력칸에 반영한다.
class _ReceiptQuantityEditor extends StatefulWidget {
  const _ReceiptQuantityEditor({
    required this.lineId,
    required this.quantity,
    required this.onChanged,
  });
  final String lineId;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  State<_ReceiptQuantityEditor> createState() => _ReceiptQuantityEditorState();
}

class _ReceiptQuantityEditorState extends State<_ReceiptQuantityEditor> {
  late final TextEditingController _quantity = TextEditingController(
    text: '${widget.quantity}',
  );

  @override
  void didUpdateWidget(covariant _ReceiptQuantityEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // [OCR 추가] 빈 직접 입력은 검증까지 유지하고 버튼 변경 때만 표시를 갱신한다.
    if (widget.quantity != (int.tryParse(_quantity.text) ?? 0)) {
      _quantity.text = '${widget.quantity}';
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _changeQuantity(int delta) {
    // [OCR 추가] 인식 실패의0에서 늘리면1이 되지만 확인 전 원본 항목에는 적용하지 않는다.
    final next = (widget.quantity + delta).clamp(1, 999);
    _quantity.text = '$next';
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final arrowStyle = IconButton.styleFrom(
      // [OCR 추가] 기존 OCR 버튼 색상·터치 크기를 사용한다.
      backgroundColor: AppColors.secondary,
      foregroundColor: AppColors.primary,
      disabledBackgroundColor: AppColors.surface,
      disabledForegroundColor: AppColors.muted,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            key: ValueKey('receipt-quantity-${widget.lineId}'),
            controller: _quantity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: '수량'),
            onChanged: (value) => widget.onChanged(int.tryParse(value) ?? 0),
          ),
        ),
        const SizedBox(width: 4),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('receipt-quantity-up-${widget.lineId}'),
              tooltip: '수량 늘리기',
              style: arrowStyle,
              onPressed: widget.quantity >= 999
                  ? null
                  : () => _changeQuantity(1),
              icon: const Icon(Icons.arrow_drop_up),
            ),
            const SizedBox(height: 4),
            IconButton(
              key: ValueKey('receipt-quantity-down-${widget.lineId}'),
              tooltip: '수량 줄이기',
              style: arrowStyle,
              onPressed: widget.quantity <= 1
                  ? null
                  : () => _changeQuantity(-1),
              icon: const Icon(Icons.arrow_drop_down),
            ),
          ],
        ),
      ],
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.store, this.onShopping});

  final VoidCallback? onShopping;

  final AppStore store;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  int _filter = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit(AppRow row) async {
    final purchase = row.purchase!;
    final current = purchase.spec ?? ProductSpec(identity: row.title);
    final title = TextEditingController(text: row.title);
    final identity = TextEditingController(text: current.identity);
    final volume = TextEditingController(
      text: current.volume?.toString() ?? '',
    );
    final unit = TextEditingController(text: current.unit);
    final pack = TextEditingController(text: '${current.packCount}');
    final condition = TextEditingController(text: purchase.condition);
    var conditionKnown = current.conditionKnown;
    var allocated = current.allocated;
    var share = purchase.share;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('구매 기록 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: '표시 상품명'),
                ),
                TextField(
                  controller: identity,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: '확인한 제품명'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: volume,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: '낱개 용량'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unit,
                        maxLength: 12,
                        decoration: const InputDecoration(labelText: '단위'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pack,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '묶음 수량'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: condition,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: '할인 조건'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: conditionKnown,
                  onChanged: (value) =>
                      setDialogState(() => conditionKnown = value ?? false),
                  title: const Text('할인 조건 확인 완료'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: allocated,
                  onChanged: (value) =>
                      setDialogState(() => allocated = value ?? false),
                  title: const Text('전체 할인 배분 완료'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: share,
                  onChanged: (value) => setDialogState(() => share = value),
                  title: const Text('가격 익명 공개'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await widget.store.updatePurchase(
          row,
          title: title.text,
          spec: ProductSpec(
            identity: identity.text.trim(),
            volume: double.tryParse(volume.text),
            unit: unit.text.trim(),
            packCount: int.tryParse(pack.text) ?? 1,
            conditionKnown: conditionKnown,
            allocated: allocated,
          ),
          condition: condition.text,
          share: share,
        );
      } catch (error) {
        if (mounted) _showError(context, error);
      }
    }
    title.dispose();
    identity.dispose();
    volume.dispose();
    unit.dispose();
    pack.dispose();
    condition.dispose();
  }

  void _showShared(AppRow row) {
    showDialog<void>(
      context: context,
      builder: (_) => _SharedPriceDialog(
        future: widget.store.cloud.sharedPrices(row.purchase!),
        base: row.purchase!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final query = normalizedProduct(_search.text);
        final month = DateFormat('yyyy-MM').format(DateTime.now());
        final groups = widget.store.purchaseGroups.where((group) {
          final matches =
              query.isEmpty ||
              normalizedProduct(group.store).contains(query) ||
              group.rows.any(
                (row) => normalizedProduct(row.title).contains(query),
              );
          return matches &&
              (_filter != 1 || group.purchasedOn.startsWith(month));
        }).toList();
        final drop = _priceDrop();
        if (_filter == 2) groups.sort((a, b) => a.total.compareTo(b.total));
        return Scaffold(
          bottomNavigationBar: widget.onShopping == null
              ? null
              : DesignNavigation(
                  index: 1,
                  onChanged: (_) => widget.onShopping!(),
                ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Row(
                      children: [
                        if (widget.onShopping == null) const DesignBackButton(),
                        Expanded(
                          child: Text(
                            '지난 장보기',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ),
                        IconButton.filled(
                          tooltip: '영수증 찍기',
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReceiptCaptureScreen(store: widget.store),
                            ),
                          ),
                          icon: const DesignIcon(
                            'IconCamera',
                            screen: '34-296',
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '언제 어디서 얼마였는지 모아봤어요.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(14),
                          child: DesignIcon('IconSearch', screen: '34-296'),
                        ),
                        hintText: '상품명이나 매장 찾기',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var index = 0; index < 3; index++)
                          ChoiceChip(
                            label: Text(['전체', '이번 달', '낮은 가격순'][index]),
                            selected: _filter == index,
                            onSelected: (_) => setState(() => _filter = index),
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (groups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: Text('저장된 구매 기록이 없습니다.')),
                      ),
                    for (final dateGroup in _groupByMonth(groups).entries) ...[
                      Text(
                        dateGroup.key,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      PaperCard(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < dateGroup.value.length;
                              index++
                            ) ...[
                              if (index > 0)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Divider(height: 1),
                                ),
                              _receiptTile(dateGroup.value[index]),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (drop != null) ...[
                      PaperCard(
                        color: AppColors.note,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PriceComparisonScreen(
                                store: widget.store,
                                base: drop.row,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const DesignIcon('IconChart', screen: '34-296'),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${drop.row.title} 가격, 내려갔어요',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '지난번보다 ${_formatWon(-drop.delta)} 저렴해요',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const DesignIcon(
                                  'IconChevron',
                                  screen: '34-296',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    const Text(
                      '영수증을 찍으면 다음 가격도 기억해둘게요.',
                      style: TextStyle(
                        fontFamily: 'Gaegu',
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, List<PurchaseGroup>> _groupByMonth(List<PurchaseGroup> groups) {
    final result = <String, List<PurchaseGroup>>{};
    for (final group in groups) {
      final date = DateTime.parse(group.purchasedOn);
      final key = date.year == DateTime.now().year
          ? '${date.month}월'
          : '${date.year}년 ${date.month}월';
      result.putIfAbsent(key, () => []).add(group);
    }
    return result;
  }

  ({AppRow row, double delta})? _priceDrop() {
    final rows = [...widget.store.purchaseRows]
      ..sort(
        (a, b) => b.purchase!.purchasedOn.compareTo(a.purchase!.purchasedOn),
      );
    final latestByProduct = <String, AppRow>{};
    for (final row in rows) {
      final latest = latestByProduct.putIfAbsent(
        normalizedProduct(row.title),
        () => row,
      );
      if (latest.id == row.id) continue;
      final comparison = comparePrices(row.purchase!, latest.purchase!);
      if (comparison.issue.isEmpty && comparison.delta! < 0) {
        return (row: latest, delta: comparison.delta!);
      }
    }
    return null;
  }

  Widget _receiptTile(PurchaseGroup group) {
    final date = DateTime.parse(group.purchasedOn);
    return InkWell(
      onTap: () => _openReceipt(group),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${date.month}.${date.day}',
                style: const TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.store,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.rows.first.title}${group.rows.length > 1 ? ' 외 ${group.rows.length - 1}개' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatWon(group.total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  void _openReceipt(PurchaseGroup group) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                group.store,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(group.purchasedOn),
              const SizedBox(height: 16),
              for (final row in group.rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.title),
                  subtitle: Text(
                    '${row.purchase!.setParentId.isEmpty ? '' : '세트 구성품 · '}${row.purchase!.quantity}개 · ${_formatWon(row.purchase!.total)}', // [OCR 수정]
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(
                        builder: (_) => PriceComparisonScreen(
                          store: widget.store,
                          base: row,
                        ),
                      ),
                    );
                  },
                  trailing: PopupMenuButton<String>(
                    icon: const DesignIcon('IconMore'),
                    onSelected: (value) {
                      Navigator.pop(context);
                      value == 'edit' ? _edit(row) : _showShared(row);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('기록 수정 · 공유 설정'),
                      ),
                      PopupMenuItem(
                        value: 'shared',
                        child: Text('다른 매장 최근 가격'),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Text(
                '모두 합쳐 ${_formatWon(group.total)}',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedPriceDialog extends StatelessWidget {
  const _SharedPriceDialog({required this.future, required this.base});

  final Future<List<SharedPriceRecord>> future;
  final PurchaseData base;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('다른 매장 최근 등록 가격'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<SharedPriceRecord>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text(CloudService.readableError(snapshot.error!));
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) return const Text('비교 가능한 공개 기록이 없습니다.');
            return ListView.separated(
              shrinkWrap: true,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final row = rows[index];
                final comparison = comparePrices(base, row.purchase);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${row.purchase.store} · ${_formatWon(row.purchase.unitPrice)}',
                  ),
                  subtitle: Text(
                    '${row.purchase.purchasedOn} · ${comparison.delta! >= 0 ? '+' : ''}${_formatWon(comparison.delta!)} (${comparison.percent!.toStringAsFixed(1)}%)',
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
