// 这个文件是干什么的：封装动态接口（流/发/看/删/赞）+ 把后端 PostOut 映射成前端 Post。
// 它对应产品里的什么功能：发现页动态流、发动态、动态详情、动态点赞。
// 如果它出错了：动态流拉不到/发不出/看不到/赞不动（经 AppException 透出）。
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/app_exception.dart';
import '../../core/network/dio_provider.dart';
import '../../domain/models/models.dart';
import '../remote_user_cache.dart';

/// 后端相对媒体 URL（/uploads/xxx）拼后端 origin；绝对 URL 原样（同 project_card_dto）。
String _resolveUrl(String url) {
  if (url.isEmpty || url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  var origin = AppConfig.apiBaseUrl;
  final i = origin.indexOf('/api/');
  if (i > 0) origin = origin.substring(0, i);
  return url.startsWith('/') ? '$origin$url' : '$origin/$url';
}

int _parseMs(dynamic iso) {
  if (iso is String && iso.isNotEmpty) {
    final dt = DateTime.tryParse(iso);
    if (dt != null) return dt.millisecondsSinceEpoch;
  }
  return DateTime.now().millisecondsSinceEpoch;
}

/// 后端 PostOut → 前端 Post。is_liked 收集进 [likedIds]；likes 存「不含我」基数
/// （前端 post_card/detail 显示 likes + isLiked，后端 like_count 含我，减掉我这一票）。
Post _postFromJson(Map<String, dynamic> j, Set<String> likedIds) {
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
  final media = <MediaItem>[];
  final rawMedia = j['media'];
  if (rawMedia is List) {
    for (final m in rawMedia.whereType<Map<dynamic, dynamic>>()) {
      final url = m['url']?.toString();
      if (url != null && url.isNotEmpty) {
        media.add(MediaItem(
          type: m['type']?.toString() == 'video' ? 'video' : 'image',
          url: _resolveUrl(url),
          poster: m['poster'] != null ? _resolveUrl(m['poster'].toString()) : null,
        ));
      }
    }
  }
  final tags = (j['tags'] is List)
      ? (j['tags'] as List).map((e) => e.toString()).toList()
      : const <String>[];
  final rawLikes = j['likes'];
  final total = rawLikes is int ? rawLikes : int.tryParse('$rawLikes') ?? 0;
  final baseLikes = j['is_liked'] == true ? (total - 1).clamp(0, total) : total;
  final cc = j['comment_count'];
  return Post(
    id: id,
    content: (j['content'] ?? '').toString(),
    authorId: authorId,
    media: media,
    tags: tags,
    quoteProjectId: j['quote_project_id']?.toString(),
    likes: baseLikes,
    commentCount: cc is int ? cc : int.tryParse('$cc') ?? 0,
    createdAtMs: _parseMs(j['created_at']),
  );
}

/// 一次动态列表拉取：动态列表 + 我已赞的动态 id 集合。
class PostList {
  final List<Post> posts;
  final Set<String> likedIds;
  const PostList(this.posts, this.likedIds);
}

class PostsApi {
  final Dio _dio;
  PostsApi(this._dio);

  /// GET /posts → 动态流 + 已赞集合。
  Future<PostList> list({int limit = 30}) async {
    try {
      final resp = await _dio.get<dynamic>('/posts', queryParameters: {'page_size': limit});
      return _parseList(resp.data);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// GET /users/{id}/posts → ta 的动态。
  Future<PostList> byUser(String userId, {int limit = 30}) async {
    try {
      final resp = await _dio.get<dynamic>('/users/$userId/posts', queryParameters: {'page_size': limit});
      return _parseList(resp.data);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  PostList _parseList(dynamic data) {
    final raw = data is Map ? (data['items'] ?? const <dynamic>[]) : const <dynamic>[];
    final items = raw is List ? raw : const <dynamic>[];
    final liked = <String>{};
    final posts = items
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => _postFromJson(Map<String, dynamic>.from(m), liked))
        .toList();
    return PostList(posts, liked);
  }

  /// GET /posts/{id} → 动态详情。404→null。
  Future<({Post? post, bool isLiked})> detail(String id) async {
    try {
      final resp = await _dio.get<dynamic>('/posts/$id');
      final data = resp.data;
      if (data is Map) {
        final liked = <String>{};
        final p = _postFromJson(Map<String, dynamic>.from(data), liked);
        return (post: p, isLiked: liked.contains(id));
      }
      return (post: null, isLiked: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return (post: null, isLiked: false);
      throw AppException.fromDio(e);
    }
  }

  /// POST /posts → 发动态。返回真 Post（真 uuid）。
  Future<Post> create(Map<String, dynamic> body) async {
    try {
      final resp = await _dio.post<dynamic>('/posts', data: body);
      final data = resp.data;
      if (data is Map) {
        return _postFromJson(Map<String, dynamic>.from(data), <String>{});
      }
      throw const AppException(code: 'UNKNOWN', message: '发动态返回格式异常');
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// 动态点赞 / 取消。on=true→POST，false→DELETE，幂等。
  Future<void> setLike(String id, bool on) async {
    try {
      if (on) {
        await _dio.post<dynamic>('/posts/$id/like');
      } else {
        await _dio.delete<dynamic>('/posts/$id/like');
      }
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// DELETE /posts/{id}（仅本人）。
  Future<void> delete(String id) async {
    try {
      await _dio.delete<dynamic>('/posts/$id');
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}

final postsApiProvider = Provider<PostsApi>((ref) => PostsApi(ref.watch(dioProvider)));
