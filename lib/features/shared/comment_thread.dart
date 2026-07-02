import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/time_ago.dart';
import '../../core/utils/parse_count.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/repositories/project_repository.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/project_provider.dart';
import '../../router/routes.dart';
import 'avatar.dart';

/// HANDOFF §6.1 CommentThread — 统一评论组件。
///
/// 四处一致(详情内联 / 评论页 / 动态弹层 / 动态详情):
///   - 评论列表(楼中楼回复)
///   - 点赞(真实计数,可切换)
///   - 回复(楼中楼,可嵌套一层)
///   - 输入框(真发送,加入内存 state)
///
/// 零旁白(HANDOFF §3):输入框 placeholder 只写"写心得"/"回复{名字}",
/// 不写"快来分享你的看法吧"之类引导。
///
/// 计数铁律(HANDOFF §6.10):评论数取 comments.length(真实),
/// 不做 ×N 放大。点赞数取 comment.likes + (用户已点赞?1:0)。
class CommentThread extends ConsumerStatefulWidget {
  /// 宿主类型 'project' | 'post'
  final String hostType;

  /// 宿主 ID
  final String hostId;

  /// 初始评论列表(从 repository 同步读)
  final List<Comment> initialComments;

  /// 是否显示输入框(详情页内联用 true,纯列表展示可 false)
  final bool showInput;

  /// 是否显示标题("心得 N")
  final bool showHeader;

  /// 长按评论回调(可选)。
  ///
  /// 传入则评论长按(avatar + 正文区域)触发,通常接入 showCommentActionsSheet;
  /// 不传则无长按行为(默认 null,不破坏现有调用方)。
  /// 操作行(点赞 / 回复按钮)不包长按,避免长按点赞按钮误触发。
  final void Function(Comment)? onCommentLongPress;

  /// F-4:评论列表变更(发送 / 删除)回调(可选)。
  ///
  /// 详情页内联 CommentThread 传入,触发外层 rebuild → 底栏「心得 N」从同源
  /// commentsFor 重读,与 header 计数实时一致(杜绝"心得 N+1 / 心得 N"分裂)。
  /// 不传则忽略(评论页 / 弹层等不依赖外层计数实时刷新的场景)。
  final VoidCallback? onChanged;

  const CommentThread({
    super.key,
    required this.hostType,
    required this.hostId,
    required this.initialComments,
    this.showInput = true,
    this.showHeader = true,
    this.onCommentLongPress,
    this.onChanged,
  });

