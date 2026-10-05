import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'app_store.dart';
import 'app_theme.dart';
import 'design_widgets.dart';
import 'models.dart';

class PriceComparisonScreen extends StatelessWidget {
  const PriceComparisonScreen({
    super.key,
    required this.store,
    required this.base,
  });
  final AppStore store;
  final AppRow base;

  String _price(double value) =>
      '${NumberFormat.decimalPattern('ko_KR').format(value.round())}원';

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final today = DateUtils.dateOnly(DateTime.now());
      final since = today.subtract(const Duration(days: 29));
      // 제품·용량·할인 조건이 확인된 동일 규격만 비교해 잘못된 최저가를 보여주지 않는다.
      final rows =
          store.pricesFor(base.title).where((row) {
            final date = DateTime.tryParse(row.purchase!.purchasedOn);
            return date != null &&
                !date.isBefore(since) &&
                !date.isAfter(today) &&
                comparePrices(base.purchase!, row.purchase!).issue.isEmpty;
          }).toList()..sort(
            (a, b) =>
                a.purchase!.purchasedOn.compareTo(b.purchase!.purchasedOn),
          );
      final prices = rows.map((row) => row.purchase!.unitPrice).toList();
      final lowest = prices.isEmpty ? null : prices.reduce(math.min);
      final average = prices.isEmpty
          ? 0.0
          : prices.reduce((a, b) => a + b) / prices.length;
      final recentStores = <String, AppRow>{};
      for (final row in rows.reversed) {
        recentStores.putIfAbsent(row.purchase!.store, () => row);
      }
      return Scaffold(
        appBar: AppBar(
          leadingWidth: 68,
          titleSpacing: 8,
          leading: const DesignBackButton(),
          title: const Text('가격 비교'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${base.title}, 어디가 더 저렴했지?',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge?.copyWith(fontSize: 25),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '최근 30일, 같은 규격의 낱개 가격을 비교했어요.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  if (lowest == null)
                    const PaperCard(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          '비교할 기록이 아직 없어요. 구매 기록에서 제품·용량·할인 조건을 확인해주세요.',
                        ),
                      ),
                    )
                  else ...[
                    PaperCard(
                      color: AppColors.secondary,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '가장 낮았던 가격',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.coral,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 24,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _price(lowest),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.note,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    average == 0
                                        ? '같은 가격이에요'
                                        : '평균보다 ${((1 - lowest / average) * 100).round()}% ↓',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.coral,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '가격 흐름',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    PaperCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Semantics(
                          label: rows
                              .map(
                                (row) =>
                                    '${row.purchase!.purchasedOn} ${_price(row.purchase!.unitPrice)}',
                              )
                              .join(', '),
                          child: SizedBox(
                            height: 160,
                            child: CustomPaint(painter: _PriceChart(rows)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '최근에 산 곳',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    PaperCard(
                      child: Column(
                        children: [
                          for (final row in recentStores.values)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.purchase!.store,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          row.purchase!.purchasedOn,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _price(row.purchase!.unitPrice),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: row.purchase!.unitPrice == lowest
                                          ? AppColors.coral
                                          : AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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

/// Figma의 그래프 스타일에 실제 구매일과 가격을 그린다. 샘플 그래프를 재사용하지 않는다.
class _PriceChart extends CustomPainter {
  _PriceChart(this.rows);
  final List<AppRow> rows;

  @override
  void paint(Canvas canvas, Size size) {
    final prices = rows.map((row) => row.purchase!.unitPrice).toList();
    final low = prices.reduce(math.min);
    final high = prices.reduce(math.max);
    final margin = math.max((high - low) * 0.2, math.max(high * 0.05, 1.0));
    final bottom = low - margin;
    final span = high - low + margin * 2;
    final plot = Rect.fromLTRB(48, 12, size.width - 8, size.height - 32);
    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (var index = 0; index < 3; index++) {
      final y = plot.top + plot.height * index / 2;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()..color = AppColors.border,
      );
      _label(
        canvas,
        NumberFormat('#,##0', 'ko_KR').format(bottom + span * (1 - index / 2)),
        Offset(0, y - 7),
      );
    }
    final firstDate = DateTime.parse(rows.first.purchase!.purchasedOn);
    final days = DateTime.parse(
      rows.last.purchase!.purchasedOn,
    ).difference(firstDate).inDays;
    final points = rows.map((row) {
      final day = DateTime.parse(
        row.purchase!.purchasedOn,
      ).difference(firstDate).inDays;
      return Offset(
        days == 0 ? plot.center.dx : plot.left + plot.width * day / days,
        plot.bottom - plot.height * (row.purchase!.unitPrice - bottom) / span,
      );
    }).toList();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fill = Path.from(path)
      ..lineTo(points.last.dx, plot.bottom)
      ..lineTo(points.first.dx, plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = AppColors.secondary.withValues(alpha: 0.5),
    );
    canvas.drawPath(path, line);
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = AppColors.surface);
      canvas.drawCircle(point, 4, line);
    }
    final firstLabel = DateFormat('M/d').format(firstDate);
    _label(canvas, firstLabel, Offset(plot.left - 12, plot.bottom + 12));
    if (days > 0) {
      _label(
        canvas,
        DateFormat(
          'M/d',
        ).format(DateTime.parse(rows.last.purchase!.purchasedOn)),
        Offset(plot.right - 24, plot.bottom + 12),
      );
    }
  }

  void _label(Canvas canvas, String value, Offset position) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 10,
          color: AppColors.muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, position);
  }

  @override
  bool shouldRepaint(_PriceChart oldDelegate) => oldDelegate.rows != rows;
}
