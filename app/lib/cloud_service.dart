import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'models.dart';
import 'recovery_code.dart';

class SharedPriceRecord {
  const SharedPriceRecord({
    required this.id,
    required this.title,
    required this.purchase,
  });

  final String id;
  final String title;
  final PurchaseData purchase;
}

class SyncConflictEntry {
  const SyncConflictEntry({required this.local, required this.remote});

  final AppRow local;
  final AppRow? remote;

  Map<String, Object?> toJson() => {
    'local': local.toJson(),
    'remote': remote?.toJson(),
  };

  factory SyncConflictEntry.fromJson(Map<String, Object?> json) =>
      SyncConflictEntry(
        local: AppRow.fromJson(
          Map<String, Object?>.from(json['local']! as Map),
        ),
        remote: json['remote'] is Map
            ? AppRow.fromJson(Map<String, Object?>.from(json['remote']! as Map))
            : null,
      );
}

class SyncConflictGroup {
  const SyncConflictGroup({required this.group, required this.entries});

  final String group;
  final List<SyncConflictEntry> entries;

  Map<String, Object?> toJson() => {
    'group': group,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory SyncConflictGroup.fromJson(Map<String, Object?> json) =>
      SyncConflictGroup(
        group: json['group'] as String? ?? '',
        entries: (json['entries'] as List? ?? [])
            .map(
              (entry) => SyncConflictEntry.fromJson(
                Map<String, Object?>.from(entry as Map),
              ),
            )
            .toList(),
      );
}

class SyncExchangeResult {
  const SyncExchangeResult({required this.rows, required this.conflicts});

  final List<AppRow> rows;
  final List<SyncConflictGroup> conflicts;
}

SyncExchangeResult reconcileRows(List<AppRow> server, List<AppRow> local) {
  final rows = <String, AppRow>{for (final row in server) row.id: _synced(row)};
  final conflicts = <SyncConflictGroup>[];
  final changes = local.where((row) => row.pending).toList();
  final groups = <String, List<AppRow>>{};
  for (final row in changes) {
    groups
        .putIfAbsent(row.group.isEmpty ? row.revision : row.group, () => [])
        .add(row);
  }
  for (final entry in groups.entries) {
    final collides = entry.value.any((localRow) {
      final remoteRevision = rows[localRow.id]?.revision;
      return remoteRevision != localRow.revision &&
          remoteRevision != localRow.baseRevision;
    });
    if (collides) {
      conflicts.add(
        SyncConflictGroup(
          group: entry.key,
          entries: entry.value
              .map(
                (localRow) => SyncConflictEntry(
                  local: localRow,
                  remote: rows[localRow.id],
                ),
              )
              .toList(),
        ),
      );
    } else {
      for (final row in entry.value) {
        rows[row.id] = _synced(row);
      }
    }
  }
  return SyncExchangeResult(rows: rows.values.toList(), conflicts: conflicts);
}

AppRow _synced(AppRow row) => row.withSync(
  pending: false,
  baseRevision: row.revision,
  group: row.revision,
);

abstract final class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static Future<bool> initialize() async {
    if (!isConfigured) return false;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain.isEmpty ? null : authDomain,
        iosBundleId: 'com.todayone.todo',
      ),
    );
    return true;
  }
}

class CloudService {
  CloudService(this.configured);

  final bool configured;

  User? get user => configured ? FirebaseAuth.instance.currentUser : null;

  String? get accountId => user?.uid;
  bool get canSync => configured && user != null && !user!.isAnonymous;
  bool get usesRecoveryCode =>
      user?.email?.endsWith('@${RecoveryCode.emailDomain}') == true;
  String get accountLabel =>
      usesRecoveryCode ? '복구 코드 계정' : user?.email ?? '기기 기록';

  /// 새 계정을 만들고 한 번만 표시할 복구 코드를 반환한다.
  Future<String> createRecoveryAccount() async {
    final code = RecoveryCode.generate();
    await signIn(
      RecoveryCode.email(code),
      RecoveryCode.password(code),
      create: true,
    );
    return code;
  }

  /// 발급된 코드로 같은 UID에 로그인한다. 없는 코드는 새 계정을 만들지 않는다.
  Future<void> restoreRecoveryAccount(String code) => signIn(
    RecoveryCode.email(code),
    RecoveryCode.password(code),
    create: false,
  );

  Stream<User?> get authChanges => configured
      ? FirebaseAuth.instance.authStateChanges()
      : Stream<User?>.value(null);

  Future<void> signIn(
    String email,
    String password, {
    required bool create,
  }) async {
    if (!configured) throw StateError('Firebase 설정이 필요합니다.');
    if (create) {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } else {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    }
  }

  Future<void> signOut() async {
    if (configured) await FirebaseAuth.instance.signOut();
  }