  @override
  ConsumerState<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends ConsumerState<CommentThread> {
  late List<Comment> _comments = List.of(widget.initialComments);
  final _ctrl = TextEditingController();
  final _replyCtrl = TextEditingController();
  String? _replyingTo; // 正在回复的评论 ID;null = 顶级评论

  @override
  void dispose() {
    _ctrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KkSpacing.lg,
              vertical: KkSpacing.md,
            ),
            child: Text(
              '心得 ${_comments.length}',
              style: KkType.h3,
            ),
          ),
        if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(KkSpacing.xl),
            child: Text(
              '暂无心得',
              style: KkType.bodySm.copyWith(color: KkColors.t4),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final c in _comments)
            _CommentTile(
              comment: c,
              onLike: () => _toggleLike(c.id),
              onReply: () => _startReply(c.id),
              isLiked: ref.watch(appStateProvider).likedItemIds.contains(c.id),
              onLongPress: widget.onCommentLongPress,
            ),
        if (widget.showInput) ...[
          const SizedBox(height: KkSpacing.sm),
          _inputBar(),
        ],
      ],
    );
  }

  void _startReply(String commentId) {
    setState(() => _replyingTo = commentId);
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyCtrl.clear();
    });
  }

  void _toggleLike(String commentId) {
    ref.read(appStateProvider.notifier).toggleLike(commentId);
  }

  void _submit() {
    final isReply = _replyingTo != null;
    final text = (isReply ? _replyCtrl.text : _ctrl.text).trim();
    if (text.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final newComment = Comment(
      id: 'local_${now}_${_comments.length}',
      hostType: widget.hostType,
      hostId: widget.hostId,
      authorId: 'me',
      content: text,
      likes: 0,
      createdAtMs: now,
    );

    // F-4:写入内存 repository(mockComments,与 detail 底栏 / 卡片 / 全屏评论页同源),
    // 杜绝"评论只存 local state,pop 走再回来丢失 + 计数分裂"。
    // 仅顶级评论写入 repo(楼中楼 replies 是 Comment 内嵌列表,不单独入 mockComments)。
    if (!isReply) {
      if (widget.hostType == 'project') {
        ref
            .read(projectRepositoryProvider)
            .addComment(widget.hostType, widget.hostId, newComment);
      } else {
        ref
            .read(postRepositoryProvider)
            .addComment(widget.hostType, widget.hostId, newComment);
      }
    }

    setState(() {
      if (isReply) {
        // 楼中楼:找到父评论,加入 replies
        _comments = _comments.map((c) {
          if (c.id == _replyingTo) {
            return c.copyWith(replies: [...c.replies, newComment]);
          }
          return c;
        }).toList();
      } else {
        _comments = [..._comments, newComment];
      }
    });

    // F-4:通知外层(如 detail_screen)重建,底栏「心得 N」从同源 commentsFor 重读。
    widget.onChanged?.call();

    if (isReply) {
      _replyCtrl.clear();
      _replyingTo = null;
    } else {
      _ctrl.clear();
    }
    FocusScope.of(context).unfocus();
  }

  Widget _inputBar() {
    final isReply = _replyingTo != null;
    final ctrl = isReply ? _replyCtrl : _ctrl;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: KkColors.bgCard,
        border: Border(top: BorderSide(color: KkColors.bd)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isReply)
            Padding(
              padding: const EdgeInsets.only(bottom: KkSpacing.sm),
              child: Row(
                children: [
                  Text(
                    '回复',
                    style: KkType.bodySm.copyWith(color: KkColors.t3),
                  ),
                  const SizedBox(width: KkSpacing.xs),
                  Tappable(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close,
                        size: 14, color: KkColors.t3),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  minLines: 1,
                  maxLines: 4,
                  style: KkType.body,
                  decoration: InputDecoration(
                    hintText: isReply ? '回复…' : '写心得',
                    hintStyle: KkType.body.copyWith(color: KkColors.t4),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: KkSpacing.md,
                      vertical: KkSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KkRadius.pill),
                      borderSide: const BorderSide(color: KkColors.bd),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KkRadius.pill),
                      borderSide: const BorderSide(color: KkColors.teal),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: KkSpacing.sm),
              Tappable(
                onTap: _submit,
                borderRadius: BorderRadius.circular(KkRadius.pill),
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
                    '发送',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'NotoSerifSC',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 评论单元(含楼中楼)──
class _CommentTile extends ConsumerWidget {
  final Comment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final bool isLiked;

  /// 长按评论回调(可空)—— CommentThread 转发 onCommentLongPress。
  /// 触发区域:avatar + 正文(操作行不包,避免长按点赞 / 回复按钮误触发)。
  final void Function(Comment)? onLongPress;

  const _CommentTile({
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.isLiked,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userByIdProvider(comment.authorId));
    final likeCount = comment.likes + (isLiked ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KkSpacing.lg,
        vertical: KkSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: onLongPress == null
                ? null
                : () => onLongPress!(comment),
            behavior: HitTestBehavior.opaque,
            child: TappableAvatar(
              userId: comment.authorId,
              user: author,
              size: 32,
              onTap: () => context.push(KkRoutes.profile(comment.authorId)),
            ),
          ),
          const SizedBox(width: KkSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onLongPress: onLongPress == null
                      ? null
                      : () => onLongPress!(comment),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            author?.name ?? comment.authorId,
                            style: KkType.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                              color: KkColors.t1,
                            ),
                          ),
                          const SizedBox(width: KkSpacing.sm),
                          Text(
                            timeAgo(comment.createdAtMs),
                            style: KkType.mono.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(comment.content, style: KkType.body),
                    ],
                  ),
                ),
                const SizedBox(height: KkSpacing.sm),
                // 操作行:点赞 / 回复(零旁白,只图标 + 数字)
                // 不包长按,避免长按点赞按钮触发评论操作 sheet
                Row(
                  children: [
                    Tappable(
                      onTap: onLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 14,
                            color: isLiked ? KkColors.coral : KkColors.t3,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatCount(likeCount),
                            style: KkType.mono.copyWith(
                              fontSize: 11,
                              color: isLiked ? KkColors.coral : KkColors.t3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KkSpacing.lg),
                    Tappable(
                      onTap: onReply,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 14, color: KkColors.t3),
                          const SizedBox(width: 4),
                          Text(
                            '回复',
                            style: KkType.mono.copyWith(
                                fontSize: 11, color: KkColors.t3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 楼中楼
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(height: KkSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(KkSpacing.sm),
                    decoration: BoxDecoration(
                      color: KkColors.bgSubtle,
                      borderRadius: BorderRadius.circular(KkRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final r in comment.replies) ...[
                          _ReplyTile(reply: r),
                          if (r != comment.replies.last)
                            const SizedBox(height: KkSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyTile extends ConsumerWidget {
  final Comment reply;

  const _ReplyTile({required this.reply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userByIdProvider(reply.authorId));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KkAvatar(userId: reply.authorId, user: author, size: 20),
        const SizedBox(width: KkSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                author?.name ?? reply.authorId,
                style: KkType.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: KkColors.t1,
                ),
              ),
              const SizedBox(height: 2),
              Text(reply.content, style: KkType.bodySm),
            ],
          ),
        ),
      ],
    );
  }
}
