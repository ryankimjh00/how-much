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
  String _cameraError = '';

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
    } catch (_) {
      if (mounted && session == _cameraSession) {
        setState(() => _cameraError = '카메라 권한이 필요해요. 설정에서 허용하거나 앨범에서 선택해주세요.');
      }
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    if (widget.memo) {
      await _recognizeMemo(
        () async => _ocr.recognizeMemoPath((await camera.takePicture()).path),
      );
      return;
    }
    await _recognize(
      () async => _ocr.recognizePath((await camera.takePicture()).path),
    );
  }

  Future<void> _gallery() async {
    if (widget.memo) {
      await _recognizeMemo(() => _ocr.pickMemo(ImageSource.gallery));
      return;
    }
    await _recognize(_ocr.pickFromGallery);
  }

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
    setState(() => _busy = true);
    try {
      final draft = await action();
      if (draft != null && mounted) await _openReview(draft);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openReview(ReceiptDraft draft) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiptReviewScreen(store: widget.store, draft: draft),
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
                            onTap: _busy ? null : _gallery,
                          ),
                          Semantics(
                            button: true,
                            label: widget.memo ? '메모 촬영' : '영수증 촬영',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap:
                                  _busy ||
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
                          widget.memo ? '메모를 읽고 있어요' : '영수증을 읽고 있어요',
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
  String _error = '';

  @override
  void dispose() {
    _recovery.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || widget.store.saving || widget.store.syncing) return;
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
    // 화면을 닫아 코드를 놓치지 않도록 보관 확인을 먼저 받는다.
    if (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('복구 코드를 보관해주세요'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('다른 기기에서 같은 기록을 열 때 필요해요. 이 코드는 한 번만 표시돼요.'),
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
                child: const Text('코드를 보관했어요'),
              ),
            ],
          ),
        ),
      );
    }
    await widget.store.reloadForCurrentAccount();
    if (await widget.store.hasGuestData()) await widget.store.importGuestData();
    await widget.store.sync();
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
                if (cloud.sessionExpired) ...[
                  const SizedBox(height: 12),
                  const Text('세션이 만료됐어요. 기록을 유지하며 복구 코드로 다시 연결해주세요.'),
                  TextField(
                    controller: _recovery,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(labelText: '보관한 복구 코드'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await cloud.restoreRecoveryAccount(_recovery.text);
                            _recovery.clear();
                            await widget.store.reloadForCurrentAccount();
                            await widget.store.sync();
                          }),
                    child: const Text('복구 코드로 다시 연결'),
                  ),
                ],
                if (cloud.usesRecoveryCode)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '새 기기에서는 보관한 복구 코드를 입력해주세요. 코드를 잃어버리면 로그아웃하지 마세요.',
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
                          if (mounted) setState(() {});
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
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await cloud.restoreRecoveryAccount(_recovery.text);
                          _recovery.clear();
                          await widget.store.reloadForCurrentAccount();
                          await widget.store.sync();
                        }),
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

  void _addLine() {
    setState(
      () => widget.draft.lines.add(
        ReceiptLineDraft(
          id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
          title: '',
        ),
      ),
    );
  }

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

  Future<void> _editLine(ReceiptLineDraft line, int index) async {
    final items = widget.store.shoppingItems
        .where((item) => !item.completed)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReceiptLineCard(
                line: line,
                items: items,
                index: index,
                onChanged: () => setState(() {}),
                onEditSpec: () => _editSpec(line),
                onDelete: () {
                  setState(() => widget.draft.lines.remove(line));
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인했어요'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '가격만 한번 확인해 주세요',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontSize: 25),
            ),
            const SizedBox(height: 4),
            const Text(
              '다르면 해당 금액만 톡 눌러 고치면 돼요.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            const Text('어디서 샀나요?'),
            const SizedBox(height: 8),
            TextField(
              controller: _store,
              maxLength: 50,
              decoration: const InputDecoration(
                counterText: '',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(14),
                  child: DesignIcon('IconStore', screen: '34-248'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('언제 샀나요?'),
            const SizedBox(height: 8),
            TextField(
              controller: _date,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                prefixIcon: Padding(
                  padding: EdgeInsets.all(14),
                  child: DesignIcon('IconCalendar', screen: '34-248'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '산 품목',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Text('$count개', style: const TextStyle(color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 12),
            PaperCard(
              child: Column(
                children: [
                  for (var index = 0; index < lines.length; index++) ...[
                    if (index > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 1),
                      ),
                    ListTile(
                      onTap: _saving
                          ? null
                          : () => _editLine(lines[index], index),
                      title: Text(
                        lines[index].title.isEmpty
                            ? '상품명을 입력해주세요'
                            : lines[index].title,
                        style: TextStyle(
                          fontSize: 14,
                          color: lines[index].selected
                              ? AppColors.ink
                              : AppColors.muted,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lines[index].selected
                                ? _formatWon(lines[index].total)
                                : '제외',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          const DesignIcon('IconEdit', screen: '34-248'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            PaperCard(
              color: AppColors.note,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('모두 합쳐', style: TextStyle(fontSize: 13)),
                    ),
                    Text(
                      _formatWon(total),
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
            TextButton.icon(
              onPressed: _saving ? null : _addLine,
              icon: const Icon(Icons.add),
              label: const Text('품목 추가'),
            ),
            ExpansionTile(
              title: const Text('가격 비교·공유 설정', style: TextStyle(fontSize: 14)),
              children: [
                TextField(
                  controller: _condition,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: '할인 조건 (선택)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: widget.draft.share,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => widget.draft.share = value),
                  title: const Text('비교 가능한 가격을 익명 공개'),
                  subtitle: const Text('계정 정보와 원본 사진은 공개하지 않아요.'),
                ),
              ],
            ),
          ],
        ),
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
                  child: TextFormField(
                    key: ValueKey('receipt-quantity-${line.id}'),
                    initialValue: '${line.quantity}',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: '수량'),
                    onChanged: (value) =>
                        line.quantity = int.tryParse(value) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('receipt-total-${line.id}'),
                    initialValue: '${line.total}',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: '상품 결제금액'),
                    onChanged: (value) =>
                        line.total = int.tryParse(value) ?? -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                    '${row.purchase!.quantity}개 · ${_formatWon(row.purchase!.total)}',
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
