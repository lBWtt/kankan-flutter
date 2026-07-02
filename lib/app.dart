import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

/// 根 Widget。
///
/// MaterialApp.router + go_router。主题只 light(HANDOFF §5:深色模式 defer)。
/// debugShowCheckedModeBanner 关掉(原型不显示 debug 角标)。
///
/// Phase 4:启用 Hero 共享元素,配合 project_card 的 Hero tag
/// (`'project-cover-{project.id}'`)实现 cover 飞入详情页。
/// `MaterialHeroController` 是 Flutter material 库自带(Flutter 3.16+),
/// 无需额外 import。app_router 已用 CustomTransitionPage 透传 Hero widget,
/// Hero 飞行由本 controller 协调。
class KankanApp extends ConsumerWidget {
  const KankanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: '看看',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
