import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/noise_background.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/project_repository.dart';
import '../../providers/publish_provider.dart';
import 'widgets/add_takeaway_sheet.dart';
import 'widgets/media_picker.dart';
import 'widgets/publish_preview.dart';

/// 项目发布屏 — HANDOFF §4:放什么系统猜什么,不让用户选类型。
///
/// 用户只管放东西,类型与拿走方式系统在后台判定:
///   - 传图/视频 → 成果(media),视频自动排前,首张作封面
///   - 写介绍 → 作者的话
///   - 贴文本 → take(复制) / 传文件 → take(下载) / 放链接 → 当场识别 GitHub/App Store/网址 → go
///   - "+"点开底部 sheet 三选一,"再加一样"可重复 → 多个拿走物
///   - 工作流链接(可选) → how(Phase 3 接)
///   - 全程零旁白、不选类型
///
/// 产出结构 = 详情端可组合渲染所读的 {media(视频优先), actions:[take/go/how]}
class PublishScreen extends ConsumerWidget {
  const PublishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(publishDraftProvider);

    return Scaffold(
      backgroundColor: KkColors.bg,
      body: NoiseBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 顶栏(发布/取消)
              _topBar(context, ref),
              // 表单
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: KkSpacing.xxl),
                  children: [
                    // 标题
                    _titleField(ref),
                    // 一句话价值
                    _summaryField(ref),
                    // 成果区:传图/视频
                    _mediaSection(context, ref, draft.media),
                    // 拿走物/actions(已加的列表 + "+" 按钮)
                    _actionsSection(context, ref, draft.actions),
                    // 作者的话
                    _authorNoteField(ref),
                    // 标签
                    _tagsSection(ref, draft.tags),
                    const SizedBox(height: KkSpacing.lg),
                    // 实时预览(复用 detail 渲染器)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: KkSpacing.lg),
                      child: PublishPreview(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 顶栏 ──
  Widget _topBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.sm,
        vertical: KkSpacing.sm,
      ),
      child: Row(
        children: [
          Tappable(
            onTap: () {
              ref.read(publishDraftProvider.notifier).reset();
              if (context.canPop()) context.pop();
            },
            child: const Padding(
              padding: EdgeInsets.all(KkSpacing.md),
              child: Text('取消', style: KkType.body),
            ),
          ),
          const Spacer(),
          Text('发作品', style: KkType.h3),
          const Spacer(),
          Tappable(
            onTap: () => _publish(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KkSpacing.lg,
                vertical: KkSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: KkColors.teal,
                borderRadius: BorderRadius.circular(KkRadius.pill),
              ),
              child: const Text(
                '发布',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'NotoSerifSC',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 标题 ──
  Widget _titleField(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: TextField(
        onChanged: ref.read(publishDraftProvider.notifier).setTitle,
        style: KkType.h2,
        decoration: const InputDecoration(
          hintText: '标题',
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ── 一句话价值 ──
  Widget _summaryField(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: TextField(
        onChanged: ref.read(publishDraftProvider.notifier).setSummary,
        style: KkType.body.copyWith(color: KkColors.t2),
        decoration: const InputDecoration(
          hintText: '一句话说价值',
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ── 成果区:传图/视频 ──
  Widget _mediaSection(
    BuildContext context,
    WidgetRef ref,
    List<MediaItem> media,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaPicker(
            current: media,
            onPicked: ref.read(publishDraftProvider.notifier).addMedia,
            onRemoved: ref.read(publishDraftProvider.notifier).removeMediaAt,
          ),
        ],
      ),
    );
  }

  // ── 拿走物/actions ──
  Widget _actionsSection(
    BuildContext context,
    WidgetRef ref,
    List<ActionItem> actions,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 已加的拿走物列表
          for (var i = 0; i < actions.length; i++)
            _ActionChip(
              action: actions[i],
              onRemove: () =>
                  ref.read(publishDraftProvider.notifier).removeActionAt(i),
            ),
          // "+" 按钮(三选一 sheet)
          Tappable(
            onTap: () => _showAddSheet(context, ref),
            borderRadius: BorderRadius.circular(KkRadius.md),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: KkSpacing.md,
                horizontal: KkSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: KkColors.bgSubtle,
                borderRadius: BorderRadius.circular(KkRadius.md),
                border: Border.all(
                  color: KkColors.bd,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 18, color: KkColors.teal),
                  const SizedBox(width: KkSpacing.xs),
                  Text(
                    '加拿走物',
                    style: KkType.bodySm.copyWith(color: KkColors.teal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 作者的话 ──
  Widget _authorNoteField(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      child: TextField(
        onChanged: ref.read(publishDraftProvider.notifier).setAuthorNote,
        maxLines: 3,
        minLines: 1,
        style: KkType.body,
        decoration: const InputDecoration(
          hintText: '作者的话',
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ── 标签 ──
  Widget _tagsSection(WidgetRef ref, List<String> tags) {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 已加标签
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: KkSpacing.sm,
              runSpacing: KkSpacing.sm,
              children: [
                for (final t in tags)
                  _TagChip(
                    tag: t,
                    onRemove: () =>
                        ref.read(publishDraftProvider.notifier).removeTag(t),
                  ),
              ],
            ),
            const SizedBox(height: KkSpacing.sm),
          ],
          // 输入框(回车加 tag)
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: '# 话题(回车加)',
              border: InputBorder.none,
              isDense: true,
            ),
            onSubmitted: (v) {
              final t = v.trim().replaceAll('#', '');
              if (t.isNotEmpty) {
                ref.read(publishDraftProvider.notifier).addTag(t);
                ctrl.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTakeawaySheet(
        onAdded: ref.read(publishDraftProvider.notifier).addAction,
      ),
    );
  }

  void _publish(BuildContext context, WidgetRef ref) {
    final draft = ref.read(publishDraftProvider);
    // 简单校验:至少有标题 + 一个内容(media 或 actions 或 text)
    if (draft.title.isEmpty) {
      _toast(context, '请填标题');
      return;
    }
    if (draft.media.isEmpty &&
        draft.actions.isEmpty &&
        (draft.text == null || draft.text!.isEmpty)) {
      _toast(context, '至少放一样东西');
      return;
    }
    // 构建 Project(产出结构 = 详情端所读的 {resultData, actions})
    final project = draft.toProject(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      authorId: 'me',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    // F-2:写入内存 repository(mockProjects 共享引用,列表头部)。
    // 发布后 discover / kankan / profile 重新读取即可见。内存级,不碰 Drift。
    ref.read(projectRepositoryProvider).add(project);
    // 让依赖 projectRepositoryProvider 的屏(kankan / me / profile)刷新看到新项目。
    ref.invalidate(projectRepositoryProvider);
    _toast(context, '已发布: ${project.title}');
    ref.read(publishDraftProvider.notifier).reset();
    if (context.canPop()) context.pop();
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
  }
}

// ── 小组件 ──
class _ActionChip extends StatelessWidget {
  final ActionItem action;
  final VoidCallback onRemove;

  const _ActionChip({required this.action, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = _meta(action);
    return Container(
      margin: const EdgeInsets.only(bottom: KkSpacing.sm),
      padding: const EdgeInsets.symmetric(
        vertical: KkSpacing.sm,
        horizontal: KkSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(KkRadius.sm),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: KkSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: KkType.bodySm.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tappable(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: color),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _meta(ActionItem a) {
    return switch (a) {
      TakeAction(:final takeKind, :final label) => (
          takeKind == 'copy' ? Icons.copy_outlined : Icons.download_outlined,
          label ?? (takeKind == 'copy' ? '复制' : '下载'),
          KkColors.coral, // 珊瑚橙只给 take
        ),
      GoAction(:final url, :final label) => (
          Icons.arrow_outward,
          label ?? url,
          KkColors.teal,
        ),
      HowAction(:final label) => (
          Icons.account_tree_outlined,
          label ?? '工作流',
          KkColors.teal,
        ),
    };
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;

  const _TagChip({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: KkColors.mint,
        borderRadius: BorderRadius.circular(KkRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tag',
            style: KkType.bodySm.copyWith(color: KkColors.teal),
          ),
          const SizedBox(width: KkSpacing.xs),
          Tappable(
            onTap: onRemove,
            child: Icon(Icons.close, size: 12, color: KkColors.teal),
          ),
        ],
      ),
    );
  }
}
