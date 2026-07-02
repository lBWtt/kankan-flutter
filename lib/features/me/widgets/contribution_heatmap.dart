import 'package:flutter/material.dart';

import '../../../core/theme/kk_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/seed/mock_seed.dart';

/// HANDOFF §6.10 贡献热力图 — 86 cells GridView,真实签到数据。
///
/// Web 版重灾区:me 屏 / activity 屏用 ×200 编造公式伪造"贡献数"。
/// Flutter 端从零做对:
///   - cells 取自 mockHeatmapCells(真实场景 Drift 查 group by date)
///   - 总贡献数 = cells 里 level > 0 的天数(真实,非 ×N)
///   - 本月贡献 = 最近 30 天 level > 0 的天数
///
/// 视觉:GitHub 风格 5 档色阶。HANDOFF §5:不用蓝/紫,用 mint → teal 渐进。
/// 布局:7 行(周一到周日)× N 列(周数),约 12-13 列。
///
/// 零旁白(HANDOFF §3):只标"贡献 N",不写"继续加油"之类引导。
class ContributionHeatmap extends StatelessWidget {
  /// 单元格列表(从 mock 或 Drift 读)
  final List<HeatmapCell> cells;

  /// 是否显示图例
  final bool showLegend;

  /// 是否显示统计行
  final bool showStats;

  const ContributionHeatmap({
    super.key,
    required this.cells,
    this.showLegend = true,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) return const SizedBox.shrink();

    // 排序:旧 → 新
    final sorted = [...cells]
      ..sort((a, b) => a.dateMs.compareTo(b.dateMs));

    // 真实统计(HANDOFF §6.10,禁 ×200)
    final totalDays = sorted.where((c) => c.level > 0).length;
    final last30 = sorted
        .skip((sorted.length - 30).clamp(0, sorted.length))
        .where((c) => c.level > 0)
        .length;
    final totalContributions = sorted.fold<int>(0, (s, c) => s + c.level);

    // 列数:按 7 天分组
    final weeks = (sorted.length / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(KkSpacing.lg),
      decoration: BoxDecoration(
        color: KkColors.bgCard,
        borderRadius: BorderRadius.circular(KkRadius.lg),
        border: Border.all(color: KkColors.bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showStats) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('贡献', style: KkType.bodySm.copyWith(color: KkColors.t3)),
                const SizedBox(width: KkSpacing.sm),
                Text(
                  '$totalContributions',
                  style: KkType.monoLg.copyWith(color: KkColors.teal),
                ),
                const SizedBox(width: KkSpacing.xs),
                Text(
                  '· $totalDays 天活跃 · 本月 $last30',
                  style: KkType.bodySm.copyWith(color: KkColors.t3),
                ),
              ],
            ),
            const SizedBox(height: KkSpacing.md),
          ],
          // 热力图主体:横向滚动(小屏可能溢出)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _grid(sorted, weeks),
                if (showLegend) ...[
                  const SizedBox(height: KkSpacing.sm),
                  _legend(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<HeatmapCell> sorted, int weeks) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 星期标签列(M/W/F)
        _weekdayLabels(),
        const SizedBox(width: KkSpacing.xs),
        // 周列
        for (var w = 0; w < weeks; w++) ...[
          _weekColumn(sorted, w, weeks),
          if (w < weeks - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }

  /// 星期标签(只标 M/W/F,参考 GitHub)
  Widget _weekdayLabels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 1),
        _label('M'),
        const SizedBox(height: 3),
        const SizedBox(height: 11),
        const SizedBox(height: 3),
        _label('W'),
        const SizedBox(height: 3),
        const SizedBox(height: 11),
        const SizedBox(height: 3),
        _label('F'),
        const SizedBox(height: 3),
        const SizedBox(height: 11),
        const SizedBox(height: 3),
      ],
    );
  }

  Widget _label(String t) {
    return SizedBox(
      width: 10,
      height: 11,
      child: Text(
        t,
        style: TextStyle(
          fontSize: 8,
          color: KkColors.t4,
          fontFamily: 'JetBrainsMono',
        ),
      ),
    );
  }

  Widget _weekColumn(List<HeatmapCell> sorted, int weekIdx, int totalWeeks) {
    return Column(
      children: [
        for (var d = 0; d < 7; d++) ...[
          _cell(sorted, weekIdx * 7 + d),
          if (d < 6) const SizedBox(height: 3),
        ],
      ],
    );
  }

  Widget _cell(List<HeatmapCell> sorted, int idx) {
    if (idx < 0 || idx >= sorted.length) {
      return const SizedBox(width: 11, height: 11);
    }
    final level = sorted[idx].level;
    return Tooltip(
      message: _tooltip(sorted[idx]),
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: _colorForLevel(level),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  String _tooltip(HeatmapCell c) {
    final dt = DateTime.fromMillisecondsSinceEpoch(c.dateMs);
    final dateStr = '${dt.month}-${dt.day}';
    return c.level > 0 ? '$dateStr · $c.level 次贡献' : '$dateStr · 无贡献';
  }

  /// 5 档色阶:HANDOFF §5 不用蓝/紫。用 mint → teal 渐进。
  Color _colorForLevel(int level) {
    switch (level) {
      case 0:
        return KkColors.bgSubtle;
      case 1:
        return const Color(0xFFD4ECDD); // 浅 mint
      case 2:
        return const Color(0xFFA8D9BC);
      case 3:
        return const Color(0xFF6BBE8E);
      case 4:
      default:
        return KkColors.teal;
    }
  }

  Widget _legend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '少',
          style: TextStyle(
            fontSize: 9,
            color: KkColors.t4,
            fontFamily: 'JetBrainsMono',
          ),
        ),
        const SizedBox(width: 4),
        for (var lv = 0; lv <= 4; lv++) ...[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _colorForLevel(lv),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        const SizedBox(width: 4),
        Text(
          '多',
          style: TextStyle(
            fontSize: 9,
            color: KkColors.t4,
            fontFamily: 'JetBrainsMono',
          ),
        ),
      ],
    );
  }
}
