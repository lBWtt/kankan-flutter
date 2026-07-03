import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/skeletons.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/post_repository.dart';
import '../../providers/app_state_provider.dart';
import '../../router/routes.dart';
import '../shared/comment_bottom_sheet.dart';
import '../shared/empty_state.dart';
import '../shared/post_card.dart';

/// 发现屏 — HANDOFF §1 动态(轻)feed。
///
/// 双流(HANDOFF §6.6 — Web 版重灾区,Flutter 从零做对):
///   - 推荐:全部动态(按时间倒序)
///   - 关注:仅关注的人发的(从 followedUserIds 过滤)
///
/// 切换 tab 不重新请求,本地过滤(Phase 5 接后端再分页)。
/// 评论弹层:点评论图标 → showCommentBottomSheet(统一 CommentThread)。
///
/// 零旁白(HANDOFF §3):无"快来发条动态吧"之类引导。空状态用 EmptyState。
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
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
    // KkRootShell 已提供 NoiseBackground + SafeArea(bottom: false),
    // branch 屏只返回内容 Column,不重复包装(避免双重噪点 + 双重 SafeArea)。
    return Column(
      children: [
        _topBar(),
        // loading 时锁住 Tab,避免在骨架屏期间切 feed。
        IgnorePointer(ignoring: _loading, child: _tabBar()),
        Expanded(
          child: ColoredBox(
            // 任务②:列表区 bg2 底,PostCard bgCard "浮"起来
            color: KkColors.bgSubtle,
            child: _loading
                ? _skeletonList()
                : TabBarView(
                    controller: _tabCtrl,
                    children: const [
                      _RecommendFeed(),
                      _FollowingFeed(),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── 加载态骨架屏:3 个 ProjectCardSkeleton + 1 个 PostCardSkeleton ──
  // PostCardSkeleton 自带 horizontal: KkSpacing.lg 内边距,ProjectCardSkeleton
  // 是 edge-to-edge 的,所以外层包一层 lg 横向 padding 对齐真实 feed 边距。
  Widget _skeletonList() {
    return ListView(
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: KkSpacing.lg,
            vertical: KkSpacing.sm,
          ),
          child: ProjectCardSkeleton(),
        ),
        SizedBox(height: KkSpacing.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: KkSpacing.lg),
          child: ProjectCardSkeleton(),
        ),
        SizedBox(height: KkSpacing.lg),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: KkSpacing.lg),
          child: ProjectCardSkeleton(),
        ),
        SizedBox(height: KkSpacing.lg),
        PostCardSkeleton(),
      ],
    );
  }

  // ── 顶栏:标题 + 搜索入口 ──
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      child: Row(
        children: [
          // 任务②:标题后 6×6 teal 品牌点
          Text('发现', style: KkType.h1),
          const SizedBox(width: 7),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: KkColors.teal,
              shape: BoxShape.circle,
            ),
          ),
          const Spacer(),
          Tappable(
            onTap: () => context.push(KkRoutes.search),
            child: const Icon(Icons.search, size: 22, color: KkColors.t1),
          ),
        ],
      ),
    );
  }

  // ── 双流 tab:推荐 / 关注 ──
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
          Tab(text: '推荐'),
          Tab(text: '关注'),
        ],
      ),
    );
  }
}

// ── 推荐 feed:全部动态(按时间倒序)──
class _RecommendFeed extends ConsumerWidget {
  const _RecommendFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    // F-36:all() 已返回可变副本(F-36 改 List.of),可直接 sort。
    // 原 `repo.all()..sort()` 在 all() 返回 List.unmodifiable 时会运行时崩
    // (UnsupportedError: Cannot modify an unmodifiable list)。
    final posts = repo.all()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    if (posts.isEmpty) {
      return ListView(
        children: const [EmptyState(variant: EmptyStateVariant.feed)],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: KkSpacing.xxl),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        return PostCard(
          post: post,
          onTap: () => context.push(KkRoutes.postDetail(post.id)),
          onCommentTap: () => _showComments(context, ref, post),
        );
      },
    );
  }

  void _showComments(BuildContext context, WidgetRef ref, Post post) {
    final repo = ref.read(postRepositoryProvider);
    final comments = repo.commentsFor(post.id);
    showCommentBottomSheet(
      context,
      hostType: 'post',
      hostId: post.id,
      initialComments: comments,
    );
  }
}

// ── 关注 feed:仅关注的人发的 ──
class _FollowingFeed extends ConsumerWidget {
  const _FollowingFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final repo = ref.watch(postRepositoryProvider);
    final followed = appState.followedUserIds;

    // 关注流 = 关注的人发的动态(按时间倒序)。
    // 首次启动 app_state.followedUserIds 为空(用户还没主动关注过),
    // 给 fallback:展示 mock 里"我(me)"默认关注的人(lin/chen/wang),
    // 让关注流不是恒空(否则首次进 app 关注流空,体验差)。
    // 用户主动关注/取关后,followed 非空,走真实过滤。
    final effectiveFollowed = followed.isEmpty
        ? const <String>{'chen', 'lin', 'wang'}
        : followed;

    final posts = repo
        .all()
        .where((p) => effectiveFollowed.contains(p.authorId))
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    if (posts.isEmpty) {
      return ListView(
        children: const [EmptyState(variant: EmptyStateVariant.feed)],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: KkSpacing.xxl),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        return PostCard(
          post: post,
          onTap: () => context.push(KkRoutes.postDetail(post.id)),
          onCommentTap: () => _showComments(context, ref, post),
        );
      },
    );
  }

  void _showComments(BuildContext context, WidgetRef ref, Post post) {
    final repo = ref.read(postRepositoryProvider);
    final comments = repo.commentsFor(post.id);
    showCommentBottomSheet(
      context,
      hostType: 'post',
      hostId: post.id,
      initialComments: comments,
    );
  }
}
