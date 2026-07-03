import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/parse_count.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/repositories/project_repository.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/project_provider.dart';
import '../../router/routes.dart';
import '../shared/avatar.dart';

/// 我的屏 — HANDOFF §6.10 真实数字(禁 ×200 编造)。
///
/// Phase 3 升级:
///   - 个人信息卡点击 → 跳 profile('me')
///   - 三档统计(发布/收藏/拿走)真实计数,点击跳对应屏
///   - 贡献热力图(86 cells,真实 mock 数据)
///   - 菜单:通知(带未读红点)/ 浏览历史 / 设置 / 关于
///
/// 零旁白(HANDOFF §3):无"完善资料"之类引导。
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userByIdProvider('me'));
    final projectRepo = ref.watch(projectRepositoryProvider);
    final postRepo = ref.watch(postRepositoryProvider);
    final appState = ref.watch(appStateProvider);

    // 真实统计(禁编造)
    final myProjects = projectRepo.byAuthor('me');
    final myPosts = postRepo.byAuthor('me');
    final followingCount = (me?.followingIds ?? const <String>[]).length;
    final followerCount = (me?.followerIds ?? const <String>[]).length;
    final totalLikes = myProjects.fold<int>(0, (s, p) => s + p.likes) +
        myPosts.fold<int>(0, (s, p) => s + p.likes);
    final unreadCount = appState.unreadNotifIds.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: KkSpacing.xxxl),
      children: [
        // 顶栏:标题 + 设置入口
        _topBar(context),
        // 个人信息卡(点击 → profile)
        _profileCard(
          context: context,
          me: me,
          followingCount: followingCount,
          followerCount: followerCount,
          totalLikes: totalLikes,
        ),
        const SizedBox(height: KkSpacing.lg),
        // 菜单(含「活跃」入口 → 活动页大热力图 + 时间线)
        _menu(context, appState.browseHistory.length, unreadCount),
      ],
    );
  }

  // ── 顶栏 ──
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      child: Row(
        children: [
          Text('我的', style: KkType.h1),
          const Spacer(),
          Tappable(
            onTap: () => context.push(KkRoutes.settings),
            child: const Icon(Icons.settings_outlined,
                size: 22, color: KkColors.t1),
          ),
        ],
      ),
    );
  }

  // ── 个人信息卡(可点击 → profile)──
  Widget _profileCard({
    required BuildContext context,
    required KkUser? me,
    required int followingCount,
    required int followerCount,
    required int totalLikes,
  }) {
    return Tappable(
      onTap: () => context.push(KkRoutes.profile('me')),
      borderRadius: BorderRadius.circular(KkRadius.lg),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
        padding: const EdgeInsets.all(KkSpacing.lg),
        decoration: BoxDecoration(
          color: KkColors.bgCard,
          borderRadius: BorderRadius.circular(KkRadius.lg),
          border: Border.all(color: KkColors.bd),
          boxShadow: KkElevation.card,
        ),
        child: Row(
          children: [
            KkAvatar(userId: 'me', user: me, size: 64),
            const SizedBox(width: KkSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    me?.name ?? '我',
                    style: KkType.h2,
                  ),
                  if (me?.bio != null && me!.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      me.bio!,
                      style: KkType.bodySm.copyWith(color: KkColors.t3),
                    ),
                  ],
                  const SizedBox(height: KkSpacing.sm),
                  // 真实数字:关注 / 粉丝 / 获赞
                  Row(
                    children: [
                      _countLabel('关注', followingCount),
                      const SizedBox(width: KkSpacing.lg),
                      _countLabel('粉丝', followerCount),
                      const SizedBox(width: KkSpacing.lg),
                      _countLabel('获赞', totalLikes),
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

  Widget _countLabel(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatCount(value),
          style: KkType.monoLg,
        ),
        Text(
          label,
          style: KkType.bodySm.copyWith(color: KkColors.t3, fontSize: 11),
        ),
      ],
    );
  }

  // ── 菜单 ──
  Widget _menu(BuildContext context, int browseHistoryCount, int unreadCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      decoration: BoxDecoration(
        color: KkColors.bgCard,
        borderRadius: BorderRadius.circular(KkRadius.md),
        border: Border.all(color: KkColors.bd),
        boxShadow: KkElevation.card,
      ),
      child: Column(
        children: [
          _menuItem(
            icon: Icons.insights_outlined,
            label: '活跃',
            onTap: () => context.push(KkRoutes.activity),
          ),
          const Divider(height: 1, color: KkColors.divider, indent: 56),
          _menuItem(
            icon: Icons.history_outlined,
            label: '浏览历史',
            trailing: '$browseHistoryCount',
            onTap: () {
              // Phase 4:跳浏览历史页(暂未做,先 no-op)
            },
          ),
          const Divider(height: 1, color: KkColors.divider, indent: 56),
          _menuItem(
            icon: Icons.notifications_outlined,
            label: '通知',
            // 未读红点(HANDOFF §6.8,真实计数)
            trailing: unreadCount > 0 ? null : null,
            badge: unreadCount > 0 ? unreadCount : null,
            onTap: () => context.push(KkRoutes.notifications),
          ),
          const Divider(height: 1, color: KkColors.divider, indent: 56),
          _menuItem(
            icon: Icons.settings_outlined,
            label: '设置',
            onTap: () => context.push(KkRoutes.settings),
          ),
          const Divider(height: 1, color: KkColors.divider, indent: 56),
          _menuItem(
            icon: Icons.info_outline,
            label: '关于',
            onTap: () {
              // Phase 4:跳关于页
            },
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    String? trailing,
    int? badge,
    VoidCallback? onTap,
  }) {
    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.md,
          vertical: KkSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: KkColors.t2),
            const SizedBox(width: KkSpacing.md),
            Expanded(
              child: Text(label, style: KkType.body),
            ),
            // 未读 badge
            if (badge != null && badge > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KkSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: KkColors.coral,
                  borderRadius: BorderRadius.circular(KkRadius.pill),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
              const SizedBox(width: KkSpacing.sm),
            ] else if (trailing != null) ...[
              Text(
                trailing,
                style: KkType.mono.copyWith(color: KkColors.t3, fontSize: 12),
              ),
              const SizedBox(width: KkSpacing.xs),
            ],
            const Icon(Icons.chevron_right, size: 18, color: KkColors.t3),
          ],
        ),
      ),
    );
  }
}
