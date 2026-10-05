import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

abstract final class ServerConfig {
  static const apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://howmuch.monithub.org',
  );
}

class ApiException implements Exception {
  const ApiException(this.status, this.message);
  final int status;
  final String message;
}

class CloudService {
  CloudService(
    this.configured, {
    String apiUrl = ServerConfig.apiUrl,
    FlutterSecureStorage storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  }) : _api = Uri.parse(apiUrl.replaceFirst(RegExp(r'/$'), '')),
       _storage = storage {
    if (configured &&
        (_api.host.isEmpty ||
            _api.userInfo.isNotEmpty ||
            _api.hasQuery ||
            _api.hasFragment ||
            (_api.scheme != 'https' &&
                !(_api.scheme == 'http' &&
                    {'localhost', '127.0.0.1', '::1'}.contains(_api.host))))) {
      throw ArgumentError('서버 주소는 HTTPS를 사용해야 합니다.');
    }
  }

  final bool configured;
  final Uri _api;
  final FlutterSecureStorage _storage;
  final _changes = StreamController<String?>.broadcast();
  String? _accountId;
  String? _token;
  bool _expired = false;

  // 서버 주소마다 세션을 분리해 다른 서버로 인증 토큰을 보내지 않는다.
  String get _storageKey =>
      'howmuch.session.v1.${sha256.convert(utf8.encode(_api.toString()))}';
  String? get accountId => _accountId;
  bool get canSync => configured && _token != null && !_expired;
  bool get sessionExpired => _expired;
  bool get usesRecoveryCode => _accountId != null;
  String get accountLabel => _accountId == null ? '기기 기록' : '복구 코드 계정';
  Stream<String?> get authChanges => _changes.stream;

  /// 네트워크 없이 안전한 저장소의 세션만 읽어 오프라인 기록을 바로 연다.
  Future<void> initialize() async {
    if (!configured) return;
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return;
    final value = jsonDecode(raw) as Map;
    final id = value['accountId'];
    final token = value['token'];
    if (id is! String || id.isEmpty || token is! String || token.isEmpty) {
      throw const FormatException('저장된 계정 정보를 확인할 수 없습니다.');
    }
    _accountId = id;
    _token = token;
    _expired = DateTime.parse(
      value['expiresAt'] as String,
    ).isBefore(DateTime.now());
  }

  Future<void> _saveSession(Map<String, Object?> value) async {
    final id = value['accountId'] as String;
    final token = value['token'] as String;
    // 복구 코드 원문은 제외하고, Keychain/Keystore 저장 성공 후 계정을 전환한다.
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({
        'accountId': id,
        'token': token,
        'expiresAt': value['expiresAt'],
      }),
    );
    _accountId = id;
    _token = token;
    _expired = false;
    _changes.add(id);
  }

  /// 서버가 발급한 코드는 한 번 표시하고 원문을 저장하지 않는다.
  Future<String> createRecoveryAccount() async {
    final result = await _request('POST', '/v1/accounts', authenticate: false);
    final code = result['recoveryCode'] as String;
    RecoveryCode.normalize(code);
    await _saveSession(result);
    return code;
  }

  /// 잘못된 코드는 새 계정을 만들지 않으며 기존 기기 기록도 유지한다.
  Future<void> restoreRecoveryAccount(String code) async {
    final normalized = RecoveryCode.normalize(code);
    final result = await _request(
      'POST',
      '/v1/sessions',
      authenticate: false,
      body: {'recoveryCode': normalized},
    );
    await _saveSession(result);
  }

  Future<void> signOut() async {
    try {
      if (_token != null) await _request('DELETE', '/v1/session');
    } catch (_) {
      // 서버 폐기가 실패해도 기기의 토큰은 제거한다. 서버 세션은 만료일까지 남는다.
    }
    await _storage.delete(key: _storageKey);
    _accountId = null;
    _token = null;
    _expired = false;
    _changes.add(null);
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Object? body,
    bool authenticate = true,
    Map<String, String>? query,
  }) async {
    if (!configured) throw StateError('동기화 서버 설정이 필요합니다.');
    final token = _token;
    if (authenticate && token == null) throw StateError('복구 코드로 기록을 연결해주세요.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final uri = _api.replace(
          path: '${_api.path}$path',
          queryParameters: query,
        );
        final request = await client.openUrl(method, uri);
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        if (authenticate) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }
        if (body != null) request.write(jsonEncode(body));
        final response = await request.close();
        final text = await response.transform(utf8.decoder).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (authenticate && response.statusCode == 401 && token == _token) {
            // 세션 만료로 계정·미전송 기록을 지우지 않고 복구 코드 재입력을 기다린다.
            _expired = true;
          }
          throw ApiException(response.statusCode, '서버 요청을 처리하지 못했습니다.');
        }
        return Map<String, Object?>.from(jsonDecode(text) as Map);
      })().timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }

  Future<SyncExchangeResult> exchange(List<AppRow> local) async {
    final result = await _request(
      'POST',
      '/v1/sync',
      body: {'rows': local.map((row) => row.toJson()).toList()},
    );
    return SyncExchangeResult(
      rows: (result['rows'] as List)
          .map(
            (value) => AppRow.fromJson(Map<String, Object?>.from(value as Map)),
          )
          .toList(),
      conflicts: (result['conflicts'] as List)
          .map(
            (value) => SyncConflictGroup.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          )
          .toList(),
    );
  }

  Future<void> publishPrices(List<AppRow> rows) async {
    await _request(
      'POST',
      '/v1/prices/publish',
      body: {'rowIds': rows.map((row) => row.id).toList()},
    );
  }

  Future<List<SharedPriceRecord>> sharedPrices(PurchaseData base) async {
    if (base.productKey == 'other' || base.spec?.isComparable != true) {
      throw StateError('기준 기록의 제품·용량·할인 조건을 먼저 확인해주세요.');
    }
    final result = await _request(
      'GET',
      '/v1/prices',
      query: {'productKey': base.productKey},
    );
    final records = <SharedPriceRecord>[];
    for (final raw in result['records'] as List) {
      final value = Map<String, Object?>.from(raw as Map);
      final purchase = PurchaseData.fromJson(
        Map<String, Object?>.from(value['purchase'] as Map),
      );
      if (comparePrices(base, purchase).issue.isEmpty) {
        records.add(
          SharedPriceRecord(
            id: value['id'] as String,
            title: value['title'] as String,
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
    if (error is ApiException) {
      return switch (error.status) {
        401 => '복구 코드를 다시 확인해주세요. 기기 기록은 유지됩니다.',
        413 => '동기화 데이터가 너무 큽니다. 기기 기록은 유지됩니다.',
        422 => '기록의 입력 형식과 허용 범위를 확인해주세요.',
        429 => '요청이 많습니다. 잠시 후 다시 시도해주세요.',
        _ => '서버에 연결하지 못했습니다. 기기 기록은 유지됩니다.',
      };
    }
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is HttpException) {
      return '인터넷 연결을 확인해주세요. 기기 기록은 유지되며 다시 동기화합니다.';
    }
    if (error is FormatException) return error.message.toString();
    return error is StateError ? error.message : '처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  }
}
