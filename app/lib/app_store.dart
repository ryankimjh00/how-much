import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_service.dart';
import 'models.dart';

class PurchaseGroup {
  const PurchaseGroup(this.receiptId, this.rows);

  final String receiptId;
  final List<AppRow> rows;

  String get store => rows.first.purchase!.store;
  String get purchasedOn => rows.first.purchase!.purchasedOn;
  int get total => rows.fold(0, (sum, row) => sum + row.purchase!.total);
}

class ReceiptWarning {
  const ReceiptWarning(this.message);

  final String message;
}

class _StoredState {
  const _StoredState(this.rows, this.conflicts);

  final List<AppRow> rows;
  final List<SyncConflictGroup> conflicts;
}

class AppStore extends ChangeNotifier {
  AppStore(this.cloud);

  static const _legacyStorageKey = '@wasprice/flutter/v1';
  static const _guestStorageKey = '@wasprice/flutter/guest/v1';
  final CloudService cloud;
  final Random _random = Random.secure();
  List<AppRow> _rows = [];
  List<SyncConflictGroup> _conflicts = [];

  bool loading = true;
  bool saving = false;
  bool syncing = false;
  String error = '';
  String syncMessage = '';
  ShoppingFilter filter = ShoppingFilter.all;

  List<AppRow> get rows => List.unmodifiable(_rows);
  List<SyncConflictGroup> get conflicts => List.unmodifiable(_conflicts);
  List<AppRow> get shoppingItems =>
      _rows.where((row) => !row.deleted && !row.isPurchase).toList();
  List<AppRow> get visibleShoppingItems => shoppingItems.where((row) {
    return filter == ShoppingFilter.all ||
        row.completed == (filter == ShoppingFilter.completed);
  }).toList();
  List<AppRow> get purchaseRows =>
      _rows.where((row) => !row.deleted && row.isPurchase).toList();
  int get completedCount => shoppingItems.where((row) => row.completed).length;
  bool get cloudConfigured => cloud.configured;
  String get _storageKey => cloud.user == null
      ? _guestStorageKey
      : '@wasprice/flutter/account/${cloud.user!.uid}/v1';

  List<PurchaseGroup> get purchaseGroups {
    final groups = <String, List<AppRow>>{};
    for (final row in purchaseRows) {
      groups.putIfAbsent(row.purchase!.receiptId, () => []).add(row);
    }
    final result = groups.entries
        .map((entry) => PurchaseGroup(entry.key, entry.value))
        .toList();
    result.sort((a, b) => b.purchasedOn.compareTo(a.purchasedOn));
    return result;
  }

  Future<void> initialize() async {
    await _loadCurrentStorage();
  }

  Future<void> reloadForCurrentAccount() async {
    loading = true;
    error = '';
    _rows = [];
    _conflicts = [];
    notifyListeners();
    await _loadCurrentStorage();
  }

