import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/kk_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/code_diff_block.dart';
import '../../../core/widgets/tappable.dart';
import '../../../data/seed/mock_seed.dart';
import '../../../domain/models/models.dart';

/// 动作区 — HANDOFF §2.2 三原语渲染,一行一个,任意组合。
///
/// **核心铁律(HANDOFF §2 / §7.1):用 switch 模式匹配 ActionItem sealed class,
/// 禁 if(artifactType) 硬编码分支。** 这是真假复用的试金石。
///
/// 颜色铁律(HANDOFF §5):
///   - TakeAction → 珊瑚橙 #D85A30(只此一处用珊瑚橙)
///   - GoAction   → 墨绿描边
///   - HowAction  → 次级墨绿文字,文案永远"工作流"
///
/// 按钮无"拿走"二字(HANDOFF §2.2):TakeAction 靠图标(下载/复制)表意 + 可选对象名。
/// take 成功后 takeawayCount +1(HANDOFF §2.2,与点赞同源体感)。
class ActionRow extends StatelessWidget {
  final List<ActionItem> actions;

  /// take 成功回调(详情页注入,用于 takeawayCount +1 + toast)
  final void Function(TakeAction action)? onTakeSuccess;

  const ActionRow({
    super.key,
    required this.actions,
    this.onTakeSuccess,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      // HANDOFF §2.2:无任何动作(纯心得)→ 动作区整块不显示。
      // 但此 widget 被调用即说明有动作;空时返回 0 高度(防御)。
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in actions) ...[
          _render(a),
          const SizedBox(height: KkSpacing.md),
        ],
        // 末尾不需要间距
        const SizedBox(height: 0),
      ],
    );
  }

  /// 模式匹配渲染 — HANDOFF §2 / §7.1 试金石。
  ///
  /// **禁 if(artifactType == 'xxx') 之类硬编码分支。**
  /// sealed class + switch 是 Dart 3 的原生穷举匹配,新增 ActionItem 子类时
  /// 编译器强制覆盖,不会漏。
  Widget _render(ActionItem a) {
    return switch (a) {
      TakeAction(:final source, :final takeKind, :final label) =>
        _TakeButton(
          source: source,
          takeKind: takeKind,
          label: label,
          onSuccess: () => onTakeSuccess?.call(a as TakeAction),
        ),
      GoAction(:final url, :final label) => _GoButton(url: url, label: label),
      HowAction(:final ref, :final label) =>
        _HowButton(ref: ref, label: label ?? '工作流'),
    };
  }
}

// ──────────────────────────────────────────────────────────────────
// take — 珊瑚橙,真复制/真下载,按钮无"拿走"字
// ──────────────────────────────────────────────────────────────────
class _TakeButton extends StatefulWidget {
  final String source;
  final String takeKind; // 'copy' | 'download'
  final String? label;
  final VoidCallback onSuccess;

  const _TakeButton({
    required this.source,
    required this.takeKind,
    required this.label,
    required this.onSuccess,
  });

  @override
  State<_TakeButton> createState() => _TakeButtonState();
}

