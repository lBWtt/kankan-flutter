# 字体文件(需本地生成后放入此目录)

本目录需放入两个字体文件后 app 才能显示真衬线中文标题。

## 为什么必须自托管子集化

HANDOFF §5 铁律:
- 标题字:Noto Serif SC(衬线,**必须含中文子集**)
- Web 版踩过坑:Google Fonts `subsets:['latin']` 不含中文,标题回退成系统 sans
- Flutter 端:**自托管子集化文件**,不依赖运行时拉取

## 需要的文件

| 文件名 | 来源 | 大小 |
|---|---|---|
| `NotoSerifSC-Subset.ttf` | Noto Serif SC 子集化(见下) | ~1.5–3 MB |
| `JetBrainsMono-Regular.ttf` | [JetBrains Mono GitHub](https://github.com/JetBrains/JetBrainsMono/releases) | ~200 KB |

## 一键子集化(推荐)

```bash
# 前置:pip install fonttools brotli
./subset.sh /path/to/NotoSerifSC-Regular.otf
# 产出:NotoSerifSC-Subset.ttf → 放入本目录
```

## 手动子集化

```bash
pyftsubset NotoSerifSC-Regular.otf \
  --unicodes="U+4E00-9FFF,U+3000-303F,U+FF00-FFEF,U+2000-206F,U+0020-007E" \
  --output-file=NotoSerifSC-Subset.ttf \
  --no-hinting \
  --desubroutinize \
  --drop-tables+=DSIG
```

- `U+4E00-9FFF`:CJK 统一汉字(全部 ~20k 字,宽子集,~3MB)
- `U+3000-303F`:CJK 标点
- `U+FF00-FFEF`:全角符号
- `U+2000-206F`:通用标点
- `U+0020-007E`:ASCII

### 精简到 3500 常用字(~1.5MB,生产推荐)

准备 `common-3500.txt`(通用规范汉字表一级字,3500 字),改用:

```bash
pyftsubset NotoSerifSC-Regular.otf \
  --text-file=common-3500.txt \
  --output-file=NotoSerifSC-Subset.ttf \
  --no-hinting \
  --desubroutinize
```

`common-3500.txt` 可从 https://github.com/JaidedAI/EasyOCR 或类似仓库获取,
或用 Python 从 `unicodedata` 生成 GB2312 一级字。

## 放好后

1. 把两个 `.ttf` 放入本目录
2. 编辑 `pubspec.yaml`,取消 `fonts:` 段注释(文件末尾):
   ```yaml
   fonts:
     - family: NotoSerifSC
       fonts:
         - asset: assets/fonts/NotoSerifSC-Subset.ttf
     - family: JetBrainsMono
       fonts:
         - asset: assets/fonts/JetBrainsMono-Regular.ttf
   ```
3. `flutter pub get && flutter run`

## 不放字体的降级行为

`pubspec.yaml` 默认注释掉 `fonts:` 段。此时 `ThemeData` 的 `fontFamily: 'NotoSerifSC'`
找不到 family,Flutter 自动回退:
- iOS:Songti SC(衬线)
- Android:Noto Serif CJK SC(若系统有)或 sans 回退

中文正常显示,只是不是 Noto Serif SC。这是 Phase 1 的有意降级,不是 bug——
让 app 放下就能跑,不等字体子集化。
