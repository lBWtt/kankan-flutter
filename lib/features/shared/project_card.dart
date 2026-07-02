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
import '../../domain/repositories/project_repository.dart';
import '../../router/routes.dart';
import 'avatar.dart';

/// HANDOFF §1 项目卡(重)— 看看页 / 收藏页 / 我的页共用。
///
/// 项目有成果 + 拿走物,可进库,有详情页。卡显示:
///   - 封面(有 media 取首张,否则领域色块 + 图标)
///   - 标题 + 一句话价值
///   - 作者 + 领域
///   - 真实计数:点赞 / 心得 / 拿走(HANDOFF §6.10,取真实数组长度,禁编造)
///
/// 零旁白(HANDOFF §3):无"快来围观"之类引导。
///
/// Phase 4 Hero 共享元素(HANDOFF §5 动效系统):
///   - full 模式封面外层包 `Hero(tag: 'project-cover-{project.id}')`,
///     详情页 detail_screen 顶部 cover 用同 tag 配对,实现卡片 → 详情 cover 飞入过渡。
///   - compact 模式(56×56 缩略图)不参与 Hero,避免与 full 模式在同一屏同时
///     渲染同一 project.id 时造成 Hero tag 冲突(Flutter 同 tag 多 Hero 报错)。
///   - **约束**:同一 project.id 在同一屏只能出现一次该 Hero tag。若未来某屏需
///     同时展示 full + compact 同一项目,改用 flightShuttleBuilder 或为 compact
///     单独命名 tag。
///   - tag 命名约定:`'project-cover-{project.id}'`(4-f 子代理在 detail_screen
///     顶部 cover 用同 tag 配对)。
class ProjectCard extends ConsumerWidget {
  final Project project;
  final bool showAuthor;

  /// 紧凑模式(收藏页用,无封面,仅文字行)
  final bool compact;

  const ProjectCard({
    super.key,
    required this.project,
    this.showAuthor = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) return _compact(context, ref);
    return _full(context, ref);
  }

  Widget _full(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userByIdProvider(project.authorId));
    final appState = ref.watch(appStateProvider);
    final isSaved = appState.savedProjectIds.contains(project.id);
    final isLiked = appState.likedItemIds.contains(project.id);
    final likeCount = project.likes + (isLiked ? 1 : 0);

