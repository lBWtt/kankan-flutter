import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/skeletons.dart';
import '../../core/widgets/kk_back_button.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/project_provider.dart';
import '../../router/routes.dart';
import '../shared/avatar.dart';
import '../shared/empty_state.dart';

/// 关注 / 粉丝列表屏 — HANDOFF §6.5 真路由 + §6.10 真实计数。
///
/// 路由:`/u/:userId/follows?type=followers|following`(可深链)。
/// 双 Tab:
///   - 关注 N   user.followingIds(我关注的人)
///   - 粉丝 N   user.followerIds(关注我的人)
/// N 取真实数组长度,无虚构放大公式(Web 版重灾区,Flutter 端从零做对)。
///
/// 行内布局:TappableAvatar(40px) + 名字/简介 + 关注按钮。
/// 行整体 Tappable → push /u/:rowUserId。关注按钮独立 Tappable → toggleFollow
/// (嵌套 InkWell 内层优先消费手势,不会触发行点击)。
///
/// 零旁白(HANDOFF §3):空状态只一行事实,不写"去发现更多有趣的人"。
/// 珊瑚橙(HANDOFF §5):本屏无 take / 点赞,完全不用 coral。
/// 关注按钮走 teal(未关注) / bgSubtle + bd(已关注)二态,与 post_card 一致。
class FollowsScreen extends ConsumerStatefulWidget {
  final String userId;

  /// 初始 Tab:'following' | 'followers'。
  final String initialTab;

  const FollowsScreen({
    super.key,
    required this.userId,
    this.initialTab = 'following',
  });

  @override
  ConsumerState<FollowsScreen> createState() => _FollowsScreenState();
}

class _FollowsScreenState extends ConsumerState<FollowsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  // Phase 5-c:300ms 假 loading,骨架屏占位(与 discover/kankan/library 一致)
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      // 'followers' → 第二个 Tab(index 1);其他默认 'following'(index 0)。
      initialIndex: widget.initialTab == 'followers' ? 1 : 0,
    );
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
    final user = ref.watch(userByIdProvider(widget.userId));
    // 计数铁律(HANDOFF §6.10):取真实数组长度,无放大。
    final followingIds = user?.followingIds ?? const <String>[];
    final followerIds = user?.followerIds ?? const <String>[];

    return Scaffold(
      backgroundColor: KkColors.bg,
      appBar: AppBar(
        backgroundColor: KkColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const KkBackButton(),
        titleSpacing: 0,
        // 标题保持极简:只显示用户名(如"陈小匠")。当前 Tab 已表明"关注/粉丝"语义。
        title: Text(
          user?.name ?? widget.userId,
          style: KkType.h3,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // loading 时锁 TabBar,避免误触切换(触控热区不变,仅 ignoring)
          IgnorePointer(
            ignoring: _loading,
            child: _tabBar(followingIds.length, followerIds.length),
          ),
          Expanded(
            child: _loading
                ? _skeletonList()
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _FollowList(
                        userIds: followingIds,
                        emptyTitle: '还没有关注的人',
                      ),
                      _FollowList(
                        userIds: followerIds,
                        emptyTitle: '还没有粉丝',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Phase 5-c:加载态骨架 — 5 行 _SkeletonFollowRow(40 圆 + 名字/简介 + 关注按钮)
  // padding 与真实 _FollowList 一致(only bottom xxl),Divider indent 72 一致
  // ──────────────────────────────────────────────────────────────────
  Widget _skeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: KkSpacing.xxl),
      itemCount: 5,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: KkColors.divider, indent: 72),
      itemBuilder: (_, __) => const _SkeletonFollowRow(),
    );
  }

  Widget _tabBar(int followingCount, int followerCount) {
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
        tabs: [
          Tab(text: '关注 $followingCount'),
          Tab(text: '粉丝 $followerCount'),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// 骨架行 — 镜像 _FollowRow(40 头像 + 名字/简介 + 关注按钮)
// HANDOFF §5:不用 coral;只用 KkColors.*(bgCard/bgSubtle)+ 骨架 shimmer
// ──────────────────────────────────────────────────────────────────

class _SkeletonFollowRow extends StatelessWidget {
  const _SkeletonFollowRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      color: KkColors.bgCard,
      child: Row(
        children: [
          // 头像(40 圆)
          const SkeletonBox(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          const SizedBox(width: KkSpacing.md),
          // 名字 16 + 简介 12
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                SkeletonLine(width: 120, height: 16),
                SizedBox(height: 4),
                SkeletonLine(width: 80, height: 12),
              ],
            ),
          ),
          const SizedBox(width: KkSpacing.md),
          // 关注按钮(56×28 圆角 pill)
          const SkeletonBox(
            width: 56,
            height: 28,
            borderRadius: BorderRadius.all(Radius.circular(KkRadius.pill)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// 列表
// ──────────────────────────────────────────────────────────────────

class _FollowList extends ConsumerWidget {
  final List<String> userIds;
  final String emptyTitle;

  const _FollowList({
    required this.userIds,
    required this.emptyTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 零旁白(HANDOFF §3):空状态只一行事实,无 CTA 引导。
    if (userIds.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            variant: EmptyStateVariant.generic,
            title: emptyTitle,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: KkSpacing.xxl),
      itemCount: userIds.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: KkColors.divider, indent: 72),
      itemBuilder: (context, i) => _FollowRow(userId: userIds[i]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// 行
// ──────────────────────────────────────────────────────────────────

class _FollowRow extends ConsumerWidget {
  final String userId;

  const _FollowRow({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userByIdProvider(userId));

    return Tappable(
      // 行整体可点 → push 该用户 profile(HANDOFF §6.5 真路由,可深链)。
      onTap: () => context.push(KkRoutes.profile(userId)),
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.lg,
          vertical: KkSpacing.md,
        ),
        color: KkColors.bgCard,
        child: Row(
          children: [
            // 头像点击也跳同一目的地,与行点击语义一致。
            TappableAvatar(
              userId: userId,
              user: user,
              size: 40,
              onTap: () => context.push(KkRoutes.profile(userId)),
            ),
            const SizedBox(width: KkSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user?.name ?? userId,
                    style: KkType.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.bio!,
                      style: KkType.bodySm.copyWith(color: KkColors.t3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: KkSpacing.md),
            // 嵌套 Tappable:内层 InkWell 优先消费手势,行点击不触发。
            // 自视(userId == 'me')下按钮依然工作 — 你能取关别人。
            _FollowButton(userId: userId),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// 关注按钮 — 视觉样式复刻 post_card 的 _FollowButton
// (不 import 私有 widget,按 spec 要求就地复制)
//
// HANDOFF §5:不用珊瑚橙,teal(未关注)/ bgSubtle + bd(已关注)二态。
// ──────────────────────────────────────────────────────────────────

class _FollowButton extends ConsumerWidget {
  final String userId;

  const _FollowButton({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following =
        ref.watch(appStateProvider).followedUserIds.contains(userId);
    return Tappable(
      onTap: () =>
          ref.read(appStateProvider.notifier).toggleFollow(userId),
      borderRadius: BorderRadius.circular(KkRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: KkSpacing.xs,
          horizontal: KkSpacing.md,
        ),
        decoration: BoxDecoration(
          color: following ? KkColors.bgSubtle : KkColors.teal,
          borderRadius: BorderRadius.circular(KkRadius.pill),
          border: following ? Border.all(color: KkColors.bd) : null,
        ),
        child: Text(
          following ? '已关注' : '关注',
          style: TextStyle(
            color: following ? KkColors.t2 : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'NotoSerifSC',
          ),
        ),
      ),
    );
  }
}
