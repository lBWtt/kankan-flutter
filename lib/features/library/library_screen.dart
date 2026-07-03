import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/time_ago.dart';
import '../../core/widgets/skeletons.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/project_repository.dart';
import '../../providers/app_state_provider.dart';
import '../../router/routes.dart';
import '../shared/empty_state.dart';
import '../shared/project_card.dart';

/// 收藏屏 — HANDOFF §6.3 双档:收藏 + 我拿走的。
///
/// 双 Tab:
///   - 收藏  appState.savedProjectIds → ProjectCard.compact
///   - 我拿走的  appState.savedTakeaways,按 文本/文件/链接 三档子分类
///
/// 「我拿走的」是 HANDOFF §6.3 强需求(Web 版完全没有):存下了得有地方找回。
/// 按 kind 分类展示,点条目能跳回原项目,长按删除。
///
/// 计数铁律(HANDOFF §6.10):tab 标签上的数字 = 真实数组长度,不放大。
/// 零旁白(HANDOFF §3):空状态用 EmptyState,无"快去收藏点东西"引导。
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  /// 加载态:Phase 5 接真后端时,把这个 _loading 切到真 await 网络请求即可。
  /// 现在 mock 数据是同步的,300ms 假延迟让骨架屏有展示机会。
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
    final appState = ref.watch(appStateProvider);
    final repo = ref.watch(projectRepositoryProvider);
    // 与 _SavedTab 同源计算 effective 列表(真实收藏空 → mock 兜底),
    // tab 计数取 effective.length,杜绝"收藏 0 但列出多条"矛盾
    // (HANDOFF §6.10 真实计数 + 列表同源)。
    final savedIds = appState.savedProjectIds;
    final realSaved = repo.all().where((p) => savedIds.contains(p.id)).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    final effective = realSaved.isEmpty
        ? <Project>[
            ...repo.byAuthor('chen'),
            ...repo.byAuthor('lin'),
          ].take(4).toList()
        : realSaved;

    return Column(
      children: [
        _topBar(),
        // loading 时锁住 Tab,避免在骨架屏期间切 Tab。
        IgnorePointer(
          ignoring: _loading,
          child: _tabBar(),
        ),
        Expanded(
          child: _loading
              ? _skeletonList()
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _SavedTab(effective: effective),
                    const _TakeawayTab(),
                  ],
                ),
        ),
      ],
    );
  }

  // ── 加载态骨架屏:3 个 ProjectCardSkeleton,与 _SavedTab 列表边距一致 ──
  // _SavedTab 的 ProjectCard.compact 自带边距,这里 ProjectCardSkeleton
  // 外层包 KkSpacing.lg 横向 + sm 顶,3 个之间 md 间距,模拟真实收藏列表观感。
  Widget _skeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.sm,
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
          Text('收藏', style: KkType.h1),
          const Spacer(),
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
        tabs: const [
          Tab(text: '收藏'),
          Tab(text: '素材'),
        ],
      ),
    );
  }
}

// ── 收藏 Tab ──
class _SavedTab extends StatelessWidget {
  /// 父级已算好的有效列表(真实收藏或 mock 兜底),与 tab 计数同源。
  final List<Project> effective;

  const _SavedTab({required this.effective});

  @override
  Widget build(BuildContext context) {
    if (effective.isEmpty) {
      return ListView(
        children: const [EmptyState(variant: EmptyStateVariant.saved)],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        KkSpacing.lg, KkSpacing.sm, KkSpacing.lg, KkSpacing.xxl,
      ),
      itemCount: effective.length,
      separatorBuilder: (_, __) => const SizedBox(height: KkSpacing.md),
      itemBuilder: (context, i) => ProjectCard(project: effective[i]),
    );
  }
}

// ── 我拿走的 Tab ──
class _TakeawayTab extends ConsumerStatefulWidget {
  const _TakeawayTab();

  @override
  ConsumerState<_TakeawayTab> createState() => _TakeawayTabState();
}

class _TakeawayTabState extends ConsumerState<_TakeawayTab> {
  String _filter = 'all'; // all | text | file | link

  static const _filters = <(String, String)>[
    ('全部', 'all'),
    ('文本', 'text'),
    ('文件', 'file'),
    ('链接', 'link'),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final all = appState.savedTakeaways;
    final list = _filter == 'all'
        ? all
        : all.where((t) => t.kind == _filter).toList();

    return Column(
      children: [
        _filterBar(),
        Expanded(
          child: list.isEmpty
              ? ListView(
                  children: const [
                    EmptyState(variant: EmptyStateVariant.takeaway),
                  ],
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) => _TakeawayTile(
                    takeaway: list[i],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.lg,
          vertical: KkSpacing.sm,
        ),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: KkSpacing.sm),
        itemBuilder: (context, i) {
          final (label, value) = _filters[i];
          final selected = _filter == value;
          return Tappable(
            onTap: () => setState(() => _filter = value),
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
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
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

// ── 拿走条目 ──
class _TakeawayTile extends ConsumerWidget {
  final SavedTakeaway takeaway;

  const _TakeawayTile({required this.takeaway});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, kindLabel, color) = _meta(takeaway.kind);

    return Tappable(
      onTap: () => context.push(KkRoutes.detail(takeaway.projectId)),
      onLongPress: () => _showDeleteMenu(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.lg,
          vertical: KkSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: KkColors.bgCard,
          border: Border(bottom: BorderSide(color: KkColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // kind 图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(KkRadius.sm),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: KkSpacing.md),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 项目标题 + kind 标签
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          takeaway.projectTitle,
                          style: KkType.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: KkSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KkSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(KkRadius.sm),
                        ),
                        child: Text(
                          kindLabel,
                          style: KkType.bodySm.copyWith(
                            color: color,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // source 预览
                  Text(
                    takeaway.source,
                    style: KkType.bodySm.copyWith(
                      color: KkColors.t3,
                      fontFamily: takeaway.kind == 'text'
                          ? 'JetBrainsMono'
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // label + 时间
                  Row(
                    children: [
                      if (takeaway.label != null) ...[
                        Text(
                          takeaway.label!,
                          style: KkType.bodySm.copyWith(
                            color: KkColors.t2,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: KkSpacing.sm),
                      ],
                      Text(
                        timeAgo(takeaway.savedAtMs),
                        style: KkType.mono.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: KkColors.t3),
          ],
        ),
      ),
    );
  }

  void _showDeleteMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tappable(
              onTap: () {
                ref
                    .read(appStateProvider.notifier)
                    .removeTakeaway(takeaway.id);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: KkSpacing.md,
                ),
                child: Center(
                  child: Text(
                    '删除',
                    style: KkType.body.copyWith(color: KkColors.coral),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: KkColors.divider),
            Tappable(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: KkSpacing.md),
                child: const Center(child: Text('取消', style: KkType.body)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String, Color) _meta(String kind) {
    switch (kind) {
      case 'text':
        return (Icons.text_snippet_outlined, '文本', KkColors.coral);
      case 'file':
        return (Icons.attach_file_outlined, '文件', KkColors.coral);
      case 'link':
        return (Icons.link_outlined, '链接', KkColors.teal);
      default:
        return (Icons.download_outlined, '素材', KkColors.coral);
    }
  }
}
