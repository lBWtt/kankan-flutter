// 这个文件是干什么的：封装用户「读」接口 —— GET /me 计数、GET /users/{id} 公开资料、
// GET /users/{id}/followers|following 列表。
// 它对应产品里的什么功能：me / profile 头部的关注/粉丝数 + 关注/粉丝列表屏（真计数 + 真列表）。
// 如果它出错了：计数显旧值或 0、列表显错误态（调用方用 RemoteError 可重试）。
//
// 边界：关注「写」通路（POST/DELETE /users/{id}/follow）在 interactions_api.dart，
// 这里只做读显示。关注按钮选中态走 appState.followedUserIds（Claude 已双轨），本文件不碰。
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/app_exception.dart';
import '../../core/network/dio_provider.dart';
import '../../domain/models/models.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../remote_user_cache.dart';

/// 远程用户公开资料（GET /users/{id} 返回字段子集，前端读显示用）。
///
/// 比 KkUser 多 published_project_count / following_count / follower_count /
/// is_followed_by_me——这些是后端聚合的「他人视角」字段，前端 KkUser 不存。
class UserPublic {
  final String id;
  final String nickname;
  final String? avatarUrl;
  final String? bio;
  final int projectCount;
  final int followingCount;
  final int followerCount;
  final bool isFollowedByMe;

  const UserPublic({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.bio,
    this.projectCount = 0,
    this.followingCount = 0,
    this.followerCount = 0,
    this.isFollowedByMe = false,
  });
}

/// 「我的」关注/粉丝计数（GET /me 取 following_count + follower_count 两字段）。
class MyCounts {
  final int following;
  final int follower;
  const MyCounts(this.following, this.follower);
}

class UsersApi {
  final Dio _dio;
  UsersApi(this._dio);

