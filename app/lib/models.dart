import 'dart:convert';

enum ShoppingFilter { all, active, completed }

int positiveInteger(String text, {int max = 999}) {
  final normalized = text.trim();
  if (!RegExp(r'^\d+$').hasMatch(normalized)) {
    throw const FormatException('수량과 금액은 양의 정수로 입력해주세요.');
  }
  final value = int.parse(normalized);
  if (value < 1 || value > max) {
    throw FormatException('1~$max 범위로 입력해주세요.');
  }
  return value;
}

int nonNegativeInteger(String text, {int max = 9999999}) {
  final normalized = text.trim();
  if (!RegExp(r'^\d+$').hasMatch(normalized)) {
    throw const FormatException('금액은 0 이상의 정수로 입력해주세요.');
  }
  final value = int.parse(normalized);
  if (value > max) throw FormatException('0~$max 범위로 입력해주세요.');
  return value;
}

String normalizedProduct(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

class ProductSpec {
  const ProductSpec({
    this.identity = '',
    this.volume,
    this.unit = '',
    this.packCount = 1,
    this.conditionKnown = false,
    this.allocated = true,
  });

  final String identity;
  final double? volume;
  final String unit;
  final int packCount;
  final bool conditionKnown;
  final bool allocated;

  bool get isComparable =>
      identity.trim().isNotEmpty &&
      volume != null &&
      volume! > 0 &&
      unit.trim().isNotEmpty &&
      conditionKnown &&
      allocated;

  Map<String, Object?> toJson() => {
    'identity': identity,
    'volume': volume,
    'unit': unit,
    'packCount': packCount,
    'conditionKnown': conditionKnown,
    'allocated': allocated,
  };

  factory ProductSpec.fromJson(Map<String, Object?> json) => ProductSpec(
    identity: json['identity'] as String? ?? '',
    volume: (json['volume'] as num?)?.toDouble(),
    unit: json['unit'] as String? ?? '',
    packCount: (json['packCount'] as num?)?.toInt() ?? 1,
    conditionKnown: json['conditionKnown'] as bool? ?? false,
    allocated: json['allocated'] as bool? ?? true,
  );
}

String productKey(ProductSpec? spec) {
  final identity = normalizedProduct(spec?.identity ?? '');
  if (identity.isEmpty) return 'other';
  return 'v2-${identity.codeUnits.map((code) => code.toRadixString(16).padLeft(4, '0')).join()}';
}

class PurchaseData {
  const PurchaseData({
    required this.receiptId,
    required this.itemId,
    required this.store,
    required this.purchasedOn,
    required this.quantity,
    required this.total,
    this.productKey = 'other',
    this.condition = '',
    this.share = false,
    this.spec,
    this.registeredAt,
  });

  final String receiptId;
  final String itemId;
  final String productKey;
  final String store;
  final String purchasedOn;
  final int quantity;
  final int total;
  final String condition;
  final bool share;
  final ProductSpec? spec;
  final String? registeredAt;

  double get unitPrice => total / (quantity * (spec?.packCount ?? 1));

  PurchaseData copyWith({
    String? productKey,
    String? condition,
    bool? share,
    ProductSpec? spec,
  }) => PurchaseData(
    receiptId: receiptId,
    itemId: itemId,
    productKey: productKey ?? this.productKey,
    store: store,
    purchasedOn: purchasedOn,
    quantity: quantity,
    total: total,
    condition: condition ?? this.condition,
    share: share ?? this.share,
    spec: spec ?? this.spec,
    registeredAt: registeredAt,
  );

  Map<String, Object?> toJson() => {
    'receiptId': receiptId,
    'itemId': itemId,
    'productKey': productKey,
    'store': store,
    'purchasedOn': purchasedOn,
    'quantity': quantity,
    'total': total,
    'condition': condition,
    'share': share,
    if (spec != null) 'spec': spec!.toJson(),
    if (registeredAt != null) 'registeredAt': registeredAt,
  };

  factory PurchaseData.fromJson(Map<String, Object?> json) => PurchaseData(
    receiptId: json['receiptId'] as String? ?? '',
    itemId: json['itemId'] as String? ?? '',
    productKey: json['productKey'] as String? ?? 'other',
    store: json['store'] as String? ?? '',
    purchasedOn: json['purchasedOn'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    total: (json['total'] as num?)?.toInt() ?? 0,
    condition: json['condition'] as String? ?? '',
    share: json['share'] as bool? ?? false,
    spec: json['spec'] is Map
        ? ProductSpec.fromJson(Map<String, Object?>.from(json['spec']! as Map))
        : null,
    registeredAt: json['registeredAt'] as String?,
  );
}

class AppRow {
  const AppRow({
    required this.id,
    required this.title,
    required this.completed,
    required this.revision,
    this.quantity,
    this.note = '',
    this.purchase,
    this.deleted = false,
  });

  final String id;
  final String title;
  final bool completed;
  final int? quantity;
  final String note;
  final PurchaseData? purchase;
  final bool deleted;
  final String revision;

  bool get isPurchase => purchase != null;

  AppRow copyWith({
    String? title,
    bool? completed,
    int? quantity,
    String? note,
    PurchaseData? purchase,
    bool? deleted,
    String? revision,
  }) => AppRow(
    id: id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
    quantity: quantity ?? this.quantity,
    note: note ?? this.note,
    purchase: purchase ?? this.purchase,
    deleted: deleted ?? this.deleted,
    revision: revision ?? this.revision,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    if (quantity != null) 'quantity': quantity,
    if (note.isNotEmpty) 'note': note,
    if (purchase != null) 'purchase': purchase!.toJson(),
    'deleted': deleted,
    'revision': revision,
  };

  factory AppRow.fromJson(Map<String, Object?> json) {
    final title = (json['title'] as String? ?? '').trim();
    final id = json['id'] as String? ?? '';
    if (id.isEmpty || title.isEmpty) {
      throw const FormatException('저장된 상품 정보가 올바르지 않습니다.');
    }
    return AppRow(
      id: id,
      title: title,
      completed: json['completed'] as bool? ?? false,
      quantity: (json['quantity'] as num?)?.toInt(),
      note: json['note'] as String? ?? '',
      purchase: json['purchase'] is Map
          ? PurchaseData.fromJson(
              Map<String, Object?>.from(json['purchase']! as Map),
            )
          : null,
      deleted: json['deleted'] as bool? ?? false,
      revision: json['revision'] as String? ?? '0000000000000000:legacy',
    );
  }
}

class ReceiptLineDraft {
  ReceiptLineDraft({
    required this.id,
    required this.title,
    this.quantity = 1,
    this.total = 0,
    this.selected = true,
    this.itemId = '',
    this.spec,
  });

  final String id;
  String title;
  int quantity;
  int total;
  bool selected;
  String itemId;
  ProductSpec? spec;
}

class ReceiptDraft {
  ReceiptDraft({
    required this.id,
    required this.store,
    required this.purchasedOn,
    required this.lines,
    this.condition = '',
    this.share = false,
  });

  final String id;
  String store;
  String purchasedOn;
  final List<ReceiptLineDraft> lines;
  String condition;
  bool share;
}

ReceiptDraft parseReceiptText(String text, {String? id}) {
  final rows = const LineSplitter()
      .convert(text)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final datePattern = RegExp(r'\b(20\d{2})[-./](\d{1,2})[-./](\d{1,2})\b');
  final amountPattern = RegExp(r'(\d{1,3}(?:,\d{3})+|\d{3,})\s*원?');
  final dateMatch = rows
      .map(datePattern.firstMatch)
      .whereType<RegExpMatch>()
      .firstOrNull;
  final purchasedOn = dateMatch == null
      ? DateTime.now().toIso8601String().substring(0, 10)
      : '${dateMatch.group(1)}-${dateMatch.group(2)!.padLeft(2, '0')}-${dateMatch.group(3)!.padLeft(2, '0')}';
  final skip = RegExp(
    r'(합계|카드|승인|부가세|과세|면세|거스름|전화|사업자|영수증)',
    caseSensitive: false,
  );
  final candidates = rows
      .where((line) => !datePattern.hasMatch(line) && !skip.hasMatch(line))
      .toList();
  final lines = <ReceiptLineDraft>[];
  String? pendingName;

  for (final row in candidates) {
    final amount = amountPattern.allMatches(row).lastOrNull;
    final hasLetters = RegExp(r'[가-힣A-Za-z]').hasMatch(row);
    if (amount != null) {
      final price = int.tryParse(amount.group(1)!.replaceAll(',', '')) ?? 0;
      final inlineName = row
          .substring(0, amount.start)
          .replaceAll(RegExp(r'[\s|]+$'), '')
          .trim();
      final name = inlineName.isNotEmpty ? inlineName : pendingName;
      if (name != null && price <= 9999999) {
        lines.add(
          ReceiptLineDraft(
            id: 'line-${lines.length}',
            title: name,
            total: price,
            selected: false,
          ),
        );
        pendingName = null;
      }
    } else if (hasLetters && row.length <= 50) {
      pendingName = row;
    }
    if (lines.length == 30) break;
  }

  if (lines.isEmpty) {
    for (final row
        in candidates
            .where((line) => RegExp(r'[가-힣A-Za-z]').hasMatch(line))
            .take(8)) {
      lines.add(
        ReceiptLineDraft(
          id: 'line-${lines.length}',
          title: row,
          total: 0,
          selected: false,
        ),
      );
    }
  }

  final store = rows.firstWhere(
    (line) =>
        RegExp(r'[가-힣A-Za-z]').hasMatch(line) &&
        !skip.hasMatch(line) &&
        line.length <= 30,
    orElse: () => '',
  );
  return ReceiptDraft(
    id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
    store: store,
    purchasedOn: purchasedOn,
    lines: lines,
  );
}

class MemoLineDraft {
  MemoLineDraft({
    required this.title,
    this.quantity = 1,
    this.selected = false,
  });

  String title;
  int quantity;
  bool selected;
}

List<MemoLineDraft> parseMemoText(String text) {
  final result = <MemoLineDraft>[];
  for (var raw in const LineSplitter().convert(text)) {
    var line = raw.trim().replaceFirst(RegExp(r'^[\-•*✓☐☑\s]+'), '').trim();
    if (line.isEmpty) continue;
    final match = RegExp(
      r'\s*(?:x|×)?\s*(\d{1,3})\s*(?:개)?\s*$',
      caseSensitive: false,
    ).firstMatch(line);
    var quantity = 1;
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed >= 1 && parsed <= 999) {
        quantity = parsed;
        line = line.substring(0, match.start).trim();
      }
    }
    if (line.isNotEmpty &&
        line.length <= 50 &&
        RegExp(r'[가-힣A-Za-z0-9]').hasMatch(line)) {
      result.add(MemoLineDraft(title: line, quantity: quantity));
    }
    if (result.length == 50) break;
  }
  return result;
}