    return Tappable(
      onTap: () {
        ref.read(appStateProvider.notifier).recordBrowse(project.id);
        context.push(KkRoutes.detail(project.id));
      },
      borderRadius: BorderRadius.circular(KkRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          color: KkColors.bgCard,
          borderRadius: BorderRadius.circular(KkRadius.lg),
          border: Border.all(color: KkColors.bd),
          boxShadow: KkElevation.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 封面(Hero 共享元素,4-f 子代理在 detail_screen 顶部用同 tag 配对)
            Hero(
              tag: 'project-cover-${project.id}',
              child: _Cover(project: project),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(KkSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(project.title, style: KkType.h3, maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    project.summary,
                    style: KkType.bodySm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showAuthor) ...[
                    const SizedBox(height: KkSpacing.md),
                    Tappable(
                      onTap: () =>
                          context.push(KkRoutes.profile(project.authorId)),
                      borderRadius: BorderRadius.circular(KkRadius.sm),
                      child: Row(
                        children: [
                          KkAvatar(
                              userId: project.authorId, user: author, size: 20),
                          const SizedBox(width: KkSpacing.xs),
                          Text(
                            author?.name ?? project.authorId,
                            style: KkType.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: KkSpacing.sm),
                          Text(
                            timeAgo(project.createdAtMs),
                            style: KkType.mono.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: KkSpacing.md),
                  // 真实计数行(HANDOFF §6.10)
                  Row(
                    children: [
                      _Stat(
                        icon: isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        value: formatCount(likeCount),
                        color: isLiked ? KkColors.like : KkColors.t3,
                        onTap: () => ref
                            .read(appStateProvider.notifier)
                            .toggleLike(project.id),
                      ),
                      const SizedBox(width: KkSpacing.lg),
                      _Stat(
                        icon: Icons.chat_bubble_outline,
                        // F-9:评论数取 commentsFor(project.id).length(与详情页同源),
                        // 不用写死的 project.commentCount(D 类 bug 在卡片复现)。
                        value: formatCount(commentsFor(project.id).length),
                        color: KkColors.t3,
                      ),
                      if (project.takeawayCount > 0) ...[
                        const SizedBox(width: KkSpacing.lg),
                        _Stat(
                          icon: Icons.download_outlined,
                          value: formatCount(project.takeawayCount),
                          color: KkColors.t3,
                        ),
                      ],
                      const Spacer(),
                      // 收藏(图标按钮,44pt 热区)
                      Tappable(
                        onTap: () => ref
                            .read(appStateProvider.notifier)
                            .toggleSave(project.id),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border_outlined,
                          size: 18,
                          color: isSaved ? KkColors.teal : KkColors.t3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compact(BuildContext context, WidgetRef ref) {
    return Tappable(
      onTap: () {
        ref.read(appStateProvider.notifier).recordBrowse(project.id);
        context.push(KkRoutes.detail(project.id));
      },
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
          children: [
            // 小封面
            _Cover(project: project, width: 56, height: 56),
            const SizedBox(width: KkSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(project.title,
                      style: KkType.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    project.summary,
                    style: KkType.bodySm.copyWith(color: KkColors.t3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        // F-9:compact 模式评论数同源 commentsFor(详情页 / full 模式一致)。
                        '${formatCount(project.likes)} 赞 · ${formatCount(commentsFor(project.id).length)} 心得',
                        style: KkType.mono.copyWith(fontSize: 11),
                      ),
                    ],
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
  }
}

// ── 封面(装饰性 CoverArt 背景 + 领域图标 / play 按钮)──
//
// Phase 3 Tier 4 接入:替换原 mint 色块 + 图标占位,改用 CoverArt 五图案装饰背景
// (HANDOFF §5 装饰用,默认 KkColors.teal 底,无 coral)。外层 ProjectCard Container
// 已 clipBehavior.antiAlias,_Cover 不再单独 ClipRRect。
class _Cover extends StatelessWidget {
  final Project project;
  final double? width;
  final double? height;

  const _Cover({required this.project, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final w = width ?? double.infinity;
    final h = height ?? 180.0;
    // compact 模式(传了 width 通常是 56×56):小尺寸用 grid 简化图案,
    // 看不出复杂的波浪 / 山峦 / 水墨细节
    final isCompact = width != null;
    final hasMedia = project.resultData.media.isNotEmpty;
    final first = hasMedia ? project.resultData.media.first : null;
    final isImage = hasMedia && first!.type == 'image';
    final isVideo = hasMedia && first!.type == 'video';

    final pattern = isCompact ? 'grid' : _domainPattern(project.domain);
    final domainIcon = _domainIcon(project.domain);

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 装饰背景:CoverArt(默认 KkColors.teal 底,5 种图案之一)
          //
          // TODO(Phase 5+):接入 cached_network_image 包后,有图项目(isImage==true)
          // 此处替换为 CachedNetworkImage 渲染真实首图,不再用 CoverArt 占位:
          //
          //   CachedNetworkImage(
          //     imageUrl: project.resultData.media.first.url,
          //     placeholder: (_, __) =>
          //         CoverArt(pattern: pattern, width: w, height: h),
          //     errorWidget: (_, __, ___) =>
          //         CoverArt(pattern: pattern, width: w, height: h),
          //     fit: BoxFit.cover,
          //     width: w,
          //     height: h,
          //   )
          //
          // 当前限制(Phase 5-a 子代理确认):
          //   · Project model 无 coverUrl 字段(见 lib/domain/models/project.dart),
          //     现阶段首图 URL 来源是 project.resultData.media.first.url(MediaItem.url,
          //     type=='image' 时为图片直链,见 media_item.dart)。
          //   · Phase 5+ 若给 Project 加 coverUrl 字段,改用 project.coverUrl 即可。
          //   · 无图项目(isImage==false)仍走 CoverArt 占位,不接入 CachedNetworkImage。
          //   · 无 Dart/Flutter SDK,无法加 cached_network_image 依赖验证 pubspec.yaml,
          //     故此处仅加文档注释 + 占位逻辑,运行时仍渲染 CoverArt(不破坏现有渲染)。
          CoverArt(pattern: pattern, width: w, height: h),
          // 半透明压暗遮罩,让前景图标 / play 按钮更突出
          Container(color: Colors.black.withAlpha(20)),
          // 前景:video 居中 play 按钮;image / 无 media 居中领域图标
          if (isVideo)
            Center(
              child: Icon(Icons.play_circle_outline,
                  size: 48, color: Colors.white.withAlpha(220)),
            )
          else
            Center(
              child: Icon(domainIcon,
                  size: 36, color: Colors.white.withAlpha(200)),
            ),
          // 图片角标:仅 full 模式有图时右上角小 image_outlined 表示「有图」
          // (compact 56×56 太小,放不下角标)
          if (isImage && !isCompact)
            Positioned(
              top: KkSpacing.sm,
              right: KkSpacing.sm,
              child: Icon(Icons.image_outlined,
                  size: 14, color: Colors.white.withAlpha(180)),
            ),
        ],
      ),
    );
  }

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
        return Icons.work_outline;
    }
  }

  /// 领域 → CoverArt 图案映射(HANDOFF §5 装饰用,5 种图案对应不同领域语义)
  ///
  /// - ai_image   → circles(同心圆,呼应图像生成的扩散感)
  /// - ai_video   → waves(波浪,呼应视频流动)
  /// - web        → grid(网格,呼应网页结构)
  /// - app        → mountains(山峦,呼应 app 层叠架构)
  /// - tool       → grid(网格,工具感)
  /// - opensource → ink(水墨,开源文化感)
  /// - prompt     → waves(波浪,文字流动)
  /// - 兜底        → mountains
  String _domainPattern(String domain) {
    switch (domain) {
      case 'ai_image':
        return 'circles';
      case 'ai_video':
        return 'waves';
      case 'web':
        return 'grid';
      case 'app':
        return 'mountains';
      case 'tool':
        return 'grid';
      case 'opensource':
        return 'ink';
      case 'prompt':
        return 'waves';
      default:
        return 'mountains';
    }
  }
}

// ── 计数小标(无 44pt 要求,纯展示)──
class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _Stat({
    required this.icon,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return Tappable(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value,
                style: KkType.mono.copyWith(fontSize: 11, color: color)),
          ],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: KkType.mono.copyWith(fontSize: 11, color: color)),
      ],
    );
  }
}
