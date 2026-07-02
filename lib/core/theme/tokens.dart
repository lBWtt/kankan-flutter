import 'package:flutter/material.dart';

import 'kk_colors.dart';

/// 设计 token — 间距 / 圆角 / 字号 / 时长 / 触控。
///
/// 全 App 只用这里的常量,不硬编码数字(保证一致性)。
/// HANDOFF §5:触控区 ≥ 44×44pt 是铁律。

/// 间距体系(4 的倍数)
class KkSpacing {
  KkSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

/// 圆角体系
class KkRadius {
  KkRadius._();
  static const sm = 6.0;   // 小标签
  static const md = 10.0;  // 卡片
  static const lg = 14.0;  // 大卡片
  static const xl = 18.0;  // sheet 顶部
  static const pill = 999.0; // 胶囊
}

/// 字号体系(三声部字体)
///
/// HANDOFF §5:
///   - 标题:Noto Serif SC(衬线,必须含中文子集)
///   - 元数据/数字:JetBrains Mono(等宽)
///   - 正文:系统 sans(Material 默认)
class KkType {
  KkType._();

  // 标题(衬线)— fontFamily 找不到时 Flutter 自动回退系统衬线
  static const h1 = TextStyle(
    fontFamily: 'NotoSerifSC',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: KkColors.t1,
  );
  static const h2 = TextStyle(
    fontFamily: 'NotoSerifSC',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: KkColors.t1,
  );
  static const h3 = TextStyle(
    fontFamily: 'NotoSerifSC',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: KkColors.t1,
  );

  // 正文(系统 sans)
  static const body = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: KkColors.t1,
  );
  static const bodySm = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: KkColors.t2,
  );

  // 元数据/数字(等宽)
  static const mono = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 13,
    height: 1.4,
    color: KkColors.t2,
  );
  static const monoLg = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: KkColors.t1,
  );
}

/// 动画时长
class KkDuration {
  KkDuration._();
  static const fast = Duration(milliseconds: 150);
  static const med = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

/// 触控区铁律
class KkTouch {
  KkTouch._();
  /// HANDOFF §5:所有可点元素实际点击区 ≥ 44×44pt
  static const minTarget = 44.0;
}
