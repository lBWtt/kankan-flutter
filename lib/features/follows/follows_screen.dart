import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/backend_id.dart';
import '../../core/widgets/skeletons.dart';
import '../../core/widgets/kk_back_button.dart';
import '../../core/widgets/tappable.dart';
import '../../data/api/users_api.dart';
import '../../domain/models/models.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/project_provider.dart';
import '../../router/routes.dart';
import '../shared/avatar.dart';
import '../shared/empty_state.dart';
import '../shared/remote_error.dart';

/// 关注 / 粉丝列表屏 — HANDOFF §6.5 真路由 + §6.10 真实计数。
///
/// 路由:`/u/:userId/follows?type=followers|following`(可深链)。
/// 双 Tab:
///   - 关注 N   我关注的人(remote: GET /users/{id}/following;mock: user.followingIds)
///   - 粉丝 N   关注我的人(remote: GET /users/{id}/followers;mock: user.followerIds)
/// N 取真实长度,无虚构放大公式(Web 版重灾区,Flutter 端从零做对)。
///
/// 数据源策略(与 kankan _ProjectList 同套路):
///   - useRemote + 真后端 id(UUID) → 真接口,AsyncValue 三态(loading→骨架 /
///     error→RemoteError 重试 / data→列表)。下拉刷新 invalidate provider 重拉。
///   - mock(短 id 'chen' 或 'me') → 内存 user.followingIds/followerIds,
///     保留原 300ms 假 loading 骨架(与 discover/kankan/library mock 分支一致)。
///
/// 行内布局:TappableAvatar(40px) + 名字/简介 + 关注按钮。
/// 行整体 Tappable → push /u/:rowUserId。关注按钮独立 Tappable → toggleFollow
/// (嵌套 InkWell 内层优先消费手势,不会触发行点击)。关注按钮逻辑不动(Claude 双轨)。
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
  // mock 分支:300ms 假 loading 骨架(与 discover/kankan/library mock 一致)。
  // remote 分支用 AsyncValue 自带 loading,不用这个旗。
  bool _mockLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      // 'followers' → 第二个 Tab(index 1);其他默认 'following'(index 0)。
      initialIndex: widget.initialTab == 'followers' ? 1 : 0,
    );
    // mock 分支才需要假 loading;remote 分支 AsyncValue 自带 loading,跳过。
    if (!_isRemote) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _mockLoading = false);
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _isRemote =>
      AppConfig.useRemote && looksLikeBackendId(widget.userId);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userByIdProvider(widget.userId));
    // 远程:tab 计数从 followers/following 列表的 .length 取(真接口结果)。
    // mock:tab 计数从 user.followingIds/followerIds 取(真实数组长度)。
    final mockFollowingIds = user?.followingIds ?? const <String>[];
    final mockFollowerIds = user?.followerIds ?? const <String>[];

    final isRemote = _isRemote;
    // remote 分支才 watch 真接口 provider(避免 mock 模式误触发后端请求)。
    // isRemote 对一个 widget 实例是常量(取决于 compile-time useRemote + widget.userId),
    // 条件 watch 不会导致依赖不一致。
    final followingAsync = isRemote
        ? ref.watch(remoteFollowingProvider(widget.userId))
        : null;
    final followersAsync = isRemote
        ? ref.watch(remoteFollowersProvider(widget.userId))
        : null;

    // valueOrNull:loading 时 null → 退化 mock 计数占位;data 时真长度。
    final followingCount =
        followingAsync?.valueOrNull?.length ?? mockFollowingIds.length;
    final followerCount =
        followersAsync?.valueOrNull?.length ?? mockFollowerIds.length;

    // Tab 内容:remote → _RemoteFollowList(AsyncValue 三态);mock → _FollowList。
    final followingTab = isRemote
        ? _RemoteFollowList(
            async: followingAsync!,
            emptyTitle: '还没有关注的人',
            onRetry: () async =>
                ref.invalidate(remoteFollowingProvider(widget.userId)),
          )
        : _FollowList(
            userIds: mockFollowingIds,
            emptyTitle: '还没有关注的人',
          );
    final followersTab = isRemote
        ? _RemoteFollowList(
            async: followersAsync!,
            emptyTitle: '还没有粉丝',
            onRetry: () async =>
                ref.invalidate(remoteFollowersProvider(widget.userId)),
          )
        : _FollowList(
            userIds: mockFollowerIds,
            emptyTitle: '还没有粉丝',
          );

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
          // mock loading 时锁 TabBar 避免误触;remote 分支 _mockLoading 永远 true
          // (initState 跳过假 loading),但 remote 用 AsyncValue 自带 loading,不锁。
          IgnorePointer(
            ignoring: !isRemote && _mockLoading,
            child: _tabBar(followingCount, followerCount),
          ),
          Expanded(
            child: isRemote
                ? TabBarView(
                    controller: _tabCtrl,
                    children: [followingTab, followersTab],
                  )
                : _mockLoading
                    ? const _SkeletonFollowList()
                    : TabBarView(
                        controller: _tabCtrl,
                        children: [followingTab, followersTab],
                      ),
          ),
        ],
      ),
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
// 远程列表(AsyncValue 三态:loading→骨架 / error→RemoteError 重试 / data→列表)
// ──────────────────────────────────────────────────────────────────

class _RemoteFollowList extends StatelessWidget {
  final AsyncValue<List<KkUser>> async;
  final String emptyTitle;
  final Future<void> Function() onRetry;

  const _RemoteFollowList({
    required this.async,
    required this.emptyTitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => _SkeletonFollowList(),
      error: (_, __) => RemoteError(
        message: '加载失败',
        onRetry: onRetry,
      ),
      data: (users) {
        if (users.isEmpty) {
          // 零旁白:空状态只一行事实(followers variant:people_outline + 「还没关注」)。
          return ListView(
            children: [
              EmptyState(
                variant: EmptyStateVariant.followers,
                title: emptyTitle,
              ),
            ],
          );
        }
        // KkUser 已在 UsersApi._parseUserList 里 cacheRemoteUser,
        // _FollowRow watch userByIdProvider 能查到。传 id 复用 mock 分支同款行。
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: KkSpacing.xxl),
          itemCount: users.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: KkColors.divider, indent: 72),
          itemBuilder: (context, i) => _FollowRow(userId: users[i].id),
        );
      },
    );
  }
}

/// 5 行骨架(mock 假 loading 与 remote 真 loading 共用)。
class _SkeletonFollowList extends StatelessWidget {
  const _SkeletonFollowList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: KkSpacing.xxl),
      itemCount: 5,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: KkColors.divider, indent: 72),
      itemBuilder: (_, __) => const _SkeletonFollowRow(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// 列表(mock 分支:user.followingIds/followerIds 派生)
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
