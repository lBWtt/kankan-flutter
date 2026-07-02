import 'package:flutter/material.dart';

import 'kk_colors.dart';
import 'tokens.dart';

/// 主题。HANDOFF §5:暂不做深色模式,只 light。
///
/// 不在 ThemeData 层覆写 cardTheme / buttonTheme 等(CardThemeData 在
/// 不同 Flutter 版本 API 漂移)。卡片/按钮样式 Phase 2 起用专门 KkCard /
/// KkButton 组件管控,避免 ThemeData 兼容性坑。
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: KkColors.bg,
      canvasColor: KkColors.bg,
      // HANDOFF §5:珊瑚橙只给 take(拿到手)动作,别处禁用。
      // 因此不设 secondary / error = coral(会泄漏到 Material 语义槽)。
      // secondary / error 留 Material 默认;coral 只在 KkColors.coral 定义处待命,
      // Phase 2 take 动作按钮才显式引用。
      colorScheme: ColorScheme.light(
        primary: KkColors.teal,
        surface: KkColors.bgCard,
        onPrimary: Colors.white,
        onSurface: KkColors.t1,
      ),
      dividerColor: KkColors.divider,
      splashFactory: InkSparkle.splashFactory,
      // 文字主题:把 KkType 接入 Material 默认语义
      textTheme: const TextTheme(
        displayLarge: KkType.h1,
        displayMedium: KkType.h2,
        titleLarge: KkType.h3,
        bodyLarge: KkType.body,
        bodyMedium: KkType.bodySm,
        labelSmall: KkType.mono,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: KkColors.bg,
        foregroundColor: KkColors.t1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: KkType.h3,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KkColors.bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(KkRadius.xl)),
        ),
      ),
    );

    return base;
  }
}
