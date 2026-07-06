// 这个文件是干什么的：一个无依赖的令牌保管盒，存当前登录的 access/refresh token。
// 它对应产品里的什么功能：登录后所有需要身份的接口靠它带 Bearer；令牌过期靠它换新。
// 如果它出错了：带不上身份 → 写操作全 401；或旧令牌清不掉 → 换号后仍用旧身份。
//
// 为什么单独一个类而不放进 auth_provider：打破 provider 循环。
//   dio(拦截器要读令牌) → 依赖 tokenStore；authApi → 依赖 dio；authProvider → 依赖 authApi。
//   若拦截器直接读 authProvider 就成环。tokenStore 无依赖，谁都能读写，环断开。
// 令牌只存内存（会话内有效）：web 刷新页面即登出，符合当前「不落持久化」的阶段约定
//   （同 banner blob URL）。Phase 5 接 shared_preferences 落地即可跨刷新。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 令牌保管盒（可变，拦截器直接改字段，不走不可变 state）。
class TokenStore {
  String? accessToken;
  String? refreshToken;

  bool get isLoggedIn => accessToken != null;

  void set({required String access, required String refresh}) {
    accessToken = access;
    refreshToken = refresh;
  }

  void clear() {
    accessToken = null;
    refreshToken = null;
  }
}

/// 全局唯一令牌盒。用法：ref.read(tokenStoreProvider).accessToken
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());
