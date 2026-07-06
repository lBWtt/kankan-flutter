// 这个文件是干什么的：提供全局唯一的 SharedPreferences 实例 + 持久化用的 key 常量。
// 它对应产品里的什么功能：登录令牌/用户的本地持久化（web 刷新页面不掉登录）。
// 如果它出错了：prefsProvider 没在 main override → 读它直接抛（提醒接线漏了）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局 SharedPreferences。main() 里 `await SharedPreferences.getInstance()` 后
/// 用 override 注入（这样各 provider 可同步读，不用到处 await）。
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider 必须在 main() 里 override 注入'),
);

/// 持久化 key（集中定义，避免散落拼错）。
class PrefsKeys {
  PrefsKeys._();

  /// access token（Bearer，2h 有效）
  static const accessToken = 'auth_access_token';

  /// refresh token（30d，用于静默换新）
  static const refreshToken = 'auth_refresh_token';

  /// 当前登录用户的最小 JSON（{id,name,avatar,bio}），恢复登录态 UI 用
  static const authUser = 'auth_user';
}
