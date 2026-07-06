import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/interactions_api.dart';
import '../data/seed/mock_seed.dart';
import '../domain/models/models.dart';
import 'auth_provider.dart';

/// 全局 AppState — 替代 Web 版 Zustand store。
///
/// HANDOFF §8.1:Drift 推迟。Phase 2 用内存 state(Riverpod Notifier),
/// Phase 5 真有复杂本地缓存需求再上 Drift。
///
/// Phase 3 扩展:加入通知未读集合(HANDOFF §6.8)+ 最近搜索词(search 屏)。
/// 所有计数取真实 Set/List 长度(HANDOFF §6.10,禁 ×200 编造)。
///
/// 状态分两类:
///   1. ID 集合(likedItemIds / savedProjectIds / followedUserIds / unreadNotifIds)
///   2. 实体列表(savedTakeaways / browseHistory / recentSearches)— 找回内容用
///
/// Phase 4:recentSearches 升级为 Map<String, int>(query → 最近一次时间戳,毫秒),
/// 天然去重 + 时间戳排序。旧 [recentSearches] getter 保留返回 List<String>
/// (按时间戳降序),向后兼容 settings_screen / search_results_screen 等调用方。
/// 新 [recentSearchesWithTime] getter 返回带时间戳 record,供 search_screen 时间分组。
@immutable
class AppStateData {
  final ThemeMode themeMode;

  /// 当前激活的 branch index(0..3)。
  final int currentTabIndex;

  // ── 点赞(ID 集合,Project / Post 共用同一池,因为 ID 唯一)──
  /// 点赞过的项目/动态 ID 集合
  final Set<String> likedItemIds;

  // ── 收藏(HANDOFF §6.3 收藏页)──
  /// 收藏的项目 ID 集合
  final Set<String> savedProjectIds;

  // ── 关注(HANDOFF §1 二分:关注流是 discover 屏的第二个 tab)──
  /// 关注的用户 ID 集合
  final Set<String> followedUserIds;

  // ── 我拿走的(HANDOFF §6.3 内容库,按 文本/文件/链接 分类)──
  /// 拿走的内容列表(找回库,真存数据)
  final List<SavedTakeaway> savedTakeaways;

  // ── 浏览历史(me 屏可读,Phase 3 完善)──
  /// 最近浏览的项目 ID(最新在前,最多 50 条)
  final List<String> browseHistory;

  // ── 通知未读 ID 集合(HANDOFF §6.8)— 真实长度,不放大 ──
  final Set<String> unreadNotifIds;

  // ── 最近搜索词(search 屏用,Phase 4 升级为 Map<String, int> 时间戳)──
  /// query → 最近一次搜索时间戳(毫秒)。Map 天然去重,更新时刷新时间戳。
  final Map<String, int> recentSearchesMap;

  // ── 不感兴趣(任务⑫:负反馈闭环)──
  /// 标记「不感兴趣」的项目/动态 ID 集合(单向 add,不可撤销)。
  /// discover 推荐/关注流 + kankan _mockList 渲染前过滤掉这些 ID。
  /// kankan _remoteList(真数据)不过滤(后端另说)。
  final Set<String> notInterestedIds;

  // ── 偏好设置(真生效,settings 屏读写)──
  /// 字号:'小'/'标准'/'大'/'特大' → app.dart 应用全局 textScaler。
  final String fontScale;

  /// 暖纸底纹开关 → NoiseBackground 读它决定画不画噪点。
  final bool paperTexture;

  /// 免打扰:开 → 通知铃未读红点被抑制(effectiveUnreadCount 归零)。
  final bool dndEnabled;

  /// 我的页 banner 背景图 URL(用户换背景;web 是 image_picker 的 blob URL,
  /// 会话内有效不持久化。null → 用默认暖色渐变)。
  final String? bannerImageUrl;

  const AppStateData({
    this.themeMode = ThemeMode.light,
    this.currentTabIndex = 0,
    this.likedItemIds = const {},
    this.savedProjectIds = const {},
    this.followedUserIds = const {},
    this.savedTakeaways = const [],
    this.browseHistory = const [],
    this.unreadNotifIds = const {},
    this.recentSearchesMap = const {},
    this.notInterestedIds = const {},
    this.fontScale = '标准',
    this.paperTexture = true,
    this.dndEnabled = false,
    this.bannerImageUrl,
  });

  /// 免打扰生效后的未读数:DND 开 → 0(红点消失);否则真实未读数。
  int get effectiveUnreadCount => dndEnabled ? 0 : unreadNotifIds.length;

  /// 字号 → textScaler 倍率。
  double get textScaleFactor => switch (fontScale) {
        '小' => 0.9,
        '大' => 1.15,
        '特大' => 1.3,
        _ => 1.0,
      };

