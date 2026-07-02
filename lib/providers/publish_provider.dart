import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/models.dart';

/// 发布草稿 state — 实时构建 resultData + actions。
///
/// HANDOFF §4:放什么系统猜什么。用户操作 → 此 state 更新 →
/// publish_preview 实时读 → 显示详情端会渲染的样子。两端咬合。
///
/// HANDOFF §4 验收:发布端产出的数据结构 = 详情端可组合渲染所读的
/// {media(视频优先), actions:[take/go/how]}。
@immutable
class PublishDraft {
  /// 标题
  final String title;

  /// 一句话价值
  final String summary;

  /// 领域(可选,用户不选则发布时按内容猜)
  final String? domain;

  /// 标签(输入的 # 话题)
  final List<String> tags;

  /// 作者的话
  final String authorNote;

  /// 成果区 media(传的图/视频,视频自动排前)
  final List<MediaItem> media;

  /// 动作区(用户加的 take/go/how,任意组合)
  final List<ActionItem> actions;

  /// 正文(无 media 时,纯文字心得)
  final String? text;

  const PublishDraft({
    this.title = '',
    this.summary = '',
    this.domain,
    this.tags = const [],
    this.authorNote = '',
    this.media = const [],
    this.actions = const [],
    this.text,
  });

  PublishDraft copyWith({
    String? title,
    String? summary,
    String? domain,
    List<String>? tags,
    String? authorNote,
    List<MediaItem>? media,
    List<ActionItem>? actions,
    String? text,
  }) =>
      PublishDraft(
        title: title ?? this.title,
        summary: summary ?? this.summary,
        domain: domain ?? this.domain,
        tags: tags ?? this.tags,
        authorNote: authorNote ?? this.authorNote,
        media: media ?? this.media,
        actions: actions ?? this.actions,
        text: text ?? this.text,
      );

  /// 构建为 Project(发布时调用)。
  ///
  /// 关键:产出结构 = detail 端可组合渲染所读的 {resultData, actions}。
  /// 视频自动排前(HANDOFF §4)。
  Project toProject({
    required String id,
    required String authorId,
    required int createdAtMs,
  }) {
    final sortedMedia = _videoFirst(media);
    return Project(
      id: id,
      title: title.isEmpty ? '未命名' : title,
      summary: summary,
      authorId: authorId,
      resultData: ResultData(
        media: sortedMedia,
        text: text,
      ),
      actions: actions,
      tags: tags,
      authorNote: authorNote.isEmpty ? null : authorNote,
      domain: domain ?? _guessDomain(),
      createdAtMs: createdAtMs,
    );
  }

  /// 视频排前(HANDOFF §4:传图视频→成果,视频自动排前)
  static List<MediaItem> _videoFirst(List<MediaItem> media) {
    final videos = media.where((m) => m.type == 'video').toList();
    final images = media.where((m) => m.type == 'image').toList();
    return [...videos, ...images];
  }

  /// 猜领域(用户不选时)
  String _guessDomain() {
    if (media.any((m) => m.type == 'video')) return 'ai_video';
    if (media.any((m) => m.type == 'image')) return 'ai_image';
    if (actions.any((a) => a is GoAction)) {
      final go = actions.whereType<GoAction>().first;
      if (go.url.contains('github.com')) return 'opensource';
      if (go.url.contains('apps.apple.com') || go.url.contains('play.google.com')) return 'app';
      return 'web';
    }
    if (actions.any((a) => a is TakeAction && a.takeKind == 'copy')) return 'prompt';
    if (actions.any((a) => a is TakeAction && a.takeKind == 'download')) return 'tool';
    return 'prompt'; // 兜底
  }
}

class PublishDraftNotifier extends Notifier<PublishDraft> {
  @override
  PublishDraft build() => const PublishDraft();

  void setTitle(String t) => state = state.copyWith(title: t);
  void setSummary(String s) => state = state.copyWith(summary: s);
  void setDomain(String d) => state = state.copyWith(domain: d);
  void setAuthorNote(String n) => state = state.copyWith(authorNote: n);
  void setText(String t) => state = state.copyWith(text: t);

  void addTag(String tag) {
    if (!state.tags.contains(tag)) {
      state = state.copyWith(tags: [...state.tags, tag]);
    }
  }
  void removeTag(String tag) =>
      state = state.copyWith(tags: state.tags.where((t) => t != tag).toList());

  /// 加媒体(图/视频)。HANDOFF §4:传图视频→成果,视频自动排前由 toProject 处理。
  void addMedia(MediaItem m) => state = state.copyWith(media: [...state.media, m]);
  void removeMediaAt(int i) {
    final list = [...state.media];
    if (i >= 0 && i < list.length) list.removeAt(i);
    state = state.copyWith(media: list);
  }

  /// 加动作(HANDOFF §4:"+"底部 sheet 三选一 → take/go/how)
  void addAction(ActionItem a) => state = state.copyWith(actions: [...state.actions, a]);
  void removeActionAt(int i) {
    final list = [...state.actions];
    if (i >= 0 && i < list.length) list.removeAt(i);
    state = state.copyWith(actions: list);
  }

  /// 重置(发布成功后调用)
  void reset() => state = const PublishDraft();
}

final publishDraftProvider =
    NotifierProvider<PublishDraftNotifier, PublishDraft>(
        () => PublishDraftNotifier());
