import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/skeletons.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/project_repository.dart';
import '../../router/routes.dart';
import '../shared/empty_state.dart';
import '../shared/project_card.dart';

/// 看看屏 — HANDOFF §6.9 项目 feed。
///
/// 三 Tab 真排序(Web 版重灾区,Flutter 从零做对):
///   - 精选  seed 默认顺序(mock seed 顺序即精选,无 shuffle)
///   - 热门  by likes 降序(真实计数)
///   - 最新  by createdAtMs 降序
///
/// 领域筛选(横向 chip 行):全部 / AI图 / AI视频 / 网页 / App / 工具 / 开源 / Prompt
///
/// 计数铁律(HANDOFF §6.10):排序按真实 likes/createdAtMs,不放大不编造。
/// 零旁白(HANDOFF §3):空状态用 EmptyState,无"快来发第一个"引导。
class KankanScreen extends ConsumerStatefulWidget {
  const KankanScreen({super.key});

  @override
  ConsumerState<KankanScreen> createState() => _KankanScreenState();
}

class _KankanScreenState extends ConsumerState<KankanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String? _domainFilter; // null = 全部

  /// 加载态:Phase 5 接真后端时,把这个 _loading 切到真 await 网络请求即可。
  /// 现在 mock 数据是同步的,300ms 假延迟让骨架屏有展示机会。
  bool _loading = true;

  static const _sorts = [('精选', 'featured'), ('热门', 'hot'), ('最新', 'new')];

  static const _domains = <(String, String?)>[
    ('全部', null),
    ('AI图', 'ai_image'),
    ('AI视频', 'ai_video'),
    ('网页', 'web'),
    ('App', 'app'),
    ('工具', 'tool'),
    ('开源', 'opensource'),
    ('Prompt', 'prompt'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // KkRootShell 已提供 NoiseBackground + SafeArea,branch 屏只返回内容。
    return Column(
      children: [
        _topBar(),
        // loading 时锁住 Tab + 领域筛选,避免在骨架屏期间切条件。
        IgnorePointer(ignoring: _loading, child: _tabBar()),
        IgnorePointer(ignoring: _loading, child: _domainFilterBar()),
        Expanded(
          child: _loading
              ? _skeletonContent()
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _ProjectList(sort: 'featured', domain: _domainFilter),
                    _ProjectList(sort: 'hot', domain: _domainFilter),
                    _ProjectList(sort: 'new', domain: _domainFilter),
                  ],
                ),
        ),
      ],
    );
  }

  // ── 加载态骨架屏:3 个 ProjectCardSkeleton,边距与 _ProjectList 一致 ──
  Widget _skeletonContent() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        KkSpacing.lg,
        KkSpacing.sm,
        KkSpacing.lg,
        KkSpacing.xxl,
      ),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: KkSpacing.md),
      itemBuilder: (_, __) => const ProjectCardSkeleton(),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      child: Row(
        children: [
          Text('看看', style: KkType.h1),
          const SizedBox(width: KkSpacing.sm),
          // 真实项目数(禁编造)
          Consumer(builder: (context, ref, _) {
            final count = ref.watch(projectRepositoryProvider).all().length;
            return Text(
              '$count',
              style: KkType.mono.copyWith(color: KkColors.t3, fontSize: 13),
            );
          }),
          const Spacer(),
          Tappable(
            onTap: () => context.push(KkRoutes.ranking),
            child: const Icon(Icons.emoji_events_outlined,
                size: 22, color: KkColors.t1),
          ),
          const SizedBox(width: KkSpacing.md),
          Tappable(
            onTap: () => context.push(KkRoutes.search),
            child: const Icon(Icons.search, size: 22, color: KkColors.t1),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KkColors.divider)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: KkColors.t1,
        unselectedLabelColor: KkColors.t3,
        labelStyle: KkType.body.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: KkType.body,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: KkColors.teal,
        indicatorWeight: 2,
        tabs: [for (final s in _sorts) Tab(text: s.$1)],
      ),
    );
  }

  // 领域筛选横向 chip 行
  Widget _domainFilterBar() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.lg,
          vertical: KkSpacing.sm,
        ),
        itemCount: _domains.length,
        separatorBuilder: (_, __) => const SizedBox(width: KkSpacing.sm),
        itemBuilder: (context, i) {
          final (label, value) = _domains[i];
          final selected = _domainFilter == value;
          return Tappable(
            onTap: () => setState(() => _domainFilter = value),
            borderRadius: BorderRadius.circular(KkRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KkSpacing.md,
                vertical: KkSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected ? KkColors.teal : KkColors.bgCard,
                borderRadius: BorderRadius.circular(KkRadius.pill),
                border: Border.all(
                  color: selected ? KkColors.teal : KkColors.bd,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: KkType.bodySm.copyWith(
                    color: selected ? Colors.white : KkColors.t2,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 项目列表(按 sort + domain 真排序)──
class _ProjectList extends ConsumerWidget {
  final String sort;
  final String? domain;

  const _ProjectList({required this.sort, required this.domain});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(projectRepositoryProvider);
    final list = repo.sorted(sort, domain: domain);

    if (list.isEmpty) {
      return ListView(
        children: const [EmptyState(variant: EmptyStateVariant.generic)],
      );
    }

    // 瀑布流式(简化:单列,每个 card 自适应高度)
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        KkSpacing.lg, KkSpacing.sm, KkSpacing.lg, KkSpacing.xxl,
      ),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: KkSpacing.md),
      itemBuilder: (context, i) => ProjectCard(project: list[i]),
    );
  }
}