  /// GET /me → 我的关注/粉丝计数。需登录（后端 auth_required）。
  /// 调用方（myCountsProvider）在未登录 / 非 useRemote 时不调本方法。
  Future<MyCounts> myCounts() async {
    try {
      final resp = await _dio.get<dynamic>('/me');
      final data = resp.data;
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        return MyCounts(
          _readInt(m['following_count']),
          _readInt(m['follower_count']),
        );
      }
      throw const AppException(code: 'UNKNOWN', message: '/me 返回格式异常');
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// GET /users/{id} → 远程用户公开资料（昵称/头像/简介/计数/是否已关注）。
  /// 游客可读。顺带 cacheRemoteUser 让 userByIdProvider 兜底也能查到这位远程用户。
  Future<UserPublic> userPublic(String id) async {
    try {
      final resp = await _dio.get<dynamic>('/users/$id');
      final data = resp.data;
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final uid = m['id'].toString();
        final nick = (m['nickname'] ?? '').toString();
        // 顺带缓存：profile_screen 头像、follows_screen 行头像都能用 userByIdProvider 查到。
        cacheRemoteUser(KkUser(
          id: uid,
          name: nick.isNotEmpty ? nick : uid,
          avatar: m['avatar_url'] as String?,
          bio: m['bio'] as String?,
        ));
        return UserPublic(
          id: uid,
          nickname: nick,
          avatarUrl: m['avatar_url'] as String?,
          bio: m['bio'] as String?,
          projectCount: _readInt(m['published_project_count']),
          followingCount: _readInt(m['following_count']),
          followerCount: _readInt(m['follower_count']),
          isFollowedByMe: m['is_followed_by_me'] == true,
        );
      }
      throw const AppException(code: 'UNKNOWN', message: '用户资料格式异常');
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// GET /users/{id}/followers → 粉丝列表（UserBrief → KkUser，顺带缓存）。
  /// 后端返回 { items:[UserBrief], next_cursor, has_more } 或裸数组，两种都兼容。
  Future<List<KkUser>> followers(String id) async {
    try {
      final resp = await _dio.get<dynamic>('/users/$id/followers');
      return _parseUserList(resp.data);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// GET /users/{id}/following → 关注列表（UserBrief → KkUser，顺带缓存）。
  Future<List<KkUser>> following(String id) async {
    try {
      final resp = await _dio.get<dynamic>('/users/$id/following');
      return _parseUserList(resp.data);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// 解析 { items:[UserBrief], next_cursor, has_more } 或裸数组 → List<KkUser>。
  /// UserBrief = { id, nickname, avatar_url, role } → KkUser(id/name=nickname/avatar=avatar_url)。
  /// role 暂不存（前端 KkUser 无此字段，Phase 5 加角色徽章时再扩）。
  List<KkUser> _parseUserList(dynamic data) {
    final raw = data is Map
        ? (data['items'] ?? const <dynamic>[])
        : (data ?? const <dynamic>[]);
    final items = raw is List ? raw : const <dynamic>[];
    final out = <KkUser>[];
    for (final m in items.whereType<Map<dynamic, dynamic>>()) {
      final j = Map<String, dynamic>.from(m);
      final id = j['id'].toString();
      if (id.isEmpty) continue;
      final nick = (j['nickname'] ?? '').toString();
      final user = KkUser(
        id: id,
        name: nick.isNotEmpty ? nick : id,
        avatar: j['avatar_url'] as String?,
      );
      cacheRemoteUser(user);
      out.add(user);
    }
    return out;
  }

  int _readInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

final usersApiProvider = Provider<UsersApi>(
  (ref) => UsersApi(ref.watch(dioProvider)),
);

/// 我的关注/粉丝计数（GET /me）。
/// 仅登录 + useRemote 时拉真数据，否则返回 null（调用方走 mock 兜底）。
/// watch followedUserIds.length：关注/取关后自动刷新我的 following_count
/// （本地状态变 → provider 重建 → 重拉 /me）。
final myCountsProvider = FutureProvider<MyCounts?>((ref) async {
  ref.watch(appStateProvider.select((s) => s.followedUserIds.length));
  final auth = ref.watch(authProvider);
  if (!auth.isLoggedIn || !AppConfig.useRemote) return null;
  return ref.watch(usersApiProvider).myCounts();
});

/// 远程用户公开资料（GET /users/{id}）。
/// 仅 useRemote + 真后端 id（UUID）时拉，否则返回 null（调用方走 mock）。
/// watch followedUserIds.contains(id)：我关注/取关该用户 → ta 的 follower_count
/// + is_followed_by_me 变，provider 重建重拉。
final remoteUserPublicProvider =
    FutureProvider.autoDispose.family<UserPublic?, String>((ref, id) async {
  ref.watch(appStateProvider.select((s) => s.followedUserIds.contains(id)));
  if (!AppConfig.useRemote) return null;
  return ref.watch(usersApiProvider).userPublic(id);
});

/// 远程用户粉丝列表（GET /users/{id}/followers）。
/// watch followedUserIds.contains(id)：我关注/取关该用户 → 我从 ta 的粉丝列表
/// 加入/退出，provider 重建重拉。
final remoteFollowersProvider =
    FutureProvider.autoDispose.family<List<KkUser>, String>((ref, id) async {
  ref.watch(appStateProvider.select((s) => s.followedUserIds.contains(id)));
  return ref.watch(usersApiProvider).followers(id);
});

/// 远程用户关注列表（GET /users/{id}/following）。
/// 若 id 是当前登录用户，watch followedUserIds.length：我关注/取关别人 → 我的
/// following 列表变，provider 重建重拉。他人 following 列表与本地状态无关，不订阅。
final remoteFollowingProvider =
    FutureProvider.autoDispose.family<List<KkUser>, String>((ref, id) async {
  final myId = ref.watch(authProvider).currentUser?.id;
  if (myId != null && myId == id) {
    ref.watch(appStateProvider.select((s) => s.followedUserIds.length));
  }
  return ref.watch(usersApiProvider).following(id);
});
