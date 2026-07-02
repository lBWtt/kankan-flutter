import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/kk_back_button.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/post_repository.dart';
import '../shared/comment_actions_sheet.dart';
import '../shared/comment_thread.dart';
import '../shared/empty_state.dart';

/// 全屏评论壳 — HANDOFF §6.1 CommentThread 的全屏容器。
///
/// 用途:
///   - 详情页「心得 N」标题旁的「查看全部」入口
///   - 动态卡评论图标点击(Phase 3 接线)
///
/// 与 detail / post_detail 内联 CommentThread 的区别:此页给评论独立的全屏空间,
/// AppBar 标题展示「心得 N」(N 真实计数),并提供热/新排序。
///
/// 路由:/comments/:type/:id
///   - type ∈ {'project','post'}
///   - id   = hostId(project.id / post.id)
///
/// 计数铁律(HANDOFF §6.10):N = comments.length,真实数组长度。
/// 零旁白(HANDOFF §3):标题只「心得 N」,空状态只「暂无心得」。
/// 珊瑚橙(HANDOFF §5):本屏不出现(like 情感色在 CommentThread 内部,非本文件)。
enum _SortMode { hot, recent }

class CommentsScreen extends ConsumerStatefulWidget {
  final String hostType;
  final String hostId;

  const CommentsScreen({
    super.key,
    required this.hostType,
    required this.hostId,
  });

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  _SortMode _sortMode = _SortMode.hot;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postRepositoryProvider);
    // repo.commentsFor 已按 hostId 过滤;再按 hostType 收窄(project / post 共享 ID
    // 空间极小,但仍按 HANDOFF §6.1 严格区分)。
    final comments = repo
        .commentsFor(widget.hostId)
        .where((c) => c.hostType == widget.hostType)
        .toList();

    final sorted = _sort(comments);

    return Scaffold(
      backgroundColor: KkColors.bg,
      appBar: AppBar(
        backgroundColor: KkColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const KkBackButton(),
        titleSpacing: 0,
        title: Text(
          '心得 ${sorted.length}',
          style: KkType.h3,
        ),
        actions: [
          if (sorted.isNotEmpty)
            Tappable(
              onTap: _toggleSort,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KkSpacing.lg,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sortMode == _SortMode.hot
                          ? Icons.local_fire_department_outlined
                          : Icons.schedule_outlined,
                      size: 16,
                      color: KkColors.t2,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortMode == _SortMode.hot ? '热' : '新',
                      style: KkType.bodySm.copyWith(
                        color: KkColors.t2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: sorted.isEmpty
          ? const Center(
              child: EmptyState(
                variant: EmptyStateVariant.generic,
                title: '暂无心得',
              ),
            )
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: CommentThread(
                  hostType: widget.hostType,
                  hostId: widget.hostId,
                  initialComments: sorted,
                  showInput: true,
                  showHeader: false,
                  onCommentLongPress: (c) => showCommentActionsSheet(
                    context,
                    comment: c,
                    hostType: widget.hostType,
                    hostId: widget.hostId,
                    isOwn: c.authorId == 'me',
                    onCopy: () {},
                  ),
                ),
              ),
            ),
    );
  }

  void _toggleSort() {
    setState(() {
      _sortMode =
          _sortMode == _SortMode.hot ? _SortMode.recent : _SortMode.hot;
    });
  }

  List<Comment> _sort(List<Comment> src) {
    final list = List<Comment>.of(src);
    switch (_sortMode) {
      case _SortMode.hot:
        // 按点赞数(含回复折算:likes + replies 总点赞)降序,同分按时间新→旧
        list.sort((a, b) {
          final aScore = a.likes + a.replies.fold<int>(0, (s, r) => s + r.likes);
          final bScore = b.likes + b.replies.fold<int>(0, (s, r) => s + r.likes);
          if (aScore != bScore) return bScore.compareTo(aScore);
          return b.createdAtMs.compareTo(a.createdAtMs);
        });
        break;
      case _SortMode.recent:
        list.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
        break;
    }
    return list;
  }
}
