import 'package:flutter/material.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/tappable.dart';

/// 发布入口 sheet。FAB 点击弹出。
///
/// HANDOFF §1 核心结构:动态/项目二分(不可动摇)。
///   - 发动态(轻):文字 + 可选图 + 话题 + 引用项目。不进库、无详情页。
///   - 发作品(项目)(重):有成果 + 拿走物。进库、有详情页。
///
/// Phase 2:"发作品"接真实 publish 屏(push /publish)。
/// "发动态"Phase 3 接 compose 屏。
///
/// HANDOFF §3 零旁白:只有两行入口 + 图标 + 标题 + 一句话价值(不是教学说明)。
class PublishEntrySheet extends StatelessWidget {
  /// 选"发作品"回调(router 注入,跳 /publish)
  final VoidCallback? onPublishProject;

  /// 选"发动态"回调(Phase 3 接 compose)
  final VoidCallback? onPublishPost;

  const PublishEntrySheet({
    super.key,
    this.onPublishProject,
    this.onPublishPost,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.xl,
        vertical: KkSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: KkSpacing.lg),
              decoration: BoxDecoration(
                color: KkColors.t4,
                borderRadius: BorderRadius.circular(KkRadius.pill),
              ),
            ),
          ),
          Text('发布', style: KkType.h2),
          const SizedBox(height: KkSpacing.lg),
          _entry(
            context,
            icon: Icons.edit_outlined,
            title: '发动态',
            hint: '文字 + 图 + 话题 + 引用',
            onTap: () {
              Navigator.pop(context);
              onPublishPost?.call();
            },
          ),
          _entry(
            context,
            icon: Icons.work_outline,
            title: '发作品(项目)',
            hint: '成果 + 拿走物',
            onTap: () {
              // sheet 先不关,让 router 的回调决定(回调里会 pop)
              onPublishProject?.call();
            },
          ),
          const SizedBox(height: KkSpacing.xl),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KkRadius.md),
      padding: const EdgeInsets.symmetric(
        vertical: KkSpacing.md,
        horizontal: KkSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: KkColors.teal, size: 24),
          const SizedBox(width: KkSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: KkType.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(hint, style: KkType.bodySm),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: KkColors.t3, size: 20),
        ],
      ),
    );
  }
}