  /// 向后兼容:返回 List<String>(按时间戳降序,最新在前)。
  /// 供 settings_screen(searchCount = .length)/ search_results_screen 等使用。
  List<String> get recentSearches {
    final entries = recentSearchesMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) e.key];
  }

  /// Phase 4:带时间戳的最近搜索(按时间戳降序)。
  /// 供 search_screen 时间分组(今天 / 昨天 / 更早)用。
  List<({String query, int createdAtMs})> get recentSearchesWithTime {
    final entries = recentSearchesMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in entries) (query: e.key, createdAtMs: e.value),
    ];
  }

  factory AppStateData.initial() => AppStateData(
        // HANDOFF §6.3:启动即载入 mock 的"我拿走的",library 屏可直接读真实数据。
        savedTakeaways: mockSavedTakeaways,
        // Phase 3:启动载入 mock 通知未读(全部 mock 通知默认未读)+ 浏览历史 + 最近搜索。
        unreadNotifIds: {for (final n in mockNotifications) n.id},
        browseHistory: mockBrowseHistory,
        // Phase 4:recentSearches 升级为 Map<String, int>,mock 词分散到今天/昨天/更早
        // 三段时间区间,让 search_screen 时间分组有真实演示数据。
        recentSearchesMap: _seedRecentSearches(),
      );

  /// 把 mockRecentSearches 6 条词分散到 今天/昨天/更早 三段。
  /// 第 0-1 条:今天(30min / 2h 前);2-3:昨天(26h / 30h 前);4-5:更早(3d / 10d 前)。
  static Map<String, int> _seedRecentSearches() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const hour = 60 * 60 * 1000;
    const day = 24 * hour;
    const offsets = [
      30 * 60 * 1000, // 0:今天 30min 前
      2 * hour, // 1:今天 2h 前
      26 * hour, // 2:昨天 26h 前
      30 * hour, // 3:昨天 30h 前
      3 * day, // 4:更早 3d 前
      10 * day, // 5:更早 10d 前
    ];
    final out = <String, int>{};
    for (var i = 0; i < mockRecentSearches.length; i++) {
      final offset =
          i < offsets.length ? offsets[i] : day * (i + 1);
      out[mockRecentSearches[i]] = now - offset;
    }
    return out;
  }

  AppStateData copyWith({
    ThemeMode? themeMode,
    int? currentTabIndex,
    Set<String>? likedItemIds,
    Set<String>? savedProjectIds,
    Set<String>? followedUserIds,
    List<SavedTakeaway>? savedTakeaways,
    List<String>? browseHistory,
    Set<String>? unreadNotifIds,
    Map<String, int>? recentSearchesMap,
    Set<String>? notInterestedIds,
    String? fontScale,
    bool? paperTexture,
    bool? dndEnabled,
    String? bannerImageUrl,
  }) =>
      AppStateData(
        themeMode: themeMode ?? this.themeMode,
        currentTabIndex: currentTabIndex ?? this.currentTabIndex,
        likedItemIds: likedItemIds ?? this.likedItemIds,
        savedProjectIds: savedProjectIds ?? this.savedProjectIds,
        followedUserIds: followedUserIds ?? this.followedUserIds,
        savedTakeaways: savedTakeaways ?? this.savedTakeaways,
        browseHistory: browseHistory ?? this.browseHistory,
        unreadNotifIds: unreadNotifIds ?? this.unreadNotifIds,
        recentSearchesMap: recentSearchesMap ?? this.recentSearchesMap,
        notInterestedIds: notInterestedIds ?? this.notInterestedIds,
        fontScale: fontScale ?? this.fontScale,
        paperTexture: paperTexture ?? this.paperTexture,
        dndEnabled: dndEnabled ?? this.dndEnabled,
        bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      );
}

/// 全局状态 Notifier(手动,无 codegen)。
class AppStateNotifier extends Notifier<AppStateData> {
  @override
  AppStateData build() => AppStateData.initial();

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  // ── 偏好设置(真生效)──
  void setFontScale(String scale) =>
      state = state.copyWith(fontScale: scale);
  void setPaperTexture(bool on) =>
      state = state.copyWith(paperTexture: on);
  void setDndEnabled(bool on) => state = state.copyWith(dndEnabled: on);
  void setBannerImage(String url) =>
      state = state.copyWith(bannerImageUrl: url);

  void setTabIndex(int i) => state = state.copyWith(currentTabIndex: i);

  /// F-3:更新 'me' 用户资料(写入内存 mockUsers)。
  /// 调用方(如 profile_edit _save)调用后应 ref.invalidate(userByIdProvider('me'))
  /// 让 profile / me 等屏重建显示新值。
  /// domains 暂不持久化(KkUser 无 interests 字段,Phase 5 加字段后接)。
  void updateProfile({required String name, String? bio}) {
    final i = mockUsers.indexWhere((u) => u.id == 'me');
    if (i >= 0) {
      mockUsers[i] = mockUsers[i].copyWith(
        name: name,
        bio: bio ?? mockUsers[i].bio,
      );
    }
  }

  // ── 点赞 ──
  bool isLiked(String id) => state.likedItemIds.contains(id);

  void toggleLike(String id) {
    final next = Set<String>.from(state.likedItemIds);
    if (!next.add(id)) next.remove(id);
    state = state.copyWith(likedItemIds: next);
  }

