/// 字体 family 常量。
///
/// HANDOFF §5:
///   - 标题:Noto Serif SC(衬线,**必须含中文子集**,Web 版踩过 subsets:['latin']
///     不含中文的坑 → Flutter 端自托管子集化文件,见 assets/fonts/README.md)
///   - 元数据/数字:JetBrains Mono(等宽)
///   - 正文:系统 sans(不显式命名,走 Material 默认)
///
/// family 名与 pubspec.yaml 的 `fonts: - family:` 段一致。
/// 未声明字体时,ThemeData 里写这些 family 名,Flutter 自动回退系统字体(不崩)。
class FontFamily {
  FontFamily._();
  static const serif = 'NotoSerifSC';
  static const mono = 'JetBrainsMono';
}