class _TakeButtonState extends State<_TakeButton> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final isCopy = widget.takeKind == 'copy';
    final icon = isCopy ? Icons.copy_outlined : Icons.download_outlined;
    final doneIcon = Icons.check;

    // HANDOFF §2.2:按钮无"拿走"二字。图标表意 + 可选对象名(label)。
    final text = widget.label ?? (isCopy ? '复制' : '下载');

    return Tappable(
      onTap: _onTap,
      borderRadius: BorderRadius.circular(KkRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: KkSpacing.md,
          horizontal: KkSpacing.lg,
        ),
        decoration: BoxDecoration(
          // 珊瑚橙(HANDOFF §5:只给 take)
          color: _done ? KkColors.coralMint : KkColors.coral,
          borderRadius: BorderRadius.circular(KkRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _done ? doneIcon : icon,
              color: _done ? KkColors.coral : Colors.white,
              size: 18,
            ),
            const SizedBox(width: KkSpacing.sm),
            Text(
              _done ? '已${isCopy ? '复制' : '下载'}' : text,
              style: TextStyle(
                color: _done ? KkColors.coral : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap() async {
    final isCopy = widget.takeKind == 'copy';
    try {
      if (isCopy) {
        // 真复制到剪贴板
        await Clipboard.setData(ClipboardData(text: widget.source));
      } else {
        // 真下载(简化:用 url_launcher 打开,浏览器处理下载)
        // Phase 5 接 path_provider + dio 做真后台下载
        final uri = Uri.tryParse(widget.source);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      if (!mounted) return;
      setState(() => _done = true);
      widget.onSuccess();
      // 2 秒后恢复
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _done = false);
      });
    } catch (_) {
      // 静默失败(Phase 5 加 toast)
    }
  }
}

// ──────────────────────────────────────────────────────────────────
// go — 墨绿描边,真开外链,行尾 ↗
// ──────────────────────────────────────────────────────────────────
class _GoButton extends StatelessWidget {
  final String url;
  final String? label;

  const _GoButton({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = label ?? _defaultLabel(url);
    return Tappable(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(KkRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: KkSpacing.md,
          horizontal: KkSpacing.lg,
        ),
        decoration: BoxDecoration(
          // 墨绿描边(HANDOFF §2.2)
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(KkRadius.md),
          border: Border.all(color: KkColors.teal, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: KkColors.teal,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'JetBrainsMono',
              ),
            ),
            const SizedBox(width: KkSpacing.xs),
            // 行尾 ↗(go 表意)
            const Icon(
              Icons.arrow_outward,
              size: 16,
              color: KkColors.teal,
            ),
          ],
        ),
      ),
    );
  }

  /// HANDOFF §4:放链接 → 当场识别 GitHub/App Store/网址 → 默认 label
  String _defaultLabel(String url) {
    final u = url.toLowerCase();
    if (u.contains('github.com')) return 'GitHub';
    if (u.contains('apps.apple.com')) return 'App Store';
    if (u.contains('play.google.com')) return 'Google Play';
    // 取域名
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return '访问';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ──────────────────────────────────────────────────────────────────
// how — 次级墨绿文字,文案永远"工作流"
// Phase 3 Tier 4:点击 inline 展开工作流 diff(不再跳页)。
// ──────────────────────────────────────────────────────────────────
class _HowButton extends StatefulWidget {
  final String ref;
  final String label; // 永远"工作流"(HANDOFF §2.2)

  const _HowButton({required this.ref, required this.label});

  @override
  State<_HowButton> createState() => _HowButtonState();
}

class _HowButtonState extends State<_HowButton> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // HANDOFF §2.2 how 动作:ref 在 mockWorkflows 找不到时,展开显示灰字兜底。
    final workflow = findWorkflow(widget.ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 按钮(点击 toggle 展开/收起)
        Tappable(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(KkRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: KkSpacing.sm,
              horizontal: KkSpacing.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _expanded
                      ? Icons.unfold_less_outlined
                      : Icons.account_tree_outlined,
                  size: 16,
                  color: KkColors.teal,
                ),
                const SizedBox(width: KkSpacing.xs),
                Text(
                  _expanded ? '收起工作流' : widget.label, // "工作流"
                  style: const TextStyle(
                    color: KkColors.teal,
                    fontSize: 14,
                    fontFamily: 'NotoSerifSC',
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开内容:AnimatedSize 折叠高度 + AnimatedOpacity 渐入渐出。
        AnimatedSize(
          duration: KkDuration.med,
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: _expanded ? 1.0 : 0.0,
            duration: KkDuration.med,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: KkSpacing.sm),
                    child: workflow == null
                        ? Text(
                            '工作流详情暂未提供',
                            style: KkType.bodySm
                                .copyWith(color: KkColors.t3),
                          )
                        : CodeDiffBlock(
                            title: workflow.title,
                            before: workflow.before,
                            after: workflow.after,
                            language: workflow.language,
                          ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
