// 这个文件是干什么的：管当前登录态——是否已登录、当前用户、发码/登录/登出动作。
// 它对应产品里的什么功能：登录页驱动它；「我的」页据它显示真实昵称或「点击登录」。
// 如果它出错了：登录后 UI 不刷新，或登出后仍显示旧身份。
//
// 令牌本身存在 tokenStore（无依赖、拦截器直接读）；这里只管 UI 关心的用户对象与状态。
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/auth_api.dart';
import '../data/token_store.dart';
import '../domain/models/models.dart';

/// 登录态数据。currentUser 非空 = 已登录（真后端账号）。
@immutable
class AuthState {
  /// 当前登录用户（真后端账号）；null = 未登录（游客）。
  final KkUser? currentUser;

  /// 本次登录是否为新注册（前端据此可进兴趣采集 onboarding，MVP 暂只提示）。
  final bool isNewUser;

  const AuthState({this.currentUser, this.isNewUser = false});

  bool get isLoggedIn => currentUser != null;

  AuthState copyWith({KkUser? currentUser, bool? isNewUser, bool clearUser = false}) =>
      AuthState(
        currentUser: clearUser ? null : (currentUser ?? this.currentUser),
        isNewUser: isNewUser ?? this.isNewUser,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  /// 发送验证码。异常（频控 429 等）原样抛给 UI 提示。
  Future<void> sendCode(String identifier) =>
      ref.read(authApiProvider).sendCode(identifier);

  /// 验证码登录：成功后把令牌写进 tokenStore、当前用户写进 state。
  /// 失败（验证码错等）抛异常给 UI。
  Future<void> login(String identifier, String code) async {
    final result = await ref.read(authApiProvider).login(identifier, code);
    ref.read(tokenStoreProvider).set(
          access: result.accessToken,
          refresh: result.refreshToken,
        );
    state = AuthState(currentUser: result.user, isNewUser: result.isNewUser);
  }

  /// 登出：清令牌 + 清用户。回到游客态。
  void logout() {
    ref.read(tokenStoreProvider).clear();
    state = const AuthState();
  }
}

/// 全局登录态。用法：ref.watch(authProvider).isLoggedIn
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
