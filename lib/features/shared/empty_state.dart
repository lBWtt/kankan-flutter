import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/kk_strings.dart';

/// 空状态组件 — HANDOFF §5:无 emoji,用图标 + 文案。
///
/// 6 变体(B3 补 followers/search):
///   - generic   通用("暂无内容")
///   - feed      流空("还没有动态"/"关注的人发的动态在这里")
///   - saved     收藏空("还没收藏"/"收藏的项目在这里")
///   - takeaway  拿走空("还没存过素材"/"存下的素材在这里找回")
///   - followers 关注空("还没关注"/"关注的人在这里")
///   - search    搜索空("没有结果"/"换个词试试")
///
/// 零旁白(HANDOFF §3):只陈述事实,不写"快去发现更多吧"之类引导。
///
/// P2-i18n:文案接 [KkStrings](2024-11 全量迁移)。组件从 StatelessWidget
/// 改为 ConsumerWidget 以 reactive 拿到当前 locale 的字符串。
class EmptyState extends ConsumerWidget {
  final EmptyStateVariant variant;
  final String? title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.variant,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(kkStringsProvider);
    final meta = _meta(s);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.xxl,
        vertical: KkSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            meta.icon,
            size: 48,
            color: KkColors.t4,
          ),
          const SizedBox(height: KkSpacing.md),
          Text(
            title ?? meta.title,
            style: KkType.body.copyWith(color: KkColors.t3),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null || meta.subtitle != null) ...[
            const SizedBox(height: KkSpacing.xs),
            Text(
              subtitle ?? meta.subtitle!,
              style: KkType.bodySm.copyWith(color: KkColors.t4),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  _EmptyMeta _meta(KkStrings s) {
    switch (variant) {
      case EmptyStateVariant.generic:
        return _EmptyMeta(
          icon: Icons.inbox_outlined,
          title: s.emptyGeneric,
          subtitle: null,
        );
      case EmptyStateVariant.feed:
        return _EmptyMeta(
          icon: Icons.dynamic_feed_outlined,
          title: s.emptyFeed,
          // TODO(i18n): 迁移到 KkStrings — "关注的人发的动态在这里"
          subtitle: '关注的人发的动态在这里',
        );
      case EmptyStateVariant.saved:
        return _EmptyMeta(
          icon: Icons.bookmark_border_outlined,
          title: s.emptySaved,
          // TODO(i18n): 迁移到 KkStrings — "收藏的项目在这里"
          subtitle: '收藏的项目在这里',
        );
      case EmptyStateVariant.takeaway:
        return _EmptyMeta(
          icon: Icons.download_outlined,
          title: s.emptyTakeaway,
          // TODO(i18n): 迁移到 KkStrings — "存下的素材在这里找回"
          subtitle: '存下的素材在这里找回',
        );
      case EmptyStateVariant.followers:
        return _EmptyMeta(
          icon: Icons.people_outline,
          title: s.emptyFollowers,
          // TODO(i18n): 迁移到 KkStrings — "关注的人在这里"
          subtitle: '关注的人在这里',
        );
      case EmptyStateVariant.search:
        return _EmptyMeta(
          icon: Icons.search_off,
          title: s.emptySearch,
          // TODO(i18n): 迁移到 KkStrings — "换个词试试"
          subtitle: '换个词试试',
        );
    }
  }
}

enum EmptyStateVariant { generic, feed, saved, takeaway, followers, search }

class _EmptyMeta {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _EmptyMeta({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
