// 这个文件是干什么的：封装评论接口（列/发/删/赞）+ 把后端 CommentOut 映射成前端 Comment。
// 它对应产品里的什么功能：项目/动态详情的评论区（真读写）。
// 如果它出错了：评论区拉不到/发不出/删不掉/赞不动（会经 AppException 透出）。
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/app_exception.dart';
import '../../core/network/dio_provider.dart';
import '../../domain/models/models.dart';
import '../remote_user_cache.dart';

/// 后端 CommentOut → 前端 Comment（递归楼中楼）。is_liked 收集进 [likedIds]（前端 Comment 无此字段）。
Comment _commentFromJson(Map<String, dynamic> j, Set<String> likedIds) {
  final id = j['id'].toString();
  if (j['is_liked'] == true) likedIds.add(id);
  final author = j['author'];
  String authorId = '';
  if (author is Map) {
    authorId = author['id']?.toString() ?? '';
    if (authorId.isNotEmpty) {
      final nick = author['nickname']?.toString();
      cacheRemoteUser(KkUser(
        id: authorId,
        name: (nick != null && nick.isNotEmpty) ? nick : authorId,
        avatar: author['avatar_url']?.toString(),
      ));
    }
  }
  final rawReplies = j['replies'];
  final replies = <Comment>[];
  if (rawReplies is List) {
    for (final r in rawReplies.whereType<Map<dynamic, dynamic>>()) {
      replies.add(_commentFromJson(Map<String, dynamic>.from(r), likedIds));
    }
  }
  final rawLikes = j['likes'];
  final total = rawLikes is int ? rawLikes : int.tryParse('$rawLikes') ?? 0;
  // 前端 _CommentTile 显示 likes + (isLiked?1:0)——所以这里存「不含我」的基数，
  // 后端 like_count 是总数(含我)，减掉我这一票，让前端 +isLiked 重建出正确总数。
  final baseLikes = j['is_liked'] == true ? (total - 1).clamp(0, total) : total;
  final created = j['created_at'];
  return Comment(
    id: id,
    hostType: (j['host_type'] ?? 'project').toString(),
    hostId: (j['host_id'] ?? '').toString(),
    authorId: authorId,
    content: (j['content'] ?? '').toString(),
    likes: baseLikes,
    replies: replies,
    createdAtMs: _parseMs(created),
  );
}

int _parseMs(dynamic iso) {
  if (iso is String && iso.isNotEmpty) {
    final dt = DateTime.tryParse(iso);
    if (dt != null) return dt.millisecondsSinceEpoch;
  }
  return DateTime.now().millisecondsSinceEpoch;
}

/// 一次评论列表拉取的结果：评论树 + 当前用户已赞的评论 id 集合。
class CommentList {
  final List<Comment> comments;
  final Set<String> likedIds;
  const CommentList(this.comments, this.likedIds);
}

class CommentsApi {
  final Dio _dio;
  CommentsApi(this._dio);

  /// GET /comments?host_type=&host_id= → 顶级评论（含楼中楼）+ 已赞集合。
  Future<CommentList> list(String hostType, String hostId) async {
    try {
      final resp = await _dio.get<dynamic>('/comments', queryParameters: {
        'host_type': hostType,
        'host_id': hostId,
      });
      final data = resp.data;
      final raw = data is Map ? (data['items'] ?? const <dynamic>[]) : const <dynamic>[];
      final items = raw is List ? raw : const <dynamic>[];
      final liked = <String>{};
      final comments = items
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => _commentFromJson(Map<String, dynamic>.from(m), liked))
          .toList();
      return CommentList(comments, liked);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// POST /comments → 发评论/回复。parentId 非空=回复顶级评论。
  Future<void> create(String hostType, String hostId, String content, {String? parentId}) async {
    try {
      await _dio.post<dynamic>('/comments', data: {
        'host_type': hostType,
        'host_id': hostId,
        'content': content,
        if (parentId != null) 'parent_comment_id': parentId,
      });
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// DELETE /comments/{id}（仅本人）。
  Future<void> delete(String id) async {
    try {
      await _dio.delete<dynamic>('/comments/$id');
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// 评论点赞 / 取消。on=true→POST，false→DELETE，幂等。
  Future<void> setLike(String id, bool on) async {
    try {
      if (on) {
        await _dio.post<dynamic>('/comments/$id/like');
      } else {
        await _dio.delete<dynamic>('/comments/$id/like');
      }
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}

final commentsApiProvider = Provider<CommentsApi>(
  (ref) => CommentsApi(ref.watch(dioProvider)),
);
