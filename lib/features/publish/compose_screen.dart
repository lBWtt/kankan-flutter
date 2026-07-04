import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/repositories/project_repository.dart';
import '../../router/routes.dart';
import 'widgets/media_picker.dart';

/// 任务⑪ 发动态 compose 屏 — 对应 Post 模型(轻内容)。
///
/// 现状:_showPublishEntrySheet 只注入 onPublishProject,「发动态」死了。
/// 本屏接通:多行文字 + 可选图(复用 MediaPicker)+ 可选话题 + 可选引用项目。
///
/// 发送:校验非空 → 造 Post 加进 postRepository.addPost(对称 addComment)
///   → 关屏 → 新动态出现在发现页推荐流顶部(按 createdAtMs 降序)。
///
/// 参考 publish_screen 的顶栏/输入/媒体结构,不引新依赖,不改 Post 模型。
///
/// 铁律:coral 只给 take(本屏不用 coral);无 emoji;零旁白(hint 只写事实);
/// 触控 ≥44pt;禁 if(artifactType);Post 引用项目按现有 quoteProjectId 字段。
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _contentCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<MediaItem> _media = [];
  final List<String> _tags = [];
  String? _quoteProjectId;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  bool get _canSend {
    final text = _contentCtrl.text.trim();
    return text.isNotEmpty || _media.isNotEmpty;
  }

  void _send() {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty && _media.isEmpty) {
      _toast('写点什么再发');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final post = Post(
      id: 'user_post_$now',
      content: text.isEmpty ? ' ' : text,
      authorId: 'me',
      media: List.of(_media),
      tags: List.of(_tags),
      quoteProjectId: _quoteProjectId,
      likes: 0,
      commentCount: 0,
      createdAtMs: now,
    );
    ref.read(postRepositoryProvider).addPost(post);
    // 让依赖 postRepositoryProvider 的屏(discover 推荐/关注/profile 动态)刷新
    ref.invalidate(postRepositoryProvider);
    _toast('已发送');
    if (context.canPop()) context.pop();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KkColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: KkSpacing.xxl),
                children: [
                  _contentField(),
                  // 媒体区(始终显,MediaPicker 自带「图片」按钮;compose 只要图,
                  // onPicked 过滤非 image。视频按钮点选后静默忽略 — Post 不收视频)
                  const SizedBox(height: KkSpacing.sm),
                  _mediaSection(),
                  const SizedBox(height: KkSpacing.md),
                  _tagsSection(),
                  const SizedBox(height: KkSpacing.md),
                  _quoteSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 顶栏(取消 / 发动态 / 发送)──
  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.sm,
        vertical: KkSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KkColors.divider)),
      ),
      child: Row(
        children: [
          Tappable(
            onTap: () {
              if (context.canPop()) context.pop();
            },
            child: const Padding(
              padding: EdgeInsets.all(KkSpacing.md),
              child: Text('取消', style: KkType.body),
            ),
          ),
          const Spacer(),
          Text('发动态', style: KkType.h3),
          const Spacer(),
          Tappable(
            onTap: _canSend ? _send : null,
            borderRadius: BorderRadius.circular(KkRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KkSpacing.lg,
                vertical: KkSpacing.sm,
              ),
              decoration: BoxDecoration(
                // 空内容置灰(非 coral;发送不是 take)
                color: _canSend ? KkColors.teal : KkColors.t4,
                borderRadius: BorderRadius.circular(KkRadius.pill),
              ),
              child: const Text(
                '发送',
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

  // ── 多行文字(主输入区,hint 零旁白)──
  Widget _contentField() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      child: TextField(
        controller: _contentCtrl,
        maxLines: 8,
        minLines: 4,
        style: KkType.body,
        decoration: InputDecoration(
          hintText: '分享你的灵感、发现、或一个问题',
          hintStyle: KkType.body.copyWith(color: KkColors.t3),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ── 媒体(复用 MediaPicker,只选图;视频走 Project)──
  Widget _mediaSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: MediaPicker(
        current: _media,
        onPicked: (m) {
          if (m.type == 'image') {
            setState(() => _media.add(m));
          }
        },
        onRemoved: (i) => setState(() => _media.removeAt(i)),
      ),
    );
  }

  // ── 话题(回车加,可删)──
  Widget _tagsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tags.isNotEmpty) ...[
            Wrap(
              spacing: KkSpacing.sm,
              runSpacing: KkSpacing.sm,
              children: [
                for (final t in _tags)
                  _TagChip(
                    tag: t,
                    onRemove: () => setState(() => _tags.remove(t)),
                  ),
              ],
            ),
            const SizedBox(height: KkSpacing.sm),
          ],
          TextField(
            controller: _tagCtrl,
            style: KkType.body,
            decoration: InputDecoration(
              hintText: '# 话题(回车加)',
              hintStyle: KkType.body.copyWith(color: KkColors.t3),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              prefixIcon: const Icon(Icons.tag,
                  size: 16, color: KkColors.teal),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
            onSubmitted: (v) {
              final t = v.trim().replaceAll('#', '');
              if (t.isNotEmpty && !_tags.contains(t)) {
                setState(() => _tags.add(t));
              }
              _tagCtrl.clear();
            },
          ),
        ],
      ),
    );
  }

  // ── 引用项目(选一个,内嵌小卡;已选可删)──
  Widget _quoteSection() {
    if (_quoteProjectId != null) {
      final repo = ref.read(projectRepositoryProvider);
      final project = repo.byId(_quoteProjectId!);
      if (project != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
          child: _QuoteProjectCard(
            project: project,
            onRemove: () => setState(() => _quoteProjectId = null),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      child: Tappable(
        onTap: _pickProject,
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
            border: Border.all(color: KkColors.bd, width: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link, size: 16, color: KkColors.teal),
              const SizedBox(width: KkSpacing.xs),
              Text(
                '引用项目',
                style: KkType.bodySm.copyWith(color: KkColors.teal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 选引用项目 — 弹底部 sheet 列出全部项目,点选设 _quoteProjectId。
  void _pickProject() {
    final repo = ref.read(projectRepositoryProvider);
    final projects = repo.all();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KkColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KkRadius.xl)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(KkSpacing.lg),
              child: Row(
                children: [
                  Text('引用项目', style: KkType.h3),
                  const Spacer(),
                  Tappable(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: const Icon(Icons.close,
                        size: 22, color: KkColors.t1),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: KkColors.divider),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: projects.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: KkColors.divider, indent: 72),
                itemBuilder: (ctx, i) {
                  final p = projects[i];
                  return Tappable(
                    onTap: () {
                      setState(() => _quoteProjectId = p.id);
                      Navigator.pop(sheetCtx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KkSpacing.lg,
                        vertical: KkSpacing.md,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.article_outlined,
                              size: 20, color: KkColors.t2),
                          const SizedBox(width: KkSpacing.md),
                          Expanded(
                            child: Text(
                              p.title,
                              style: KkType.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 18, color: KkColors.t3),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 话题 chip(可删)──
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
            child: const Icon(Icons.close, size: 12, color: KkColors.teal),
          ),
        ],
      ),
    );
  }
}

// ── 引用项目小卡(已选态,可删)──
class _QuoteProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onRemove;

  const _QuoteProjectCard({required this.project, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KkSpacing.md),
      decoration: BoxDecoration(
        color: KkColors.bgSubtle,
        borderRadius: BorderRadius.circular(KkRadius.md),
        border: Border.all(color: KkColors.bd),
      ),
      child: Row(
        children: [
          const Icon(Icons.article_outlined, size: 18, color: KkColors.teal),
          const SizedBox(width: KkSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  project.title,
                  style: KkType.bodySm.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@ 引用项目',
                  style: KkType.mono.copyWith(fontSize: 10, color: KkColors.t3),
                ),
              ],
            ),
          ),
          const SizedBox(width: KkSpacing.sm),
          Tappable(
            onTap: () => context.push(KkRoutes.detail(project.id)),
            child: const Icon(Icons.open_in_new,
                size: 16, color: KkColors.t3),
          ),
          const SizedBox(width: KkSpacing.xs),
          Tappable(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: KkColors.t3),
          ),
        ],
      ),
    );
  }
}