  // ── 收藏 ──
  bool isSaved(String projectId) =>
      state.savedProjectIds.contains(projectId);

  void toggleSave(String projectId) {
    final wasSaved = state.savedProjectIds.contains(projectId);
    final next = Set<String>.from(state.savedProjectIds);
    if (wasSaved) {
      next.remove(projectId);
    } else {
      next.add(projectId);
    }
    state = state.copyWith(savedProjectIds: next); // 乐观更新，UI 立即响应
    _syncFavorite(projectId, on: !wasSaved); // 后端同步（仅登录 + 真后端项目）
  }

  /// 收藏落库：登录 + 真后端项目（UUID）才发请求；失败回滚本地，保持与后端一致。
  /// mock 项目（短 id 如 'p1'）本地即真源，不碰后端（发了也会 404）。
  Future<void> _syncFavorite(String projectId, {required bool on}) async {
    if (!ref.read(authProvider).isLoggedIn) return;
    if (!_looksLikeBackendId(projectId)) return;
    try {
      await ref.read(interactionsApiProvider).setFavorite(projectId, on);
    } catch (_) {
      // 落库失败：撤回乐观更新（此刻 state 可能已被其它操作改动，按幂等增删处理）
      final revert = Set<String>.from(state.savedProjectIds);
      if (on) {
        revert.remove(projectId);
      } else {
        revert.add(projectId);
      }
      state = state.copyWith(savedProjectIds: revert);
    }
  }

  /// 粗判是否后端项目 id（UUID：含 '-' 且长度 ≥ 32）。mock id 是 'p1'/'p2' 这类短串。
  bool _looksLikeBackendId(String id) => id.contains('-') && id.length >= 32;

  // ── 关注 ──
  bool isFollowing(String userId) =>
      state.followedUserIds.contains(userId);

  void toggleFollow(String userId) {
    final next = Set<String>.from(state.followedUserIds);
    if (!next.add(userId)) next.remove(userId);
    state = state.copyWith(followedUserIds: next);
  }

  // ── 我拿走的(HANDOFF §6.3)──
  void addTakeaway(SavedTakeaway t) {
    final next = List<SavedTakeaway>.from(state.savedTakeaways);
    next.removeWhere((x) => x.id == t.id);
    next.insert(0, t);
    state = state.copyWith(savedTakeaways: next);
  }

  void removeTakeaway(String id) {
    final next = List<SavedTakeaway>.from(state.savedTakeaways)
      ..removeWhere((x) => x.id == id);
    state = state.copyWith(savedTakeaways: next);
  }

  // ── 浏览历史 ──
  void recordBrowse(String projectId) {
    final next = List<String>.from(state.browseHistory)
      ..remove(projectId)
      ..insert(0, projectId);
    if (next.length > 50) next.removeRange(50, next.length);
    state = state.copyWith(browseHistory: next);
  }

  /// 清空浏览历史(「我的」页最近看过的「清空」按钮)。
  void clearBrowseHistory() {
    state = state.copyWith(browseHistory: const []);
  }

  // ── 通知未读(HANDOFF §6.8)──
  void markNotifRead(String id) {
    final next = Set<String>.from(state.unreadNotifIds)..remove(id);
    state = state.copyWith(unreadNotifIds: next);
  }

  void markAllNotifRead() {
    state = state.copyWith(unreadNotifIds: const {});
  }

  // ── 最近搜索词(Phase 4:Map<String, int> 时间戳)──
  /// 加入一条搜索:刷新时间戳(天然去重)。超过 12 条时淘汰最旧。
  void addRecentSearch(String q) {
    final s = q.trim();
    if (s.isEmpty) return;
    final next = Map<String, int>.from(state.recentSearchesMap);
    next[s] = DateTime.now().millisecondsSinceEpoch;
    // 容量上限 12:超出则按时间戳升序(最旧在前)批量淘汰
    if (next.length > 12) {
      final sorted = next.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final excess = sorted.length - 12;
      for (var i = 0; i < excess; i++) {
        next.remove(sorted[i].key);
      }
    }
    state = state.copyWith(recentSearchesMap: next);
  }

  void removeRecentSearch(String q) {
    final next = Map<String, int>.from(state.recentSearchesMap)..remove(q);
    state = state.copyWith(recentSearchesMap: next);
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearchesMap: const {});
  }

  // ── 不感兴趣(任务⑫:负反馈闭环)──
  /// 标记某项目/动态 ID 为「不感兴趣」(单向 add,幂等)。
  /// discover 推荐/关注流 + kankan _mockList 渲染前过滤掉该 ID。
  /// 不对称 toggleSave(单向):「不感兴趣」是减少推荐,无「恢复」语义。
  void markNotInterested(String id) {
    if (state.notInterestedIds.contains(id)) return;
    final next = Set<String>.from(state.notInterestedIds)..add(id);
    state = state.copyWith(notInterestedIds: next);
  }
}

/// 全局 AppState provider。用法:ref.watch(appStateProvider).xxx
final appStateProvider =
    NotifierProvider<AppStateNotifier, AppStateData>(() => AppStateNotifier());