  Future<void> resetPassword(String email) async {
    if (!configured) throw StateError('Firebase 설정이 필요합니다.');
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  Future<SyncExchangeResult> exchange(List<AppRow> local) async {
    final currentUser = user;
    if (currentUser == null || currentUser.isAnonymous) {
      throw StateError('복구 코드 또는 이메일로 기록을 연결해주세요.');
    }
    final ref = FirebaseFirestore.instance.doc(
      'accounts/${currentUser.uid}/state/main',
    );
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final remoteRows = <AppRow>[];
      if (snapshot.exists) {
        final raw = snapshot.data()?['rows'];
        if (raw is Map) {
          for (final value in raw.values) {
            if (value is Map) {
              remoteRows.add(AppRow.fromJson(Map<String, Object?>.from(value)));
            }
          }
        }
      }

      final result = reconcileRows(remoteRows, local);
      final rows = <String, Object?>{
        for (final row in result.rows) row.id: _remoteJson(row),
      };
      if (jsonEncode(rows).length > 200000) {
        throw StateError('동기화 데이터가 너무 큽니다. 오래된 기록을 정리해주세요.');
      }
      final remoteRevisions = {
        for (final row in remoteRows) row.id: row.revision,
      };
      // 서버 확인만 한 경우에는 같은 문서를 다시 쓰지 않는다.
      if (!snapshot.exists ||
          result.rows.any((row) => remoteRevisions[row.id] != row.revision)) {
        transaction.set(ref, {'version': 4, 'rows': rows});
      }
      return result;
    }, maxAttempts: 3);
  }

  Map<String, Object?> _remoteJson(AppRow row) => row.toJson()
    ..remove('pending')
    ..remove('baseRevision')
    ..remove('group');

  Future<void> publishPrices(List<AppRow> rows) async {
    final currentUser = user;
    if (currentUser == null || currentUser.isAnonymous) return;
    for (final row in rows.where((row) => row.purchase != null)) {
      final purchase = row.purchase!;
      final ownerRef = FirebaseFirestore.instance.doc('priceOwners/${row.id}');
      final priceRef = FirebaseFirestore.instance.doc('sharedPrices/${row.id}');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final owner = await transaction.get(ownerRef);
        final canShare =
            !row.deleted &&
            purchase.share &&
            purchase.spec?.isComparable == true &&
            purchase.registeredAt != null;
        if (canShare) {
          if (owner.exists && owner.data()?['uid'] != currentUser.uid) {
            throw StateError('다른 계정의 공개 기록입니다.');
          }
          transaction.set(ownerRef, {'uid': currentUser.uid, 'rowId': row.id});
          transaction.set(priceRef, {
            'productKey': purchase.productKey,
            'title': purchase.spec!.identity,
            'store': purchase.store,
            'purchasedOn': purchase.purchasedOn,
            'registeredAt': purchase.registeredAt,
            'quantity': purchase.quantity,
            'total': purchase.total,
            'condition': purchase.condition,
            'spec': purchase.spec!.toJson(),
          });
        } else if (owner.exists && owner.data()?['uid'] == currentUser.uid) {
          transaction.delete(priceRef);
          transaction.delete(ownerRef);
        }
      }, maxAttempts: 3);
    }
  }

  Future<List<SharedPriceRecord>> sharedPrices(
    PurchaseData base,
    Set<String> ownIds,
  ) async {
    if (!canSync) throw StateError('복구 코드 또는 이메일로 기록을 연결해주세요.');
    if (base.productKey == 'other' || base.spec?.isComparable != true) {
      throw StateError('기준 기록의 제품·용량·할인 조건을 먼저 확인해주세요.');
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('sharedPrices')
        .where('productKey', isEqualTo: base.productKey)
        .get();
    final records = <SharedPriceRecord>[];
    for (final doc in snapshot.docs) {
      if (ownIds.contains(doc.id)) continue;
      final value = doc.data();
      if (value['spec'] is! Map) continue;
      final purchase = PurchaseData(
        receiptId: '',
        itemId: '',
        productKey: value['productKey'] as String? ?? 'other',
        store: value['store'] as String? ?? '',
        purchasedOn: value['purchasedOn'] as String? ?? '',
        quantity: (value['quantity'] as num?)?.toInt() ?? 1,
        total: (value['total'] as num?)?.toInt() ?? 0,
        condition: value['condition'] as String? ?? '',
        share: true,
        spec: ProductSpec.fromJson(
          Map<String, Object?>.from(value['spec']! as Map),
        ),
        registeredAt: value['registeredAt'] as String?,
      );
      if (comparePrices(base, purchase).issue.isEmpty) {
        records.add(
          SharedPriceRecord(
            id: doc.id,
            title: value['title'] as String? ?? '',
            purchase: purchase,
          ),
        );
      }
    }
    records.sort(
      (a, b) => b.purchase.purchasedOn.compareTo(a.purchase.purchasedOn) != 0
          ? b.purchase.purchasedOn.compareTo(a.purchase.purchasedOn)
          : (b.purchase.registeredAt ?? '').compareTo(
              a.purchase.registeredAt ?? '',
            ),
    );
    final latestByStore = <String, SharedPriceRecord>{};
    for (final record in records) {
      latestByStore.putIfAbsent(record.purchase.store, () => record);
    }
    return latestByStore.values.toList();
  }

  static String readableError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-credential' ||
        'user-not-found' ||
        'wrong-password' => '복구 코드 또는 이메일과 비밀번호를 확인해주세요.',
        'email-already-in-use' => '이미 가입한 이메일입니다.',
        'weak-password' => '비밀번호를 더 길게 입력해주세요.',
        'invalid-email' => '이메일 형식을 확인해주세요.',
        'network-request-failed' => '인터넷 연결을 확인해주세요. 기기 기록은 유지됩니다.',
        _ => error.message ?? '계정 요청을 처리하지 못했습니다.',
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'unavailable' ||
        'deadline-exceeded' => '인터넷 연결을 확인해주세요. 기기 기록은 유지되며 다시 동기화합니다.',
        'permission-denied' => '기록 접근 권한을 확인해주세요.',
        _ => '서버에 연결하지 못했습니다. 기기 기록은 유지됩니다.',
      };
    }
    if (error is FormatException) return error.message.toString();
    return error is StateError ? error.message : '처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  }
}
