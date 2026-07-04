import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/skeletons.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/project_repository.dart';
import '../../providers/remote_project_provider.dart';
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
          child: ColoredBox(
            // 任务②:列表区 bg2 底,卡片 bgCard "浮"起来,编辑层次
            color: KkColors.bgSubtle,
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
      separatorBuilder: (_, __) => const SizedBox(height: KkSpacing.lg),
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
          // 任务②:标题后 6×6 teal 品牌点(签名细节)
          Text('看看', style: KkType.h1),
          const SizedBox(width: 7),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: KkColors.teal,
              shape: BoxShape.circle,
            ),
          ),
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
                // 任务②:激活态 bg2 底 + bd 边框 + t1 加粗(原型克制风,非 teal 实心)
                color: selected ? KkColors.bgSubtle : Colors.transparent,
                borderRadius: BorderRadius.circular(KkRadius.pill),
                border: Border.all(color: KkColors.bd),
              ),
              child: Center(
                child: Text(
                  label,
                  style: KkType.bodySm.copyWith(
                    color: selected ? KkColors.t1 : KkColors.t2,
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
    // 后端接入开关(--dart-define=USE_REMOTE=true):真数据走 remote,否则 mock。
    // 默认 mock,不带 flag 构建行为完全不变。
    if (AppConfig.useRemote) return _remoteList(context, ref);
    return _mockList(context, ref);
  }

  // ── mock 数据源(内存 repo,默认)──
  Widget _mockList(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(projectRepositoryProvider);
    final list = repo.sorted(sort, domain: domain);
    if (list.isEmpty) {
      return ListView(
        children: const [EmptyState(variant: EmptyStateVariant.generic)],
      );
    }
    return _cardListView(list, showAuthor: true);
  }

  // ── 真数据源(GET /projects,AsyncValue 三态)──
  Widget _remoteList(BuildContext context, WidgetRef ref) {
    final async = ref.watch(remoteProjectsProvider);
    return async.when(
      loading: () => _skeleton(),
      error: (e, _) => _RemoteError(
        onRetry: () => ref.invalidate(remoteProjectsProvider),
      ),
      data: (all) {
        // 后端不透传前端 domain/hot 排序,这里客户端兜底(见 DTO 分叉注释)。
        var list = domain == null
            ? all
            : all.where((p) => p.domain == domain).toList();
        list = _applySort(list);
        if (list.isEmpty) {
          return ListView(
            children: const [EmptyState(variant: EmptyStateVariant.generic)],
          );
        }
        // 真数据卡片隐藏作者行(后端卡片不展开作者)。
        return _cardListView(list, showAuthor: false);
      },
    );
  }

  List<Project> _applySort(List<Project> src) {
    final list = List<Project>.of(src);
    switch (sort) {
      case 'hot':
        list.sort((a, b) => b.takeawayCount.compareTo(a.takeawayCount));
      case 'new':
        list.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      case 'featured':
      default:
        break; // 保持后端返回顺序
    }
    return list;
  }

  Widget _cardListView(List<Project> list, {required bool showAuthor}) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        KkSpacing.lg, KkSpacing.sm, KkSpacing.lg, KkSpacing.xxl,
      ),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: KkSpacing.lg),
      itemBuilder: (context, i) =>
          ProjectCard(project: list[i], showAuthor: showAuthor),
    );
  }

  Widget _skeleton() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        KkSpacing.lg, KkSpacing.sm, KkSpacing.lg, KkSpacing.xxl,
      ),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: KkSpacing.lg),
      itemBuilder: (_, __) => const ProjectCardSkeleton(),
    );
  }
}

// 真数据加载失败:一句事实 + 重试(零旁白,不写"哎呀出错了")。
class _RemoteError extends StatelessWidget {
  final VoidCallback onRetry;
  const _RemoteError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('连不上服务器',
                  style: KkType.body.copyWith(color: KkColors.t2)),
              const SizedBox(height: KkSpacing.md),
              Tappable(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(KkRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KkSpacing.lg,
                    vertical: KkSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: KkColors.bgSubtle,
                    borderRadius: BorderRadius.circular(KkRadius.pill),
                    border: Border.all(color: KkColors.bd),
                  ),
                  child: Text('重试',
                      style: KkType.bodySm.copyWith(color: KkColors.teal)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
