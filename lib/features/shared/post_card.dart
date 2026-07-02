import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/parse_count.dart';
import '../../core/utils/time_ago.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../data/seed/mock_seed.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/project_provider.dart';
import '../../domain/repositories/project_repository.dart';
import '../../router/routes.dart';
import 'avatar.dart';

/// HANDOFF §1 动态卡(轻)— 发现页 feed 用。
///
/// 动态二分:文字 + 可选图 + 话题 + 引用项目(浮窗)。
/// 没有 resultData / actions(那是 Project 的)。
///
/// 零旁白(HANDOFF §3):无"点赞 +1"等引导,只图标 + 真实数字。
/// 计数铁律(HANDOFF §6.10):likes/commentCount 取真实数组长度。
///
/// Phase 4 Hero 共享元素(HANDOFF §5 动效系统):
///   - PostCard 不参与 Hero。虽然 Post 模型有 `media: List<MediaItem>` 字段,
///     但本卡当前渲染为「作者行 + 正文 + 标签 + 引用项目浮窗 + 操作行」,
///     无首图 / cover 展示区(无 _buildMedia / _buildFirstImage 之类方法),
///     故无 Hero 发送端。动态详情页(post_detail_screen)顶部也不需要 cover
///     飞入过渡。
///   - 引用项目浮窗(_QuoteProject)内的 40×40 小封面是引用项目的占位,
///     不是本动态的 cover,不参与 Hero 共享元素(由被引用项目的 detail_screen
///     Hero 负责)。
///   - 若未来 PostCard 接入首图渲染,使用 tag `'post-cover-{post.id}'`
///     与 post_detail_screen 顶部配对。
class PostCard extends ConsumerWidget {
  final Post post;
  final VoidCallback? onCommentTap;

  /// 整卡点击(→ 动态详情)。null 时仅内部热区可点(头像/作者名/引用/点赞/评论)。
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    this.onCommentTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userByIdProvider(post.authorId));
    final appState = ref.watch(appStateProvider);
    final isLiked = appState.likedItemIds.contains(post.id);
    final likeCount = post.likes + (isLiked ? 1 : 0);

    final card = Container(
      decoration: const BoxDecoration(
        color: KkColors.bgCard,
        border: Border(
          bottom: BorderSide(color: KkColors.divider),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者行
          Row(
            children: [
              TappableAvatar(
                userId: post.authorId,
                user: author,
                size: 36,
                onTap: () => context.push(KkRoutes.profile(post.authorId)),
              ),
              const SizedBox(width: KkSpacing.md),
              Expanded(
                child: Tappable(
                  onTap: () => context.push(KkRoutes.profile(post.authorId)),
                  borderRadius: BorderRadius.circular(KkRadius.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        author?.name ?? post.authorId,
                        style: KkType.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        timeAgo(post.createdAtMs),
                        style: KkType.mono.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              _FollowButton(userId: post.authorId),
            ],
          ),
          const SizedBox(height: KkSpacing.md),
          // 正文
          Text(post.content, style: KkType.body.copyWith(height: 1.6)),
          // 标签(无 emoji,纯 #tag)
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: KkSpacing.sm),
            Wrap(
              spacing: KkSpacing.sm,
              runSpacing: KkSpacing.xs,
              children: [
                for (final t in post.tags)
                  Text(
                    '#$t',
                    style: KkType.bodySm.copyWith(color: KkColors.teal),
                  ),
              ],
            ),
          ],
          // 引用项目浮窗
          if (post.quoteProjectId != null) ...[
            const SizedBox(height: KkSpacing.md),
            _QuoteProject(projectId: post.quoteProjectId!),
          ],
          // 操作行:点赞 / 评论
          const SizedBox(height: KkSpacing.md),
          Row(
            children: [
              _IconStat(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                value: formatCount(likeCount),
                color: isLiked ? KkColors.like : KkColors.t3,
                onTap: () => ref
                    .read(appStateProvider.notifier)
                    .toggleLike(post.id),
              ),
              const SizedBox(width: KkSpacing.lg),
              _IconStat(
                icon: Icons.chat_bubble_outline,
                // F-8:评论数取 commentsFor(post.id).length(与详情页 / 卡片同源),
                // 不用写死的 post.commentCount(D 类 bug 在 feed 复现)。
                value: formatCount(commentsFor(post.id).length),
                color: KkColors.t3,
                // 默认:推全屏评论页(HANDOFF §6.1)。调用方可覆盖(如 discover 用底部弹层)。
                onTap: onCommentTap ??
                    () => context.push(KkRoutes.comments('post', post.id)),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );

    // 整卡点击(内部热区优先,手势竞技场自然分离)
    if (onTap != null) {
      return Tappable(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: card,
      );
    }
    return card;
  }
}

// ── 引用项目浮窗 ──
class _QuoteProject extends ConsumerWidget {
  final String projectId;

  const _QuoteProject({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectByIdProvider(projectId));
    return project.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (p) {
        if (p == null) return const SizedBox.shrink();
        return Tappable(
          onTap: () => context.push(KkRoutes.detail(p.id)),
          borderRadius: BorderRadius.circular(KkRadius.md),
          child: Container(
            padding: const EdgeInsets.all(KkSpacing.md),
            decoration: BoxDecoration(
              color: KkColors.bgSubtle,
              borderRadius: BorderRadius.circular(KkRadius.md),
              border: Border.all(color: KkColors.bd),
            ),
            child: Row(
              children: [
                // 封面占位(领域色块)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: KkColors.mint,
                    borderRadius: BorderRadius.circular(KkRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.bookmark_outlined,
                    size: 18,
                    color: KkColors.teal,
                  ),
                ),
                const SizedBox(width: KkSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.title,
                        style: KkType.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        p.summary,
                        style: KkType.bodySm.copyWith(
                          color: KkColors.t3,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: KkColors.t3),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 关注按钮(本地状态,Phase 3 接全局 follow)──
class _FollowButton extends ConsumerWidget {
  final String userId;

  const _FollowButton({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(appStateProvider).followedUserIds.contains(userId);
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

// ── 图标 + 数字按钮(44pt 热区)──
class _IconStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _IconStat({
    required this.icon,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: KkSpacing.sm,
          horizontal: KkSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: KkType.mono.copyWith(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
