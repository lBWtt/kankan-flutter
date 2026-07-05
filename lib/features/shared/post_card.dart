import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/parse_count.dart';
import '../../core/utils/time_ago.dart';
import '../../core/widgets/cover_art.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../data/seed/mock_seed.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/project_provider.dart';
import '../../router/routes.dart';
import 'avatar.dart';

/// HANDOFF §1 动态卡(轻)— 发现页 feed 用。
///
/// 动态二分:文字 + 可选图 + 话题 + 引用项目(浮窗)。
/// 没有 resultData / actions(那是 Project 的)。
///
/// 任务⑮:补配图网格(1/2/3/4-9 布局)+ 引用卡改浅绿底 + 分类徽标。
///
/// 零旁白(HANDOFF §3):无"点赞 +1"等引导,只图标 + 真实数字。
/// 计数铁律(HANDOFF §6.10):likes/commentCount 取真实数组长度。
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
                      // 对齐原型:第二行「@handle · 时间」(handle = 作者 id,同引用卡)。
                      Text(
                        '@${post.authorId} · ${timeAgo(post.createdAtMs)}',
                        style: KkType.mono.copyWith(
                          fontSize: 11,
                          color: KkColors.t3,
                        ),
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
          // 配图网格(任务⑮A:1/2/3/4-9 布局,放正文下、标签/引用上)
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: KkSpacing.md),
            _ImageGrid(media: post.media),
          ],
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

// ── 任务⑮A:配图网格(按张数布局,小红书/朋友圈式)──
//
// 1 张 → 单大图(16:9,圆角 md)
// 2 张 → 并排(1:1,中间 xs 间距)
// 3 张 → 一行三(1:1)
// 4–9 张 → 3 列九宫格(1:1)
// >9 张 → 只显前 9,第 9 张叠「+N」遮罩
// 每张:Image.network(loadingBuilder/errorBuilder 回退 CoverArt,同 project_card);
// video 叠 play 图标。
class _ImageGrid extends StatelessWidget {
  final List<MediaItem> media;

  const _ImageGrid({required this.media});

  @override
  Widget build(BuildContext context) {
    final shown = media.take(9).toList();
    final count = shown.length;
    final overflow = media.length - 9; // >0 表示有溢出

    if (count == 1) {
      // 单大图 16:9
      return _GridCell(
        media: shown[0],
        aspect: 16 / 9,
        borderRadius: KkRadius.md,
        overlayCount: overflow > 0 ? overflow : null,
      );
    }

    if (count == 2) {
      return Row(
        children: [
          Expanded(child: _GridCell(media: shown[0], aspect: 1)),
          const SizedBox(width: KkSpacing.xs),
          Expanded(child: _GridCell(media: shown[1], aspect: 1)),
        ],
      );
    }

    if (count == 3) {
      return Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(child: _GridCell(media: shown[i], aspect: 1)),
            if (i < 2) const SizedBox(width: KkSpacing.xs),
          ],
        ],
      );
    }

    // 4–9 张:3 列九宫格(AspectRatio 1:1,间距 xs)
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: KkSpacing.xs,
      crossAxisSpacing: KkSpacing.xs,
      childAspectRatio: 1,
      children: [
        for (var i = 0; i < count; i++)
          _GridCell(
            media: shown[i],
            aspect: 1,
            overlayCount: (i == 8 && overflow > 0) ? overflow : null,
          ),
      ],
    );
  }
}

// ── 单格(Image.network + CoverArt 回退;video 叠 play;溢出叠+N)──
class _GridCell extends StatelessWidget {
  final MediaItem media;
  final double aspect;
  final double borderRadius;
  final int? overlayCount; // >0 时叠「+N」遮罩(仅溢出末格)

  const _GridCell({
    required this.media,
    required this.aspect,
    this.borderRadius = KkRadius.sm,
    this.overlayCount,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = media.type == 'video';
    final url = isVideo ? (media.poster ?? media.url) : media.url;
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 图/封面:有 URL → Image.network(loading/error 回退 CoverArt);
            // 无 URL → CoverArt 占位(同 project_card 套路,不引新依赖)
            if (url.isNotEmpty)
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const CoverArt(pattern: 'grid');
                },
                errorBuilder: (context, error, stackTrace) =>
                    const CoverArt(pattern: 'grid'),
              )
            else
              const CoverArt(pattern: 'grid'),
            // video 叠 play 图标
            if (isVideo)
              Center(
                child: Icon(Icons.play_circle_outline,
                    size: 36, color: Colors.white.withAlpha(220)),
              ),
            // 溢出末格叠「+N」浅黑遮罩
            if (overlayCount != null && overlayCount! > 0)
              Container(
                color: Colors.black.withAlpha(140),
                alignment: Alignment.center,
                child: Text(
                  '+$overlayCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'NotoSerifSC',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 引用项目浮窗(任务⑮B:浅绿底 + 分类徽标)──
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
              // 浅绿底(原型样式,区别于原 bgSubtle 中性底)
              color: KkColors.mint,
              borderRadius: BorderRadius.circular(KkRadius.md),
            ),
            child: Row(
              children: [
                // 小封面(40×40,圆角,领域色块 + 图标)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: KkColors.bgCard,
                    borderRadius: BorderRadius.circular(KkRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _domainIcon(p.domain),
                    size: 20,
                    color: KkColors.teal,
                  ),
                ),
                const SizedBox(width: KkSpacing.md),
                // 项目名(t1 粗) + @handle(t3,作者 handle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.title,
                        style: KkType.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: KkColors.t1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${p.authorId}',
                        style: KkType.mono.copyWith(
                          fontSize: 11,
                          color: KkColors.t3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KkSpacing.sm),
                // 右上分类徽标(teal 描边 pill + 中文 label)
                _DomainBadge(domain: p.domain),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 分类徽标(teal 描边 pill + 中文 label,映射同 me _domainLabel)──
class _DomainBadge extends StatelessWidget {
  final String domain;

  const _DomainBadge({required this.domain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(KkRadius.pill),
        border: Border.all(color: KkColors.teal, width: 0.8),
      ),
      child: Text(
        _domainLabel(domain),
        style: const TextStyle(
          color: KkColors.teal,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'NotoSerifSC',
        ),
      ),
    );
  }

  /// 7 领域值 → 中文标签(与 me 页 _domainLabel / profile_edit._domainOptions 同源)。
  static const _map = <String, String>{
    'ai_image': 'AI图',
    'ai_video': 'AI视频',
    'web': '网页',
    'app': 'App',
    'tool': '工具',
    'opensource': '开源',
    'prompt': 'Prompt',
  };

  static String _domainLabel(String value) => _map[value] ?? value;
}

/// 领域 → 图标(同 project_card._domainIcon,引用卡小封面用)。
IconData _domainIcon(String domain) {
  switch (domain) {
    case 'ai_image':
      return Icons.image_outlined;
    case 'ai_video':
      return Icons.play_circle_outline;
    case 'web':
      return Icons.language;
    case 'app':
      return Icons.phone_iphone;
    case 'tool':
      return Icons.build_outlined;
    case 'opensource':
      return Icons.code;
    case 'prompt':
      return Icons.chat_bubble_outline;
    default:
      return Icons.article_outlined;
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
