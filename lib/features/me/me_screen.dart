import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/parse_count.dart';
import '../../core/widgets/cover_art.dart';
import '../../core/widgets/tappable.dart';
import '../../data/seed/mock_seed.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/repositories/project_repository.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/project_provider.dart';
import '../../router/routes.dart';
import '../shared/avatar.dart';
import 'widgets/contribution_heatmap.dart';

/// 我的屏 — 任务③整屏重构为"个人主页"式布局。
///
/// 从上到下 7 块(签到卡不做,相机/封面上传不做):
///   1. 渐变 banner(160px,暖色柔和渐变)+ 右上通知/设置图标
///   2. 大头像(72×72,压在 banner 底沿)+ 名字 + 编辑资料链接
///   3. inline 四联统计(关注/粉丝/获赞/收藏,纯文字无边框)
///   4. (签到卡跳过)
///   5. 我的贡献卡(白卡 + ContributionHeatmap bare 嵌入,整卡 → activity)
///   6. 我关注的领域(chip 排 + "+调整")
///   7. 我关注的话题(chip 排 / 空态)
///   8. 最近看过(横向小卡 + 清空)
///
/// 真实计数(HANDOFF §6.10 禁 ×200):
///   - 关注 = me.followingIds.length
///   - 粉丝 = me.followerIds.length
///   - 获赞 = myProjects.likes + myPosts.likes
///   - 收藏 = appState.savedProjectIds.length
///   - 贡献活跃 = mockHeatmapCells 里 level>0 的格子数
///
/// 零旁白(HANDOFF §3):无"完善资料"之类引导。
/// 铁律:coral 只给 take / 无 emoji / 触控 ≥44pt / 禁 artifactType 分支。
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
    final savedCount = appState.savedProjectIds.length;
    final unreadCount = appState.unreadNotifIds.length;

    // 最近看过 → 真实 Project 列表(过滤已删/不存在的 ID)
    final recentProjects = appState.browseHistory
        .map((id) => projectRepo.byId(id))
        .whereType<Project>()
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: KkSpacing.xxxl),
      children: [
        // 1+2. 渐变 banner + 大头像 + 名字 + 编辑资料
        _headerBanner(
          context: context,
          me: me,
          unreadCount: unreadCount,
        ),
        const SizedBox(height: KkSpacing.lg),
        // 3. inline 四联统计(纯文字,无边框无卡片)
        _inlineStats(
          context: context,
          followingCount: followingCount,
          followerCount: followerCount,
          totalLikes: totalLikes,
          savedCount: savedCount,
        ),
        const SizedBox(height: KkSpacing.xl),
        // 5. 我的贡献卡(整卡 → activity)
        _contributionCard(context),
        const SizedBox(height: KkSpacing.xl),
        // 6. 我关注的领域
        _followedDomainsSection(context),
        const SizedBox(height: KkSpacing.xl),
        // 7. 我关注的话题
        _followedTopicsSection(context),
        const SizedBox(height: KkSpacing.xl),
        // 8. 最近看过 + 清空
        _recentlyViewedSection(context, recentProjects),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // 1+2. 渐变 banner + 大头像 + 名字
  // ──────────────────────────────────────────────────────────────────
  Widget _headerBanner({
    required BuildContext context,
    required KkUser? me,
    required int unreadCount,
  }) {
    const bannerHeight = 160.0;
    const avatarSize = 72.0;
    return SizedBox(
      // banner + 半个头像(头像压在 banner 底沿,一半上一半下)
      height: bannerHeight + avatarSize / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 渐变 banner(暖色柔和,浅珊瑚 → 暖纸底,不艳)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF3E1CE), // 浅珊瑚/浅橙
                    KkColors.bg, // 暖纸底 #FBF9F4
                  ],
                ),
              ),
            ),
          ),
          // 右上:通知铃(未读红点)+ 设置齿轮
          Positioned(
            top: KkSpacing.sm,
            right: KkSpacing.xs,
            child: Row(
              children: [
                _bannerIconBtn(
                  icon: Icons.notifications_outlined,
                  onTap: () => context.push(KkRoutes.notifications),
                  hasDot: unreadCount > 0,
                ),
                _bannerIconBtn(
                  icon: Icons.settings_outlined,
                  onTap: () => context.push(KkRoutes.settings),
                ),
              ],
            ),
          ),
          // 大头像(压在 banner 底沿)+ 名字 + 编辑资料
          Positioned(
            top: bannerHeight - avatarSize / 2, // 头像中心落在 banner 底沿
            left: KkSpacing.lg,
            right: KkSpacing.lg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 头像外圈白边(在渐变上更清晰)
                Container(
                  decoration: const BoxDecoration(
                    color: KkColors.bg,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: KkAvatar(userId: 'me', user: me, size: avatarSize),
                ),
                const SizedBox(width: KkSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          me?.name ?? '我',
                          style: KkType.h2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Tappable(
                          onTap: () => context.push(KkRoutes.profileEdit),
                          borderRadius: BorderRadius.circular(KkRadius.sm),
                          child: Text(
                            '编辑资料',
                            style: KkType.bodySm
                                .copyWith(color: KkColors.teal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// banner 右上小图标按钮(半透明白底圆 + 图标,通知带未读红点)。
  Widget _bannerIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool hasDot = false,
  }) {
    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KkRadius.pill),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0x14FFFFFF), // 8% 白
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: KkColors.t1),
          ),
          if (hasDot)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  // SPEC:coral 只给 take;未读红点用 like 红(情感色,非 take)
                  color: KkColors.like,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // 3. inline 四联统计(纯文字,无边框无卡片)
  // ──────────────────────────────────────────────────────────────────
  Widget _inlineStats({
    required BuildContext context,
    required int followingCount,
    required int followerCount,
    required int totalLikes,
    required int savedCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _statBlock(
              '关注',
              followingCount,
              onTap: () => context.push(KkRoutes.follows('me')),
            ),
          ),
          Expanded(
            child: _statBlock(
              '粉丝',
              followerCount,
              onTap: () => context.push(KkRoutes.follows('me')),
            ),
          ),
          Expanded(
            child: _statBlock('获赞', totalLikes),
          ),
          Expanded(
            child: _statBlock(
              '收藏',
              savedCount,
              onTap: () => context.go(KkRoutes.library),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBlock(String label, int value, {VoidCallback? onTap}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatCount(value), style: KkType.monoLg),
        const SizedBox(height: 2),
        Text(
          label,
          style: KkType.bodySm.copyWith(color: KkColors.t3, fontSize: 11),
        ),
      ],
    );
    if (onTap == null) return content;
    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KkRadius.md),
      child: content,
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // 5. 我的贡献 卡片(白卡 + bare 热力图嵌入,整卡 → activity)
  // ──────────────────────────────────────────────────────────────────
  Widget _contributionCard(BuildContext context) {
    // 真实活跃数 = cells 里 level>0 的格子数(非 ×N 编造)
    final activeDays = mockHeatmapCells.where((c) => c.level > 0).length;
    return Tappable(
      onTap: () => context.push(KkRoutes.activity),
      borderRadius: BorderRadius.circular(KkRadius.lg),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
        padding: const EdgeInsets.all(KkSpacing.lg),
        decoration: BoxDecoration(
          color: KkColors.bgCard,
          borderRadius: BorderRadius.circular(KkRadius.lg),
          boxShadow: KkElevation.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('我的贡献', style: KkType.h3),
                const Spacer(),
                Text(
                  '最近 13 周 · 共 $activeDays 次活跃',
                  style: KkType.mono.copyWith(color: KkColors.t3, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: KkSpacing.md),
            // bare 模式:不带自带容器,嵌入本卡(避免双层 bgCard/边框)
            ContributionHeatmap(
              cells: mockHeatmapCells,
              showStats: false,
              showLegend: true,
              bare: true,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // 6. 我关注的领域(chip 排 + "+调整")
  // ──────────────────────────────────────────────────────────────────
  Widget _followedDomainsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我关注的领域', style: KkType.h3),
          const SizedBox(height: KkSpacing.md),
          Wrap(
            spacing: KkSpacing.sm,
            runSpacing: KkSpacing.sm,
            children: [
              for (final d in mockFollowedDomains) _domainChip(_domainLabel(d)),
              _addChip(
                label: '调整',
                onTap: () => context.push(KkRoutes.profileEdit),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 7 领域值 → 中文标签(与 profile_edit._domainOptions 同源)。
  String _domainLabel(String value) {
    const map = <String, String>{
      'ai_image': 'AI图',
      'ai_video': 'AI视频',
      'web': '网页',
      'app': 'App',
      'tool': '工具',
      'opensource': '开源',
      'prompt': 'Prompt',
    };
    return map[value] ?? value;
  }

  // ──────────────────────────────────────────────────────────────────
  // 7. 我关注的话题(chip 排 / 空态)
  // ──────────────────────────────────────────────────────────────────
  Widget _followedTopicsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我关注的话题', style: KkType.h3),
          const SizedBox(height: KkSpacing.md),
          if (mockFollowedTopics.isEmpty)
            Text(
              '# 还没有关注的话题',
              style: KkType.bodySm.copyWith(color: KkColors.t3),
            )
          else
            Wrap(
              spacing: KkSpacing.sm,
              runSpacing: KkSpacing.sm,
              children: [
                for (final t in mockFollowedTopics)
                  _topicChip(context, t),
              ],
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // 8. 最近看过 + 清空(横向小卡)
  // ──────────────────────────────────────────────────────────────────
  Widget _recentlyViewedSection(BuildContext context, List<Project> recent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('最近看过', style: KkType.h3),
              const Spacer(),
              if (recent.isNotEmpty)
                Tappable(
                  // 任务③:app_state 暂无 clearBrowseHistory 方法,
                  // 按任务文件"先留视觉"指令暂不接线(Phase 5 接后端时接通)。
                  onTap: () {},
                  borderRadius: BorderRadius.circular(KkRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KkSpacing.sm,
                      vertical: 4,
                    ),
                    child: Text(
                      '清空',
                      style: KkType.bodySm.copyWith(color: KkColors.t3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: KkSpacing.md),
          if (recent.isEmpty)
            Text(
              '还没有看过',
              style: KkType.bodySm.copyWith(color: KkColors.t3),
            )
          else
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: KkSpacing.lg),
                itemCount: recent.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: KkSpacing.md),
                itemBuilder: (ctx, i) => _recentProjectCard(ctx, recent[i]),
              ),
            ),
        ],
      ),
    );
  }

  /// 最近看过的小卡(130 宽,封面 84 + 标题/赞数)。
  Widget _recentProjectCard(BuildContext context, Project project) {
    return Tappable(
      onTap: () => context.push(KkRoutes.detail(project.id)),
      borderRadius: BorderRadius.circular(KkRadius.md),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: KkColors.bgCard,
          borderRadius: BorderRadius.circular(KkRadius.md),
          border: Border.all(color: KkColors.bd),
          boxShadow: KkElevation.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 84,
              width: double.infinity,
              child: _RecentCover(project: project),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KkSpacing.sm,
                vertical: KkSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    project.title,
                    style: KkType.bodySm
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatCount(project.likes)} 赞',
                    style: KkType.mono.copyWith(fontSize: 10, color: KkColors.t3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // chip helpers(沿用任务②克制风:bgSubtle 底 + bd 边 + t1 文字)
  // ──────────────────────────────────────────────────────────────────
  Widget _domainChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.md,
        vertical: KkSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: KkColors.bgSubtle,
        borderRadius: BorderRadius.circular(KkRadius.pill),
        border: Border.all(color: KkColors.bd),
      ),
      child: Text(
        label,
        style: KkType.bodySm.copyWith(
          color: KkColors.t1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _topicChip(BuildContext context, String tag) {
    return Tappable(
      onTap: () => context.push(KkRoutes.topic(tag)),
      borderRadius: BorderRadius.circular(KkRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.md,
          vertical: KkSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: KkColors.bgSubtle,
          borderRadius: BorderRadius.circular(KkRadius.pill),
          border: Border.all(color: KkColors.bd),
        ),
        child: Text(
          '#$tag',
          style: KkType.bodySm.copyWith(color: KkColors.t1),
        ),
      ),
    );
  }

  Widget _addChip({required String label, required VoidCallback onTap}) {
    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KkRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.md,
          vertical: KkSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(KkRadius.pill),
          border: Border.all(color: KkColors.bd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: KkColors.t2),
            const SizedBox(width: KkSpacing.xs),
            Text(
              label,
              style: KkType.bodySm.copyWith(color: KkColors.t2),
            ),
          ],
        ),
      ),
    );
  }
}

/// 最近看过小卡的封面(真图优先,断网/坏链回退 CoverArt)。
/// 与 project_card._Cover 同套路:Image.network + loadingBuilder + errorBuilder。
class _RecentCover extends StatelessWidget {
  final Project project;
  const _RecentCover({required this.project});

  @override
  Widget build(BuildContext context) {
    final media = project.resultData.media;
    String? coverUrl;
    if (media.isNotEmpty) {
      final first = media.first;
      if (first.type == 'image') {
        coverUrl = first.url;
      } else if (first.type == 'video' && first.poster != null) {
        coverUrl = first.poster;
      }
    }
    if (coverUrl == null) {
      return const CoverArt(pattern: 'waves', height: 84);
    }
    return Image.network(
      coverUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 84,
      loadingBuilder: (ctx, child, progress) =>
          progress == null ? child : const CoverArt(pattern: 'waves', height: 84),
      errorBuilder: (_, __, ___) =>
          const CoverArt(pattern: 'waves', height: 84),
    );
  }
}
