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
    useSafeArea: true,
    builder: (_) => _AccountSheet(store: store),
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

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final value = _draft.text;
    if (value.trim().isEmpty) return;
    try {
      await widget.store.addItem(value);
      _draft.clear();
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _openCapture() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptCaptureScreen(store: widget.store),
      ),
    );
  }

  Future<void> _openMemo() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemoImportScreen(store: widget.store)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        final active = items.where((item) => !item.completed).toList();
        final completed = items.where((item) => item.completed).toList();
        final allCount = store.shoppingItems.length;
        final progress = allCount == 0 ? 0.0 : store.completedCount / allCount;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '얼마였지',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '오늘 살 것을 가볍게 적어두세요.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '더보기',
                            onSelected: (value) {
                              if (value == 'account') {
                                _showAccount(context, store);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'account',
                                child: Text('계정 · 동기화'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _draft,
                            enabled: !store.saving,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _add(),
                            decoration: const InputDecoration(
                              hintText: '상품명을 입력하세요',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: store.saving ? null : _add,
                          child: const Text('추가'),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '기기에 자동 저장돼요',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '오늘 장보기 · ${store.completedCount}/$allCount 완료',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: AppColors.checked,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                      backgroundColor: AppColors.secondary,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.checked,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FilterBar(store: store),
                    if (store.error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _MessageBox(message: store.error, error: true),
                    ],
                    const SizedBox(height: 18),
                    if (active.isNotEmpty) ...[
                      _SectionTitle(title: '살 것', count: active.length),
                      const SizedBox(height: 8),
                      for (final item in active) ...[
                        _ShoppingItemCard(store: store, item: item),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _SectionTitle(title: '구매 완료', count: completed.length),
                      const SizedBox(height: 8),
                      for (final item in completed) ...[
                        _ShoppingItemCard(store: store, item: item),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (items.isEmpty) const _EmptyShopping(),
                    const SizedBox(height: 18),
                    _NavigationCard(
                      icon: Icons.note_add_outlined,
                      title: '메모 사진에서 가져오기',
                      description: '인식 결과를 확인한 뒤 목록에 추가해요',
                      onTap: _openMemo,
                    ),
                    const SizedBox(height: 10),
                    _NavigationCard(
                      icon: Icons.document_scanner_outlined,
                      title: '영수증으로 구매 기록',
                      description: '촬영 한 번으로 품목과 가격을 불러와요',
                      onTap: _openCapture,
                    ),
                    const SizedBox(height: 10),
                    _NavigationCard(
                      icon: Icons.show_chart_outlined,
                      title: '지난 가격 보기',
                      description: '언제, 어디서, 얼마였는지 확인해요',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HistoryScreen(store: store),
                        ),
                      ),
                    ),
                    if (store.syncMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        store.syncMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    const labels = {
      ShoppingFilter.all: '전체',
      ShoppingFilter.active: '살 것',
      ShoppingFilter.completed: '완료',
    };
    return Wrap(
      spacing: 8,
      children: labels.entries.map((entry) {
        final selected = store.filter == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: selected,
          onSelected: (_) => store.setFilter(entry.key),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.body,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        Text('$count', style: Theme.of(context).textTheme.bodyMedium),
      ],
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
      color: item.completed ? AppColors.secondary : AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: store.saving
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
              Checkbox(
                value: item.completed,
                onChanged: store.saving
                    ? null
                    : (_) async {
                        try {
                          await store.toggleItem(item);
                        } catch (error) {
                          if (context.mounted) _showError(context, error);
                        }
                      },
                activeColor: AppColors.checked,
                shape: const CircleBorder(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: item.completed ? AppColors.muted : AppColors.ink,
                        decoration: item.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      item.completed
                          ? '구매 완료'
                          : '${item.quantity ?? 1}개${item.note.isEmpty ? '' : ' · ${item.note}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '${item.title} 메뉴',
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
                            onPressed: () => store.restoreItem(item),
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
            '상품을 추가하거나 영수증을 불러오세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? '상품 추가' : '상품 수정')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '장보기 목록에 추가할 정보를 입력하세요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: '상품명',
                  hintText: '예: 우유',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '수량'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: 80,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  hintText: '예: 저지방으로',
                ),
              ),
              const SizedBox(height: 8),
              const _MessageBox(message: '저장 후에도 언제든 수정할 수 있어요.'),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(widget.item == null ? '목록에 추가' : '저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReceiptCaptureScreen extends StatefulWidget {
  const ReceiptCaptureScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ReceiptCaptureScreen> createState() => _ReceiptCaptureScreenState();
}

class _ReceiptCaptureScreenState extends State<ReceiptCaptureScreen>
    with WidgetsBindingObserver {
  final _ocr = OcrService();
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
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      camera.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
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
      if (!mounted) return controller.dispose();
      await _camera?.dispose();
      setState(() {
        _camera = controller;
        _cameraError = '';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = '카메라 권한이 필요해요. 설정에서 허용하거나 앨범에서 선택해주세요.');
      }
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    await _recognize(
      () async => _ocr.recognizePath((await camera.takePicture()).path),
    );
  }

  Future<void> _gallery() async {
    await _recognize(_ocr.pickFromGallery);
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
    _torch = !_torch;
    await camera.setFlashMode(_torch ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: const Color(0xFF12251C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && camera.value.isInitialized)
            CameraPreview(camera)
          else
            const ColoredBox(color: Color(0xFF12251C)),
          ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          '영수증 촬영',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: camera == null ? null : _toggleTorch,
                        icon: Icon(
                          _torch ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '영수증 전체가 네모 안에 오도록',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 52),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: const Color(0xFF79E86A),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '구김을 펴고 그림자를 피해주세요.',
                    style: TextStyle(color: AppColors.secondary, fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CameraAction(
                            icon: Icons.photo_library_outlined,
                            label: '앨범',
                            onTap: _busy ? null : _gallery,
                          ),
                          Semantics(
                            button: true,
                            label: '영수증 촬영',
                            child: InkWell(
                              onTap: _busy ? null : _capture,
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 74,
                                height: 74,
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 4,
                                  ),
                                ),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.checked,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _CameraAction(
                            icon: Icons.edit_outlined,
                            label: '직접 입력',
                            onTap: _busy
                                ? null
                                : () => _openReview(
                                    ReceiptDraft(
                                      id: DateTime.now().microsecondsSinceEpoch
                                          .toString(),
                                      store: '',
                                      purchasedOn: DateTime.now()
                                          .toIso8601String()
                                          .substring(0, 10),
                                      lines: [
                                        ReceiptLineDraft(
                                          id: 'manual-0',
                                          title: '',
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _cameraError.isEmpty
                            ? '촬영 후 품목과 가격을 확인할 수 있어요.'
                            : _cameraError,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: _cameraError.isEmpty
                              ? AppColors.muted
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            ColoredBox(
              color: const Color(0xFF12251C).withValues(alpha: 0.92),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.checked),
                    SizedBox(height: 18),
                    Text(
                      '영수증을 읽고 있어요',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '앱을 닫지 말고 잠시만 기다려주세요.',
                      style: TextStyle(color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({required this.store});

  final AppStore store;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
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

  @override
  Widget build(BuildContext context) {
    final user = widget.store.cloud.user;
    return Padding(
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
            Text('계정 · 동기화', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (!widget.store.cloudConfigured) ...[
              const _MessageBox(
                message:
                    'Firebase 설정 없이 실행 중입니다. 장보기와 구매 기록은 이 기기에 안전하게 저장됩니다.',
              ),
              const SizedBox(height: 12),
              Text(
                '로그인과 기기 간 동기화는 README의 --dart-define 설정 후 사용할 수 있어요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else if (user != null) ...[
              _MessageBox(message: '${user.email ?? '이메일 계정'}으로 로그인했습니다.'),
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
              if (widget.store.rows.where((row) => !row.deleted).isEmpty)
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
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: '이메일'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: '비밀번호'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await widget.store.cloud.signIn(
                          _email.text,
                          _password.text,
                          create: false,
                        );
                        await widget.store.reloadForCurrentAccount();
                        await widget.store.sync();
                        if (mounted) setState(() {});
                      }),
                child: const Text('로그인'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await widget.store.cloud.signIn(
                          _email.text,
                          _password.text,
                          create: true,
                        );
                        await widget.store.reloadForCurrentAccount();
                        await widget.store.sync();
                        if (mounted) setState(() {});
                      }),
                child: const Text('회원가입'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.store.cloud.resetPassword(_email.text),
                      ),
                child: const Text('비밀번호 재설정 메일 보내기'),
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
  const MemoImportScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<MemoImportScreen> createState() => _MemoImportScreenState();
}

class _MemoImportScreenState extends State<MemoImportScreen> {
  final _ocr = OcrService();
  List<MemoLineDraft> _lines = [];
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final lines = await _ocr.pickMemo(source);
      if (lines != null && mounted) setState(() => _lines = lines);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    try {
      await widget.store.addMemoItems(_lines);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메모에서 가져오기')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _MessageBox(
                    message: '사진은 기기 안에서만 인식합니다. 결과를 확인한 뒤 선택한 상품만 추가돼요.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('촬영'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('앨범'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: _lines.isEmpty
                  ? const Center(child: Text('메모를 촬영하거나 앨범에서 선택해주세요.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final line = _lines[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: line.selected,
                                  onChanged: (value) => setState(
                                    () => line.selected = value ?? false,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        key: ValueKey('memo-title-$index'),
                                        initialValue: line.title,
                                        maxLength: 50,
                                        decoration: const InputDecoration(
                                          labelText: '상품명',
                                        ),
                                        onChanged: (value) =>
                                            line.title = value,
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        key: ValueKey('memo-quantity-$index'),
                                        initialValue: '${line.quantity}',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: '수량',
                                        ),
                                        onChanged: (value) => line.quantity =
                                            int.tryParse(value) ?? 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: _busy || _lines.isEmpty ? null : _save,
                child: Text(
                  '선택 ${_lines.where((line) => line.selected).length}개 추가',
                ),
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

  @override
  Widget build(BuildContext context) {
    final items = widget.store.shoppingItems
        .where((item) => !item.completed)
        .toList();
    final selectedCount = widget.draft.lines
        .where((line) => line.selected)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('영수증 검토')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _MessageBox(
              message: '인식 결과는 자동 확정되지 않습니다. 저장할 항목과 금액을 직접 확인해주세요.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _store,
              maxLength: 50,
              decoration: const InputDecoration(labelText: '매장명'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _date,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: '구매일',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _condition,
              maxLength: 120,
              decoration: const InputDecoration(labelText: '할인 조건 (선택)'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '구매 항목 · $selectedCount개 선택',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add),
                  label: const Text('항목 추가'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < widget.draft.lines.length; index++) ...[
              _ReceiptLineCard(
                line: widget.draft.lines[index],
                items: items,
                index: index,
                onChanged: () => setState(() {}),
                onEditSpec: () => _editSpec(widget.draft.lines[index]),
                onDelete: () =>
                    setState(() => widget.draft.lines.removeAt(index)),
              ),
              const SizedBox(height: 10),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: widget.draft.share,
              onChanged: (value) => setState(() => widget.draft.share = value),
              title: const Text('비교 가능한 가격을 익명 공개'),
              subtitle: const Text('계정·목록 정보와 원본 사진은 공개하지 않습니다.'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('구매 기록 저장'),
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
  const HistoryScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();

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
        future: widget.store.cloud.sharedPrices(
          row.purchase!,
          widget.store.purchaseRows.map((row) => row.id).toSet(),
        ),
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
        final rows =
            widget.store.purchaseRows.where((row) {
              final purchase = row.purchase!;
              return query.isEmpty ||
                  normalizedProduct(row.title).contains(query) ||
                  normalizedProduct(purchase.store).contains(query);
            }).toList()..sort(
              (a, b) =>
                  b.purchase!.purchasedOn.compareTo(a.purchase!.purchasedOn),
            );
        return Scaffold(
          appBar: AppBar(title: const Text('지난 가격')),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '상품명 또는 매장 검색',
                    ),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(child: Text('저장된 구매 기록이 없습니다.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            final purchase = row.purchase!;
                            final previous = rows
                                .skip(index + 1)
                                .where(
                                  (candidate) =>
                                      normalizedProduct(candidate.title) ==
                                      normalizedProduct(row.title),
                                )
                                .firstOrNull;
                            final comparison = previous == null
                                ? null
                                : comparePrices(previous.purchase!, purchase);
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            row.title,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) => value == 'edit'
                                              ? _edit(row)
                                              : _showShared(row),
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
                                      ],
                                    ),
                                    Text(
                                      '${purchase.store} · ${purchase.purchasedOn}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${purchase.quantity}개 ${_formatWon(purchase.total)} · 개당 ${_formatWon(purchase.unitPrice)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (purchase.spec != null)
                                      Text(
                                        '${purchase.spec!.identity} · ${purchase.spec!.volume ?? '?'}${purchase.spec!.unit} × ${purchase.spec!.packCount}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (comparison != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        comparison.issue.isEmpty
                                            ? '이전 기록 대비 ${comparison.delta! >= 0 ? '+' : ''}${_formatWon(comparison.delta!)} · ${comparison.percent!.toStringAsFixed(1)}%'
                                            : comparison.issue,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
