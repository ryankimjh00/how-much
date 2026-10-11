import 'dart:async';
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
  final Map<String, String> _publishedRevisions = {};
  String? _accountId;
  int _session = 0;
  bool _storageHealthy = true;
  bool _active = true;
  bool _disposed = false;
  Timer? _syncTimer;
  Timer? _pollTimer;
  StreamSubscription<Object?>? _authSubscription;
  Future<void>? _loadFuture;

  bool loading = true;
  bool saving = false;
  bool syncing = false;
  String error = '';
  String syncMessage = '';
  DateTime? lastSyncedAt;
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
  bool get canEdit =>
      !_disposed &&
      !loading &&
      !saving &&
      !syncing &&
      _storageHealthy &&
      _accountId == cloud.accountId;
  int get pendingCount => _rows.where((row) => row.pending).length;
  String get _storageKey => _accountId == null
      ? _guestStorageKey
      : '@wasprice/flutter/account/$_accountId/v1';

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
    _accountId = cloud.accountId;
    await _loadCurrentStorage();
    _authSubscription = cloud.authChanges.listen((_) {
      if (_accountId != cloud.accountId) {
        unawaited(reloadForCurrentAccount());
      }
    });
    // 앱이 열린 동안 서버 변경을 확인하고, 오프라인 실패도 다음 주기에 재시도한다.
    if (cloud.configured) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => requestSync(),
      );
    }
    requestSync();
  }

  Future<void> reloadForCurrentAccount() async {
    if (_accountId == cloud.accountId) {
      await _loadFuture;
      return;
    }
    _syncTimer?.cancel();
    _session++;
    _accountId = cloud.accountId;
    loading = true;
    syncing = false;
    lastSyncedAt = null;
    syncMessage = '';
    error = '';
    _rows = [];
    _conflicts = [];
    _publishedRevisions.clear();
    notifyListeners();
    _loadFuture = _loadCurrentStorage();
    await _loadFuture;
    requestSync();
  }

  void setActive(bool active) {
    _active = active;
    if (active) {
      if (_accountId != cloud.accountId) {
        unawaited(reloadForCurrentAccount());
      } else {
        requestSync();
      }
    } else {
      _syncTimer?.cancel();
    }
  }

  void requestSync() {
    _syncTimer?.cancel();
    if (_disposed ||
        !_active ||
        !cloud.canSync ||
        loading ||
        !_storageHealthy) {
      return;
    }
    _syncTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(sync()),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    _syncTimer?.cancel();
    _pollTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<bool> hasGuestData() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeState(
      prefs.getString(_guestStorageKey) ?? prefs.getString(_legacyStorageKey),
    ).rows.any((row) => !row.deleted);
  }

  Future<void> importGuestData() async {
    final session = _session;
    if (!cloud.canSync) throw const FormatException('기록을 연결한 후 가져와주세요.');
    final prefs = await SharedPreferences.getInstance();
    final guest = _decodeState(
      prefs.getString(_guestStorageKey) ?? prefs.getString(_legacyStorageKey),
    ).rows;
    if (guest.where((row) => !row.deleted).isEmpty) {
      throw const FormatException('가져올 기기 기록이 없습니다.');
    }
    final revision = _revision();
    if (session != _session) {
      throw const FormatException('계정이 변경됐습니다. 다시 가져와주세요.');
    }
    // 읽는 동안 받은 서버 기록과 전송 대기 중인 삭제 기록도 덮어쓰지 않는다.
    if (_rows.isNotEmpty || _conflicts.isNotEmpty) {
      throw const FormatException('계정에 이미 기록이 있어 자동으로 합치지 않습니다.');
    }
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
    final session = _session;
    final storageKey = _storageKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(storageKey) ??
          (_accountId == null ? prefs.getString(_legacyStorageKey) : null);
      final state = _decodeState(raw);
      if (session != _session) return;
      _rows = state.rows;
      _conflicts = state.conflicts;
      _storageHealthy = true;
    } catch (failure) {
      if (session != _session) return;
      // 읽지 못한 기존 파일을 빈 목록으로 덮어쓰지 않는다.
      _storageHealthy = false;
      error = '기기 기록을 읽지 못했습니다. 기존 기록을 보존 중입니다.';
    } finally {
      if (session == _session) {
        loading = false;
        notifyListeners();
      }
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

  Future<void> restoreItem(AppRow item) async {
    final current = _rows.where((row) => row.id == item.id).firstOrNull;
    if (current == null) throw const FormatException('복원할 항목이 없습니다.');
    await _replace(current.copyWith(deleted: false));
  }

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

    // [OCR 추가] 선택에서 빠진 기준 항목·순환·중첩 세트는 저장 전에 차단한다.
    for (final line in selected.where((line) => line.setParentId.isNotEmpty)) {
      // [OCR 추가]
      final parent = selected
          .where((candidate) => candidate.id == line.setParentId)
          .firstOrNull; // [OCR 추가]
      if (parent == null ||
          parent.id == line.id ||
          parent.setParentId.isNotEmpty) {
        // [OCR 추가]
        throw const FormatException('세트의 기준 상품과 구성품 선택을 확인해주세요.'); // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]

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
      if (spec != null) _validateSpec(spec);
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
        setParentId: line.setParentId.isEmpty
            ? ''
            : 'purchase-${draft.id}-${line.setParentId}', // [OCR 추가]
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
        .where(
          (row) =>
              row.purchase!.setParentId.isEmpty &&
              normalizedProduct(row.title) == key,
        ) // [OCR 수정] 구성품은 단독 가격 이력에서 제외한다.
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
    _validateSpec(spec);
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
    if (!cloud.canSync || !canEdit) return;
    _syncTimer?.cancel();
    final session = _session;
    final accountId = _accountId;
    final storageKey = _storageKey;
    syncing = true;
    syncMessage = '동기화 중…';
    notifyListeners();
    try {
      final result = await cloud.exchange(_rows);
      // 이전 계정의 늦은 응답을 현재 계정 화면이나 저장소에 적용하지 않는다.
      if (session != _session || accountId != cloud.accountId) return;
      final next = <String, AppRow>{for (final row in result.rows) row.id: row};
      for (final conflict in result.conflicts) {
        for (final entry in conflict.entries) {
          next[entry.local.id] = entry.local;
        }
      }
      await _writeState(
        next.values.toList(),
        result.conflicts,
        storageKey: storageKey,
      );
      if (session != _session || accountId != cloud.accountId) return;
      _rows = next.values.toList();
      _conflicts = result.conflicts;
      lastSyncedAt = DateTime.now();
      // 같은 실행 중에는 변경된 구매 기록만 공유한다. 실패한 기록은 다음 동기화에서 재시도한다.
      final changedPrices = result.rows
          .where(
            (row) =>
                row.isPurchase && _publishedRevisions[row.id] != row.revision,
          )
          .toList();
      if (changedPrices.isNotEmpty) await cloud.publishPrices(changedPrices);
      if (session != _session || accountId != cloud.accountId) return;
      for (final row in changedPrices) {
        _publishedRevisions[row.id] = row.revision;
      }
      syncMessage = result.conflicts.isEmpty
          ? '동기화 완료'
          : '동기화 충돌 ${result.conflicts.length}건을 확인해주세요.';
    } catch (failure) {
      if (session == _session) {
        syncMessage = CloudService.readableError(failure);
      }
    } finally {
      if (session == _session) {
        syncing = false;
        notifyListeners();
      }
    }
  }

  Future<void> resolveConflict(String group, {required bool useLocal}) async {
    if (!canEdit) throw const FormatException('저장 또는 동기화가 끝난 후 다시 시도해주세요.');
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
    await _commit(next.values.toList(), conflicts: remaining);
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
    // 편집 화면을 연 뒤 다른 기기에서 바뀐 항목을 오래된 값으로 덮어쓰지 않는다.
    if (current.revision != replacement.revision) {
      throw const FormatException('항목이 변경됐습니다. 다시 열어 최신 내용을 확인해주세요.');
    }
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

  Future<void> _commit(
    List<AppRow> next, {
    List<SyncConflictGroup>? conflicts,
  }) async {
    if (!_storageHealthy) {
      throw const FormatException('기존 기록을 읽지 못해 새 저장을 중단했습니다.');
    }
    if (!canEdit) {
      throw const FormatException('저장 또는 동기화 중입니다. 잠시 후 다시 시도해주세요.');
    }
    saving = true;
    error = '';
    notifyListeners();
    final session = _session;
    final storageKey = _storageKey;
    try {
      // 기기에 저장한 뒤 화면을 갱신한다. 서버 전송 실패는 로컬 저장을 취소하지 않는다.
      await _writeState(next, conflicts ?? _conflicts, storageKey: storageKey);
      if (session != _session) return;
      _rows = next;
      if (conflicts != null) _conflicts = conflicts;
    } catch (failure) {
      if (session == _session) {
        error = failure.toString().replaceFirst('FormatException: ', '');
      }
      rethrow;
    } finally {
      saving = false;
      if (!_disposed) {
        notifyListeners();
        requestSync();
      }
    }
  }

  Future<void> _writeState(
    List<AppRow> rows,
    List<SyncConflictGroup> conflicts, {
    String? storageKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      storageKey ?? _storageKey,
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

  void _validateSpec(ProductSpec spec) {
    final volume = spec.volume;
    if (spec.identity.length > 50 ||
        spec.unit.length > 12 ||
        spec.packCount < 1 ||
        spec.packCount > 999 ||
        (volume != null &&
            (!volume.isFinite || volume <= 0 || volume > 1000000))) {
      throw const FormatException('제품명·용량·단위·묶음 개수를 확인해주세요.');
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
