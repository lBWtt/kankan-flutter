import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/seed/mock_seed.dart';
import '../../domain/models/models.dart';

/// PostRepository — 动态(轻)的内存 repo。
/// HANDOFF §1:动态不进库、无详情页。这里只提供 feed 查询。
class PostRepository {
  final List<Post> _posts;
  final List<Comment> _comments;

  PostRepository(this._posts, this._comments);

  /// F-36:返回可变副本 `List.of(_posts)`,不再用 `List.unmodifiable`。
  /// 原因:不可变 List 调 `..sort()` 运行时抛 `UnsupportedError`(discover 屏踩过)。
  /// 约定(Codex 规则 C):repository 的 all() 统一返回可变副本,调用方可直接 sort。
  List<Post> all() => List.of(_posts);

  Post? byId(String id) => _posts.where((p) => p.id == id).firstOrNull;

  List<Post> byAuthor(String userId) =>
      _posts.where((p) => p.authorId == userId).toList();

  List<Comment> commentsFor(String hostId) =>
      _comments.where((c) => c.hostId == hostId).toList();

  /// F-4:写入评论到内存 mockComments(与 ProjectRepository 同源)。
  /// CommentThread 发送时调用,detail 底栏 / 卡片 / CommentThread 读同一份,计数一致。
  /// hostType/hostId 透传仅作文档;Comment 自身已带这两个字段。
  void addComment(String hostType, String hostId, Comment comment) {
    _comments.add(comment);
  }
}

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(mockPosts, mockComments);
});
