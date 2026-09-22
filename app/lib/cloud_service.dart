import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

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

  Future<List<AppRow>> exchange(List<AppRow> local) async {
    final currentUser = user;
    if (currentUser == null || currentUser.isAnonymous) {
      throw StateError('이메일 계정으로 로그인해주세요.');
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

      final merged = <String, AppRow>{
        for (final row in remoteRows) row.id: row,
      };
      for (final row in local) {
        final remote = merged[row.id];
        if (remote == null || row.revision.compareTo(remote.revision) >= 0) {
          merged[row.id] = row;
        }
      }
      final rows = <String, Object?>{
        for (final row in merged.values) row.id: _remoteJson(row),
      };
      if (jsonEncode(rows).length > 200000) {
        throw StateError('동기화 데이터가 너무 큽니다. 오래된 기록을 정리해주세요.');
      }
      transaction.set(ref, {'version': 4, 'rows': rows});
      return merged.values.toList();
    }, maxAttempts: 3);
  }

  Map<String, Object?> _remoteJson(AppRow row) => row.toJson();

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
    if (!configured || user == null) throw StateError('이메일 계정으로 로그인해주세요.');
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
        'invalid-credential' => '이메일과 비밀번호를 확인해주세요.',
        'email-already-in-use' => '이미 가입한 이메일입니다.',
        'weak-password' => '비밀번호를 더 길게 입력해주세요.',
        'invalid-email' => '이메일 형식을 확인해주세요.',
        'network-request-failed' => '인터넷 연결을 확인해주세요. 기기 기록은 유지됩니다.',
        _ => error.message ?? '계정 요청을 처리하지 못했습니다.',
      };
    }
    if (kDebugMode) debugPrint('$error');
    return error is StateError ? error.message : '처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  }
}
