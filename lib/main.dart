import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/prefs.dart';

/// 入口。
///
/// HANDOFF §0:看看 = "看 AI 做出的有意思的东西 + 心得"的目的地。
/// Phase 1:ProviderScope 包根 → KankanApp(MaterialApp.router)。
///
/// 会话持久化:main 里先 await SharedPreferences,再 override 注入 prefsProvider,
/// 这样 tokenStore/auth 能同步读回登录令牌——web 刷新页面不掉登录。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const KankanApp(),
    ),
  );
}