  Future<bool> hasGuestData() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeState(
      prefs.getString(_guestStorageKey) ?? prefs.getString(_legacyStorageKey),
    ).rows.any((row) => !row.deleted);
  }

  Future<void> importGuestData() async {
    if (cloud.user == null) throw const FormatException('로그인 후 가져와주세요.');
    if (_rows.any((row) => !row.deleted)) {
      throw const FormatException('계정에 이미 기록이 있어 자동으로 합치지 않습니다.');
    }
    final prefs = await SharedPreferences.getInstance();
    final guest = _decodeState(
      prefs.getString(_guestStorageKey) ?? prefs.getString(_legacyStorageKey),
    ).rows;
    if (guest.where((row) => !row.deleted).isEmpty) {
      throw const FormatException('가져올 기기 기록이 없습니다.');
    }
    final revision = _revision();
    await _commit(
      guest
          .map(
            (row) => row
                .copyWith(revision: revision)
                .withSync(pending: true, baseRevision: null, group: revision),
          )
          .toList(),
    );
  }

  Future<void> _loadCurrentStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(_storageKey) ??
          (cloud.user == null ? prefs.getString(_legacyStorageKey) : null);
      final state = _decodeState(raw);
      _rows = state.rows;
      _conflicts = state.conflicts;
    } catch (failure) {
      error = failure.toString().replaceFirst('FormatException: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  _StoredState _decodeState(String? raw) {
    if (raw == null) return const _StoredState([], []);
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['version'] != 4 ||
        decoded['rows'] is! List) {
      throw const FormatException('저장 형식을 확인해주세요.');
    }
    final rows = (decoded['rows'] as List)
        .map(
          (value) => AppRow.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList();
    final conflicts = (decoded['conflicts'] as List? ?? [])
        .map(
          (value) => SyncConflictGroup.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
        )
        .toList();
    return _StoredState(rows, conflicts);
  }

  void setFilter(ShoppingFilter value) {
    filter = value;
    notifyListeners();
  }

  Future<void> addItem(
    String title, {
    int quantity = 1,
    String note = '',
  }) async {
    _validateTitle(title);
    if (quantity < 1 || quantity > 999) {
      throw const FormatException('수량은 1~999개로 입력해주세요.');
    }
    final now = DateTime.now().microsecondsSinceEpoch;
    final revision = _revision();
    final row = AppRow(
      id: '$now-${_random.nextInt(1 << 32).toRadixString(36)}',
      title: title.trim(),
      completed: false,
      quantity: quantity,
      note: note.trim(),
      revision: revision,
    ).withSync(pending: true, baseRevision: null, group: revision);
    await _commit([row, ..._rows]);
    filter = ShoppingFilter.all;
  }

  Future<void> addMemoItems(List<MemoLineDraft> lines) async {
    final selected = lines.where((line) => line.selected).toList();
    if (selected.isEmpty) throw const FormatException('추가할 상품을 하나 이상 선택해주세요.');
    for (final line in selected) {
      _validateTitle(line.title);
      if (line.quantity < 1 || line.quantity > 999) {
        throw const FormatException('수량은 1~999개로 입력해주세요.');
      }
    }
    final revision = _revision();
    final now = DateTime.now().microsecondsSinceEpoch;
    final added = <AppRow>[];
    for (var index = 0; index < selected.length; index++) {
      final line = selected[index];
      added.add(
        AppRow(
          id: '${now + index}-${_random.nextInt(1 << 32).toRadixString(36)}',
          title: line.title.trim(),
          completed: false,
          quantity: line.quantity,
          revision: revision,
        ).withSync(pending: true, baseRevision: null, group: revision),
      );
    }
    await _commit([...added, ..._rows]);
    filter = ShoppingFilter.all;
  }

  Future<void> updateItem(
    AppRow item, {
    required String title,
    required int quantity,
    required String note,
  }) async {
    _validateTitle(title);
    if (quantity < 1 || quantity > 999) {
      throw const FormatException('수량은 1~999개로 입력해주세요.');
    }
    await _replace(
      item.copyWith(title: title.trim(), quantity: quantity, note: note.trim()),
    );
  }

  Future<void> toggleItem(AppRow item) =>
      _replace(item.copyWith(completed: !item.completed));

  Future<void> deleteItem(AppRow item) =>
      _replace(item.copyWith(deleted: true));

  Future<void> restoreItem(AppRow item) =>
      _replace(item.copyWith(deleted: false));

  Future<void> saveReceipt(ReceiptDraft draft) async {
    final store = draft.store.trim();
    if (store.isEmpty || store.length > 50) {
      throw const FormatException('매장명은 1~50자로 입력해주세요.');
    }
    final date = DateTime.tryParse(draft.purchasedOn);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date == null ||
        date.toIso8601String().substring(0, 10) != draft.purchasedOn ||
        date.isAfter(today)) {
      throw const FormatException('구매일은 오늘까지의 실제 날짜로 입력해주세요.');
    }
    final selected = draft.lines.where((line) => line.selected).toList();
    if (selected.isEmpty) throw const FormatException('구매한 항목을 하나 이상 선택해주세요.');
    if (draft.condition.length > 120) {
      throw const FormatException('할인 조건은 120자 이내로 입력해주세요.');
    }
    if (selected.any(
      (line) =>
          line.title.trim().isEmpty ||
          line.title.trim().length > 50 ||
          line.quantity < 1 ||
          line.quantity > 999 ||
          line.total < 0 ||
          line.total > 9999999,
    )) {
      throw const FormatException('상품명과 금액을 확인해주세요.');
    }
    if (_rows.any((row) => row.purchase?.receiptId == draft.id)) {
      throw const FormatException('이미 저장한 영수증입니다.');
    }

    final revision = _revision();
    final registeredAt = DateTime.now().toIso8601String();
    final next = [..._rows];
    final ids = <String>{};
    final linkedIds = <String>{};
    for (final line in selected) {
      if (!RegExp(r'^[a-zA-Z0-9-]{1,80}$').hasMatch(line.id) ||
          !ids.add(line.id)) {
        throw const FormatException('영수증 항목 번호를 다시 확인해주세요.');
      }
      final spec = line.spec;
      if (spec != null &&
          (spec.identity.length > 50 ||
              spec.unit.length > 12 ||
              spec.packCount < 1 ||
              spec.packCount > 999 ||
              (spec.volume != null &&
                  (spec.volume! <= 0 || spec.volume! > 1000000)))) {
        throw const FormatException('제품명·용량·단위·묶음 개수를 확인해주세요.');
      }
      if (draft.share && (spec == null || !spec.isComparable)) {
        throw const FormatException('가격 공유 전 제품·용량·단위·할인 조건을 확인해주세요.');
      }
      final targetIndex = line.itemId.isEmpty
          ? -1
          : next.indexWhere(
              (row) =>
                  row.id == line.itemId &&
                  !row.deleted &&
                  !row.isPurchase &&
                  !row.completed,
            );
      if (line.itemId.isNotEmpty &&
          (targetIndex < 0 || !linkedIds.add(line.itemId))) {
        throw const FormatException('연결한 장보기 항목이 변경됐습니다. 다시 선택해주세요.');
      }
      final target = targetIndex < 0 ? null : next[targetIndex];
      if (target != null &&
          _conflicts.any(
            (conflict) =>
                conflict.entries.any((entry) => entry.local.id == target.id),
          )) {
        throw const FormatException('연결한 항목의 동기화 충돌을 먼저 해결해주세요.');
      }
      final purchase = PurchaseData(
        receiptId: draft.id,
        itemId: target?.id ?? '',
        productKey: productKey(spec),
        store: store,
        purchasedOn: draft.purchasedOn,
        quantity: line.quantity,
        total: line.total,
        condition: draft.condition.trim(),
        share: draft.share,
        spec: spec,
        registeredAt: registeredAt,
      );
      final purchaseId = 'purchase-${draft.id}-${line.id}';
      if (next.any((row) => row.id == purchaseId)) {
        throw const FormatException('이미 저장한 영수증 항목입니다.');
      }
      if (target != null) {
        final remaining = (target.quantity ?? 1) - line.quantity;
        next[targetIndex] = _pendingChange(
          target,
          target.copyWith(
            completed: remaining <= 0,
            quantity: remaining <= 0 ? target.quantity : remaining,
          ),
          revision,
        );
        if (remaining > 0) {
          next.insert(
            0,
            AppRow(
              id: 'bought-$purchaseId',
              title: target.title,
              completed: true,
              quantity: line.quantity,
              note: target.note,
              revision: revision,
            ).withSync(pending: true, baseRevision: null, group: revision),
          );
        }
      }
      next.insert(
        0,
        AppRow(
          id: purchaseId,
          title: line.title.trim(),
          completed: true,
          purchase: purchase,
          revision: revision,
        ).withSync(pending: true, baseRevision: null, group: revision),
      );
    }
    await _commit(next);
  }

  List<ReceiptWarning> receiptWarnings(ReceiptDraft draft) {
    final warnings = <ReceiptWarning>[];
    for (final line in draft.lines.where((line) => line.selected)) {
      final duplicates = purchaseRows.where((row) {
        final purchase = row.purchase!;
        return row.title.trim() == line.title.trim() &&
            purchase.store == draft.store.trim() &&
            purchase.purchasedOn == draft.purchasedOn &&
            purchase.quantity == line.quantity &&
            purchase.total == line.total;
      }).length;
      if (duplicates > 0) {
        warnings.add(
          ReceiptWarning(
            '${line.title}: 같은 매장·날짜·수량·금액의 기록이 $duplicates건 있습니다.',
          ),
        );
      }
      final target = shoppingItems
          .where((row) => row.id == line.itemId && !row.completed)
          .firstOrNull;
      if (target != null && line.quantity > (target.quantity ?? 1)) {
        warnings.add(
          ReceiptWarning(
            '${line.title}: 계획보다 ${line.quantity - (target.quantity ?? 1)}개 더 구매했습니다.',
          ),
        );
      }
    }
    return warnings;
  }

  List<AppRow> pricesFor(String title) {
    final key = normalizedProduct(title);
    final result = purchaseRows
        .where((row) => normalizedProduct(row.title) == key)
        .toList();
    result.sort(
      (a, b) => b.purchase!.purchasedOn.compareTo(a.purchase!.purchasedOn),
    );
    return result;
  }

  Future<void> renamePurchase(AppRow row, String title) async {
    _validateTitle(title);
    await _replace(row.copyWith(title: title.trim()));
  }

  Future<void> updatePurchase(
    AppRow row, {
    required String title,
    required ProductSpec spec,
    required String condition,
    required bool share,
  }) async {
    _validateTitle(title);
    if (row.purchase == null) throw const FormatException('구매 기록이 아닙니다.');
    if (condition.length > 120) {
      throw const FormatException('할인 조건은 120자 이내로 입력해주세요.');
    }
    if (share && !spec.isComparable) {
      throw const FormatException('공유 전 제품·용량·단위·할인 조건을 확인해주세요.');
    }
    final purchase = row.purchase!.copyWith(
      productKey: productKey(spec),
      condition: condition.trim(),
      share: share,
      spec: spec,
    );
    await _replace(row.copyWith(title: title.trim(), purchase: purchase));
  }

  Future<void> sync() async {
    if (!cloud.configured || cloud.user == null) return;
    syncing = true;
    syncMessage = '동기화 중…';
    notifyListeners();
    try {
      final result = await cloud.exchange(_rows);
      final next = <String, AppRow>{for (final row in result.rows) row.id: row};
      for (final conflict in result.conflicts) {
        for (final entry in conflict.entries) {
          next[entry.local.id] = entry.local;
        }
      }
      await _writeState(next.values.toList(), result.conflicts);
      _rows = next.values.toList();
      _conflicts = result.conflicts;
      await cloud.publishPrices(result.rows);
      syncMessage = result.conflicts.isEmpty
          ? '동기화 완료'
          : '동기화 충돌 ${result.conflicts.length}건을 확인해주세요.';
    } catch (failure) {
      syncMessage = CloudService.readableError(failure);
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> resolveConflict(String group, {required bool useLocal}) async {
    final conflict = _conflicts
        .where((item) => item.group == group)
        .firstOrNull;
    if (conflict == null) {
      throw const FormatException('충돌 내용이 바뀌었습니다. 다시 확인해주세요.');
    }
    final next = <String, AppRow>{for (final row in _rows) row.id: row};
    final revision = _revision();
    for (final entry in conflict.entries) {
      if (useLocal) {
        next[entry.local.id] = entry.local
            .copyWith(revision: revision)
            .withSync(
              pending: true,
              baseRevision: entry.remote?.revision,
              group: revision,
            );
      } else if (entry.remote == null) {
        next.remove(entry.local.id);
      } else {
        next[entry.remote!.id] = entry.remote!.withSync(
          pending: false,
          baseRevision: entry.remote!.revision,
          group: entry.remote!.revision,
        );
      }
    }
    final remaining = _conflicts.where((item) => item.group != group).toList();
    await _writeState(next.values.toList(), remaining);
    _rows = next.values.toList();
    _conflicts = remaining;
    syncMessage = useLocal ? '이 기기 변경을 다시 전송할 준비가 됐습니다.' : '서버 변경을 적용했습니다.';
    notifyListeners();
  }

  Future<void> _replace(AppRow replacement) async {
    final index = _rows.indexWhere((row) => row.id == replacement.id);
    if (index < 0) throw const FormatException('다른 기기에서 삭제된 항목입니다.');
    if (_conflicts.any(
      (conflict) =>
          conflict.entries.any((entry) => entry.local.id == replacement.id),
    )) {
      throw const FormatException('동기화 충돌을 먼저 해결해주세요. 양쪽 변경을 보관 중입니다.');
    }
    final current = _rows[index];
    final revision = _revision();
    final next = [..._rows]
      ..[index] = _pendingChange(current, replacement, revision);
    await _commit(next);
  }

  AppRow _pendingChange(AppRow current, AppRow replacement, String revision) =>
      replacement
          .copyWith(revision: revision)
          .withSync(
            pending: true,
            baseRevision: current.pending
                ? current.baseRevision
                : current.revision,
            group: revision,
          );

  Future<void> _commit(List<AppRow> next) async {
    if (saving || syncing) {
      throw const FormatException('저장 또는 동기화 중입니다. 잠시 후 다시 시도해주세요.');
    }
    saving = true;
    error = '';
    notifyListeners();
    try {
      await _writeState(next, _conflicts);
      _rows = next;
    } catch (failure) {
      error = failure.toString().replaceFirst('FormatException: ', '');
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> _writeState(
    List<AppRow> rows,
    List<SyncConflictGroup> conflicts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _storageKey,
      jsonEncode({
        'version': 4,
        'rows': rows.map((row) => row.toJson()).toList(),
        'conflicts': conflicts.map((conflict) => conflict.toJson()).toList(),
      }),
    );
    if (!saved) throw const FormatException('기기에 저장하지 못했습니다. 다시 시도해주세요.');
  }

  void _validateTitle(String title) {
    final value = title.trim();
    if (value.isEmpty ||
        value.length > 50 ||
        value.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('상품명은 한 줄 1~50자로 입력해주세요.');
    }
  }

  String _revision() {
    final latest = _rows.fold<int>(
      0,
      (value, row) =>
          max(value, int.tryParse(row.revision.split(':').first) ?? 0),
    );
    final time = max(
      DateTime.now().millisecondsSinceEpoch,
      latest + 1,
    ).toString().padLeft(16, '0');
    return '$time:${_random.nextInt(1 << 32).toRadixString(36)}';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