class PriceComparison {
  const PriceComparison({required this.issue, this.delta, this.percent});

  final String issue;
  final double? delta;
  final double? percent;
}

PriceComparison comparePrices(PurchaseData base, PurchaseData other) {
  final baseSpec = base.spec;
  final otherSpec = other.spec;
  if (baseSpec == null ||
      otherSpec == null ||
      !baseSpec.isComparable ||
      !otherSpec.isComparable) {
    return const PriceComparison(issue: '제품·용량·할인 조건을 확인할 수 없어 참고용입니다.');
  }
  if (normalizedProduct(baseSpec.identity) !=
      normalizedProduct(otherSpec.identity)) {
    return const PriceComparison(issue: '동일 제품으로 확인되지 않았습니다.');
  }
  if (baseSpec.volume != otherSpec.volume ||
      normalizedProduct(baseSpec.unit) != normalizedProduct(otherSpec.unit) ||
      baseSpec.packCount != otherSpec.packCount) {
    return const PriceComparison(issue: '용량·단위·묶음 규격이 다릅니다.');
  }
  if (normalizedProduct(base.condition) != normalizedProduct(other.condition)) {
    return const PriceComparison(issue: '할인 조건이 다릅니다.');
  }
  final delta = other.unitPrice - base.unitPrice;
  if (base.unitPrice == 0) {
    return PriceComparison(issue: '기준 가격이 0원이라 변동률을 계산하지 않습니다.', delta: delta);
  }
  return PriceComparison(
    issue: '',
    delta: delta,
    percent: delta / base.unitPrice * 100,
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
