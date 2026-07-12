// P2-i18n:看看 app 字符串 SSOT(手写方案,免 codegen)。
//
// 设计依据(用户:"未来会用英文,但不准备第一次就上线,接口之类的留好就行"):
//   - 不依赖 flutter gen-l10n(沙箱无 flutter SDK 也能编译;CI 跑 gen-l10n 也不冲突);
//   - 同名 key 与 lib/l10n/app_zh.arb / app_en.arb 并行维护 — arb 是切 gen-l10n
//     时的输入,kk_strings.dart 是当前运行的输出,两边 key 同名同语义;
//   - 当前 zh 默认,en 是 stub(不暴露给用户:app.dart locale 写死 zh);
//   - 切 gen-l10n 时:删本文件,改用 `AppLocalizations.of(context)!.xxx`,
//     app.dart 的 localizationsDelegates 改为 AppLocalizations.localizationsDelegates,
//     调用方把 `ref.watch(kkStringsProvider).xxx` 改为
//     `AppLocalizations.of(context)!.xxx`(1 文件替换 + 调用点改 import)。
//
// 已迁移的调用点(参考实现):
//   - lib/core/widgets/kk_tab_bar.dart:底栏 4 Tab 标签(discoverTab / kankanTab /
//     libraryTab / meTab)。
//   - lib/features/kankan/kankan_screen.dart:顶栏榜单/搜索图标 semanticLabel。
//   - lib/features/shared/post_card.dart / project_card.dart:卡片整体 +
//     点赞/评论/收藏按钮 semanticLabel。
//   - lib/features/shared/kk_chip.dart:× 关闭 chip 的 semanticLabel(remove)。
//   - lib/features/shared/empty_state.dart:6 变体文案接 KkStrings。
//   - lib/features/shared/remote_error.dart:默认错误文案 + 重试按钮。
//   - discover / kankan / library / me / profile / detail / compose / publish /
//     search / settings / notifications / topic_plaza / profile_edit / post_detail /
//     publish_entry_sheet:顶栏标题 + 高频字面量接 KkStrings(2024-11 扩量)。
//
// 未迁移(按需逐步搬):
//   - lib/ 内仍硬编码的中文字面量(主要在 detail widgets / publish widgets /
//     ranking / activity / clue / login / topic / comment_bottom_sheet 等)。
//     搜索 `// TODO(i18n): 迁移到 KkStrings` 找未迁点。
//
// 命名约定:getter 名 = arb key(camelCase);含占位符的用方法(如
// projectSemantic(title))— 切 gen-l10n 时方法签名兼容(ARB 的 {placeholder}
// 也变成方法参数)。

import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 看看 app 字符串集合(不可变)。
///
/// 两种实例:
///   - [KkStrings.zh]:中文(默认,当前 app 唯一对外暴露的 locale)。
///   - [KkStrings.en]:英文 stub(预留接口,文案已对齐 zh 全部 key;切 en 上线
///     时一行 locale 改动即生效)。
class KkStrings {
  /// 中文(默认)。
  const KkStrings.zh() : _v = _zhValues;

  /// 英文 stub(预留接口,当前不暴露)。
  const KkStrings.en() : _v = _enValues;

  final Map<String, String> _v;

  // ── App 标题 ──

  /// MaterialApp.title / 顶栏标题(arb: appTitle)。
  String get appTitle => _v['appTitle']!;

  // ── 底栏 4 Tab ──

  /// 底栏 Tab 1(arb: discoverTab)。
  String get discoverTab => _v['discoverTab']!;

  /// 底栏 Tab 2(arb: kankanTab)。
  String get kankanTab => _v['kankanTab']!;

  /// 底栏 Tab 3(arb: libraryTab)。
  String get libraryTab => _v['libraryTab']!;

  /// 底栏 Tab 4(arb: meTab)。
  String get meTab => _v['meTab']!;

  // ── 通用动作(多用于 icon-only 按钮的 semanticLabel)──

  /// 发布动作(arb: publish)。
  String get publish => _v['publish']!;

  /// 搜索动作(arb: search)。
  String get search => _v['search']!;

  /// 收藏动作(arb: save)。
  String get save => _v['save']!;

  /// 点赞动作(arb: like)。
  String get like => _v['like']!;

  /// 评论动作(arb: comment)。
  String get comment => _v['comment']!;

  /// 分享动作(arb: share)。
  String get share => _v['share']!;

  /// 关注(未关注态,arb: follow)。
  String get follow => _v['follow']!;

  /// 已关注(关注态,arb: unfollow)。
  String get unfollow => _v['unfollow']!;

  /// 删除动作(arb: delete)。
  String get delete => _v['delete']!;

  /// 取消(arb: cancel)。
  String get cancel => _v['cancel']!;

  /// 确定(arb: confirm)。
  String get confirm => _v['confirm']!;

  /// 重试(arb: retry)。
  String get retry => _v['retry']!;

  /// 编辑(arb: edit)。
  String get edit => _v['edit']!;

  /// 复制(arb: copy)。
  String get copy => _v['copy']!;

  /// 完成(arb: done)。
  String get done => _v['done']!;

  /// 刷新(arb: refresh)。
  String get refresh => _v['refresh']!;

  /// 返回(arb: back)。
  String get back => _v['back']!;

  /// 更多(arb: more)。
  String get more => _v['more']!;

  /// 举报(arb: report)。
  String get report => _v['report']!;

  /// 拉黑(arb: block)。
  String get block => _v['block']!;

  /// 加载更多(arb: loadMore)。
  String get loadMore => _v['loadMore']!;

  /// 移除(arb: remove)。多用于 chip × 关闭按钮的 semanticLabel。
  String get remove => _v['remove']!;

  /// 清空(arb: clearAll)。多用于历史/缓存清空入口。
  String get clearAll => _v['clearAll']!;

  /// 榜单(看看页顶栏榜单图标 semanticLabel,arb: ranking)。
  String get ranking => _v['ranking']!;

  // ── 通用状态 ──

  /// 加载中(arb: loading)。
  String get loading => _v['loading']!;

  /// 空(arb: empty)。
  String get empty => _v['empty']!;

  /// 出错了(arb: error)。
  String get error => _v['error']!;

  /// 离线(arb: offline)。
  String get offline => _v['offline']!;

  /// 成功(arb: success)。
  String get success => _v['success']!;

  /// 失败(arb: failed)。
  String get failed => _v['failed']!;

  /// 网络异常(arb: networkError)。
  String get networkError => _v['networkError']!;

  // ── 空状态文案 ──

  /// feed 空状态(arb: emptyFeed)。
  String get emptyFeed => _v['emptyFeed']!;

  /// 通用空状态(arb: emptyGeneric)。
  String get emptyGeneric => _v['emptyGeneric']!;

  /// 搜索结果空状态(arb: emptySearch)。
  String get emptySearch => _v['emptySearch']!;

  /// 收藏空状态(arb: emptySaved)。
  String get emptySaved => _v['emptySaved']!;

  /// 拿走物空状态(arb: emptyTakeaway)。
  String get emptyTakeaway => _v['emptyTakeaway']!;

  /// 关注列表空状态(arb: emptyFollowers)。
  String get emptyFollowers => _v['emptyFollowers']!;

  // ── 错误状态文案 ──

  /// 加载失败兜底(arb: loadFailed)。
  String get loadFailed => _v['loadFailed']!;

  /// 连不上服务器(RemoteError message,arb: connectFailed)。
  String get connectFailed => _v['connectFailed']!;

  /// 加载失败通用(arb: errorLoad)。
  String get errorLoad => _v['errorLoad']!;

  /// 网络错误(arb: errorNetwork)。
  String get errorNetwork => _v['errorNetwork']!;

  /// 重试按钮(arb: retryButton)。
  String get retryButton => _v['retryButton']!;

  // ── 含占位符的(方法,与 arb 的 {placeholder} 对应)──

  /// 项目卡整体无障碍标签(arb: projectSemantic = "项目:{title}" /
  /// "Project: {title}")。读屏会念「项目: <标题>」。
  String projectSemantic(String title) =>
      _v['projectSemantic']!.replaceAll('{title}', title);

  /// 动态卡整体无障碍标签(arb: postSemantic = "动态:{author}" /
  /// "Post: {author}")。
  String postSemantic(String author) =>
      _v['postSemantic']!.replaceAll('{author}', author);

  /// 动态计数(arb: postCount = "{n} 动态")。
  String postCount(Object n) => _v['postCount']!.replaceAll('{n}', '$n');

  /// 粉丝计数(arb: followerCount = "{n} 粉丝")。
  String followerCount(Object n) => _v['followerCount']!.replaceAll('{n}', '$n');

  /// 关注计数(arb: followingCount = "{n} 关注")。
  String followingCount(Object n) =>
      _v['followingCount']!.replaceAll('{n}', '$n');

  /// 点赞计数(arb: likeCount = "{n} 赞")。
  String likeCount(Object n) => _v['likeCount']!.replaceAll('{n}', '$n');

  /// 评论计数(arb: commentCount = "{n} 评论")。
  String commentCount(Object n) => _v['commentCount']!.replaceAll('{n}', '$n');

  /// 浏览计数(arb: viewCount = "{n} 浏览")。
  String viewCount(Object n) => _v['viewCount']!.replaceAll('{n}', '$n');

  /// 拿走计数(arb: takeawayCount = "{n} 拿走")。
  String takeawayCount(Object n) => _v['takeawayCount']!.replaceAll('{n}', '$n');

  /// 「N 人想知道」(arb: wantHowToCount = "{n} 人想知道")。
  String wantHowToCount(Object n) =>
      _v['wantHowToCount']!.replaceAll('{n}', '$n');

  /// 「回复 {name}」(arb: replyToName)。
  String replyToName(String name) =>
      _v['replyToName']!.replaceAll('{name}', name);

  // ── 时间相对文案(方法/字符串,与 time_ago.dart 文案对齐)──

  /// 刚刚(arb: justNow)。
  String get justNow => _v['justNow']!;

  /// N 分钟前(arb: minutesAgo = "{n} 分钟前")。
  String minutesAgo(Object n) => _v['minutesAgo']!.replaceAll('{n}', '$n');

  /// N 小时前(arb: hoursAgo = "{n} 小时前")。
  String hoursAgo(Object n) => _v['hoursAgo']!.replaceAll('{n}', '$n');

  /// 昨天(arb: yesterday)。也用作通知/搜索时间桶标题。
  String get yesterday => _v['yesterday']!;

  /// N 天前(arb: daysAgo = "{n} 天前")。
  String daysAgo(Object n) => _v['daysAgo']!.replaceAll('{n}', '$n');

  /// N 周前(arb: weeksAgo = "{n} 周前")。
  String weeksAgo(Object n) => _v['weeksAgo']!.replaceAll('{n}', '$n');

  /// N 个月前(arb: monthsAgo = "{n} 个月前")。
  String monthsAgo(Object n) => _v['monthsAgo']!.replaceAll('{n}', '$n');

  /// 今天(arb: today)。通知/搜索时间桶标题。
  String get today => _v['today']!;

  /// 本周(arb: thisWeek)。通知时间桶标题。
  String get thisWeek => _v['thisWeek']!;

  /// 更早(arb: earlier)。通知/搜索时间桶标题。
  String get earlier => _v['earlier']!;

  // ── 发现页 ──

  /// 发现页顶栏标题(arb: discoverTitle)。
  String get discoverTitle => _v['discoverTitle']!;

  /// 「今日话题」(arb: todayTopic)。
  String get todayTopic => _v['todayTopic']!;

  /// 推荐流 Tab(arb: recommendFeed)。
  String get recommendFeed => _v['recommendFeed']!;

  /// 关注流 Tab(arb: followingFeed)。
  String get followingFeed => _v['followingFeed']!;

  /// 话题广场入口(arb: topicPlaza)。
  String get topicPlaza => _v['topicPlaza']!;

  // ── 看看页 ──

  /// 看看页顶栏标题(arb: kankanTitle)。
  String get kankanTitle => _v['kankanTitle']!;

  /// 榜单更新说明(arb: rankingUpdated)。
  String get rankingUpdated => _v['rankingUpdated']!;

  /// 榜单排序说明(arb: rankingBasis)。
  String get rankingBasis => _v['rankingBasis']!;

  /// 「换一批」(arb: changeBatch)。
  String get changeBatch => _v['changeBatch']!;

  /// 「因为你看过 」(arb: becauseYouViewed)。
  String get becauseYouViewed => _v['becauseYouViewed']!;

  // ── 收藏页 ──

  /// 收藏页顶栏标题(arb: libraryTitle)。
  String get libraryTitle => _v['libraryTitle']!;

  /// 收藏 Tab(arb: savedProjects)。
  String get savedProjects => _v['savedProjects']!;

  /// 素材/拿走 Tab(arb: savedTakeaways)。
  String get savedTakeaways => _v['savedTakeaways']!;

  // ── 我的页 ──

  /// 我的页顶栏标题(arb: meTitle)。
  String get meTitle => _v['meTitle']!;

  /// 「我发布的」(arb: myPosts)。
  String get myPosts => _v['myPosts']!;

  /// 「编辑资料」(arb: editProfile)。
  String get editProfile => _v['editProfile']!;

  /// 「设置」(arb: settings)。
  String get settings => _v['settings']!;

  /// 「退出登录」(arb: logout)。
  String get logout => _v['logout']!;

  /// 「我的贡献」(arb: myContribution)。
  String get myContribution => _v['myContribution']!;

  /// 「我关注的领域」(arb: followedDomains)。
  String get followedDomains => _v['followedDomains']!;

  /// 「我关注的话题」(arb: followedTopics)。
  String get followedTopics => _v['followedTopics']!;

  /// 「最近看过」(arb: recentlyViewed)。
  String get recentlyViewed => _v['recentlyViewed']!;

  /// 「查看全部」(arb: viewAll)。
  String get viewAll => _v['viewAll']!;

  /// 「调整」(me 页「+调整」chip,arb: adjust)。
  String get adjust => _v['adjust']!;

  /// 「清空」(arb: clear)。
  String get clear => _v['clear']!;

  /// 「更换头像」(arb: changeAvatar)。
  String get changeAvatar => _v['changeAvatar']!;

  /// 「登录 / 注册」(arb: loginRegister)。
  String get loginRegister => _v['loginRegister']!;

  // ── 详情页 ──

  /// 「想看怎么做」(arb: wantHowTo)。
  String get wantHowTo => _v['wantHowTo']!;

  /// 「删除这个项目?」(arb: deleteThisProject)。
  String get deleteThisProject => _v['deleteThisProject']!;

  /// 「项目不存在」(arb: projectNotExist)。
  String get projectNotExist => _v['projectNotExist']!;

  /// 「动态不存在或已删除」(arb: postNotExist)。
  String get postNotExist => _v['postNotExist']!;

  /// 「心得」(detail 底栏 / CommentThread header,arb: commentsLabel)。
  String get commentsLabel => _v['commentsLabel']!;

  /// 「拿走」(短,arb: takeaway)。
  String get takeaway => _v['takeaway']!;

  /// 「怎么用」(arb: howToUse)。
  String get howToUse => _v['howToUse']!;

  /// 「代码块」(arb: codeBlock)。
  String get codeBlock => _v['codeBlock']!;

  /// 「视频块」(arb: videoBlock)。
  String get videoBlock => _v['videoBlock']!;

  /// 「文件下载」(arb: fileDownload)。
  String get fileDownload => _v['fileDownload']!;

  /// 「流程对比」(arb: flowCompare)。
  String get flowCompare => _v['flowCompare']!;

  // ── 发布/编辑 ──

  /// 「发动态」(publish_entry_sheet,arb: composePost)。
  String get composePost => _v['composePost']!;

  /// 「发作品」(publish_entry_sheet,arb: publishProject)。
  String get publishProject => _v['publishProject']!;

  /// 「标题」placeholder(arb: titlePlaceholder)。
  String get titlePlaceholder => _v['titlePlaceholder']!;

  /// 「一句话说价值」placeholder(arb: summaryPlaceholder)。
  String get summaryPlaceholder => _v['summaryPlaceholder']!;

  /// 「这一刻的想法…」placeholder(arb: contentPlaceholder)。
  String get contentPlaceholder => _v['contentPlaceholder']!;

  /// 「作者的话」placeholder(arb: authorNotePlaceholder)。
  String get authorNotePlaceholder => _v['authorNotePlaceholder']!;

  /// 「# 话题(回车加)」placeholder(arb: topicPlaceholder)。
  String get topicPlaceholder => _v['topicPlaceholder']!;

  /// 「加素材」(arb: addMaterial)。
  String get addMaterial => _v['addMaterial']!;

  /// 「保存」(profile_edit 顶栏,arb: save)。
  String get saveAction => _v['saveAction']!;

  /// 「恢复」(草稿横条,arb: restore)。
  String get restore => _v['restore']!;

  /// 「忽略」(草稿横条,arb: ignore)。
  String get ignore => _v['ignore']!;

  /// 「恢复上次草稿?」(arb: draftRestore)。
  String get draftRestore => _v['draftRestore']!;

  /// 「引用项目」(compose,arb: quoteProject)。
  String get quoteProject => _v['quoteProject']!;

  /// publish_entry_sheet 发动态副标题(arb: publishHintPost)。
  String get publishHintPost => _v['publishHintPost']!;

  /// publish_entry_sheet 发作品副标题(arb: publishHintProject)。
  String get publishHintProject => _v['publishHintProject']!;

  // ── 搜索 ──

  /// 搜索框 placeholder(arb: searchHint)。
  String get searchHint => _v['searchHint']!;

  /// 「最近搜索」section title(arb: recentSearches)。
  String get recentSearches => _v['recentSearches']!;

  /// 「清空」搜索历史按钮(arb: clearHistory)。与 clear 同义但语义更明确。
  String get clearHistory => _v['clearHistory']!;

  /// 「热门话题」(arb: hotSearch)。
  String get hotSearch => _v['hotSearch']!;

  /// 「暂无」(搜索建议/热门话题空,arb: noResult)。
  String get noResult => _v['noResult']!;

  // ── 评论 ──

  /// 「写评论…」placeholder(arb: writeComment)。
  String get writeComment => _v['writeComment']!;

  /// 「回复」短(arb: replyTo)。
  String get replyTo => _v['replyTo']!;

  /// 「评论已删除」(arb: commentDeleted)。
  String get commentDeleted => _v['commentDeleted']!;

  /// 「已编辑」(arb: commentEdited)。
  String get commentEdited => _v['commentEdited']!;

  // ── 中文(默认)── 与 lib/l10n/app_zh.arb 同步维护。
  static const Map<String, String> _zhValues = <String, String>{
    'appTitle': '看看',
    'discoverTab': '发现',
    'kankanTab': '看看',
    'libraryTab': '收藏',
    'meTab': '我的',
    'publish': '发布',
    'search': '搜索',
    'save': '收藏',
    'like': '点赞',
    'comment': '评论',
    'share': '分享',
    'follow': '关注',
    'unfollow': '已关注',
    'delete': '删除',
    'cancel': '取消',
    'confirm': '确定',
    'retry': '重试',
    'edit': '编辑',
    'copy': '复制',
    'done': '完成',
    'refresh': '刷新',
    'back': '返回',
    'more': '更多',
    'report': '举报',
    'block': '拉黑',
    'loadMore': '加载更多',
    'remove': '移除',
    'clearAll': '清空',
    'ranking': '榜单',
    'loading': '加载中',
    'empty': '空',
    'error': '出错了',
    'offline': '离线',
    'success': '成功',
    'failed': '失败',
    'networkError': '网络异常',
    'emptyFeed': '还没有动态',
    'emptyGeneric': '暂无内容',
    'emptySearch': '没有结果',
    'emptySaved': '还没收藏',
    'emptyTakeaway': '还没存过素材',
    'emptyFollowers': '还没关注',
    'loadFailed': '加载失败',
    'connectFailed': '连不上服务器',
    'errorLoad': '加载失败',
    'errorNetwork': '连不上服务器',
    'retryButton': '重试',
    'projectSemantic': '项目:{title}',
    'postSemantic': '动态:{author}',
    'postCount': '{n} 动态',
    'followerCount': '{n} 粉丝',
    'followingCount': '{n} 关注',
    'likeCount': '{n} 赞',
    'commentCount': '{n} 评论',
    'viewCount': '{n} 浏览',
    'takeawayCount': '{n} 拿走',
    'wantHowToCount': '{n} 人想知道',
    'replyToName': '回复 {name}',
    'justNow': '刚刚',
    'minutesAgo': '{n} 分钟前',
    'hoursAgo': '{n} 小时前',
    'yesterday': '昨天',
    'daysAgo': '{n} 天前',
    'weeksAgo': '{n} 周前',
    'monthsAgo': '{n} 个月前',
    'today': '今天',
    'thisWeek': '本周',
    'earlier': '更早',
    'discoverTitle': '发现',
    'todayTopic': '今日话题',
    'recommendFeed': '推荐',
    'followingFeed': '关注',
    'topicPlaza': '话题广场',
    'kankanTitle': '看看',
    'rankingUpdated': '榜单每小时更新',
    'rankingBasis': '按获赞数排序',
    'changeBatch': '换一批',
    'becauseYouViewed': '因为你看过 ',
    'libraryTitle': '收藏',
    'savedProjects': '收藏',
    'savedTakeaways': '素材',
    'meTitle': '我的',
    'myPosts': '我发布的',
    'editProfile': '编辑资料',
    'settings': '设置',
    'logout': '退出登录',
    'myContribution': '我的贡献',
    'followedDomains': '我关注的领域',
    'followedTopics': '我关注的话题',
    'recentlyViewed': '最近看过',
    'viewAll': '查看全部',
    'adjust': '调整',
    'clear': '清空',
    'changeAvatar': '更换头像',
    'loginRegister': '登录 / 注册',
    'wantHowTo': '想看怎么做',
    'deleteThisProject': '删除这个项目?',
    'projectNotExist': '项目不存在',
    'postNotExist': '动态不存在或已删除',
    'commentsLabel': '心得',
    'takeaway': '拿走',
    'howToUse': '怎么用',
    'codeBlock': '代码块',
    'videoBlock': '视频块',
    'fileDownload': '文件下载',
    'flowCompare': '流程对比',
    'composePost': '发动态',
    'publishProject': '发作品',
    'titlePlaceholder': '标题',
    'summaryPlaceholder': '一句话说价值',
    'contentPlaceholder': '这一刻的想法…',
    'authorNotePlaceholder': '作者的话',
    'topicPlaceholder': '# 话题(回车加)',
    'addMaterial': '加素材',
    'saveAction': '保存',
    'restore': '恢复',
    'ignore': '忽略',
    'draftRestore': '恢复上次草稿?',
    'quoteProject': '引用项目',
    'publishHintPost': '文字 + 图 + 话题 + 引用',
    'publishHintProject': '成果 + 素材',
    'searchHint': '搜索',
    'recentSearches': '最近搜索',
    'clearHistory': '清空',
    'hotSearch': '热门话题',
    'noResult': '暂无',
    'writeComment': '写评论…',
    'replyTo': '回复',
    'commentDeleted': '评论已删除',
    'commentEdited': '已编辑',
  };

  // ── 英文 stub(用户:"未来会用英文,但不准备第一次就上线")──
  // 当前不暴露给用户(app.dart locale 写死 zh)。完整保留 zh 全部 key,
  // 切 en 时一行 locale 改动即生效。文案为 stub,正式上线前需 native speaker 校对。
  // 与 lib/l10n/app_en.arb 同步维护。
  static const Map<String, String> _enValues = <String, String>{
    'appTitle': 'Kankan',
    'discoverTab': 'Discover',
    'kankanTab': 'Kankan',
    'libraryTab': 'Library',
    'meTab': 'Me',
    'publish': 'Publish',
    'search': 'Search',
    'save': 'Save',
    'like': 'Like',
    'comment': 'Comment',
    'share': 'Share',
    'follow': 'Follow',
    'unfollow': 'Following',
    'delete': 'Delete',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'retry': 'Retry',
    'edit': 'Edit',
    'copy': 'Copy',
    'done': 'Done',
    'refresh': 'Refresh',
    'back': 'Back',
    'more': 'More',
    'report': 'Report',
    'block': 'Block',
    'loadMore': 'Load more',
    'remove': 'Remove',
    'clearAll': 'Clear all',
    'ranking': 'Rankings',
    'loading': 'Loading',
    'empty': 'Empty',
    'error': 'Error',
    'offline': 'Offline',
    'success': 'Success',
    'failed': 'Failed',
    'networkError': 'Network error',
    'emptyFeed': 'Nothing here yet',
    'emptyGeneric': 'Nothing here',
    'emptySearch': 'No results',
    'emptySaved': 'Nothing saved yet',
    'emptyTakeaway': 'No saved takeaways yet',
    'emptyFollowers': 'Not following anyone yet',
    'loadFailed': 'Failed to load',
    'connectFailed': 'Cannot reach server',
    'errorLoad': 'Failed to load',
    'errorNetwork': 'Cannot reach server',
    'retryButton': 'Retry',
    'projectSemantic': 'Project: {title}',
    'postSemantic': 'Post: {author}',
    'postCount': '{n} posts',
    'followerCount': '{n} followers',
    'followingCount': '{n} following',
    'likeCount': '{n} likes',
    'commentCount': '{n} comments',
    'viewCount': '{n} views',
    'takeawayCount': '{n} takeaways',
    'wantHowToCount': '{n} want to know',
    'replyToName': 'Reply to {name}',
    'justNow': 'Just now',
    'minutesAgo': '{n} min ago',
    'hoursAgo': '{n} hr ago',
    'yesterday': 'Yesterday',
    'daysAgo': '{n} days ago',
    'weeksAgo': '{n} weeks ago',
    'monthsAgo': '{n} months ago',
    'today': 'Today',
    'thisWeek': 'This week',
    'earlier': 'Earlier',
    'discoverTitle': 'Discover',
    'todayTopic': "Today's topics",
    'recommendFeed': 'For you',
    'followingFeed': 'Following',
    'topicPlaza': 'Topics',
    'kankanTitle': 'Kankan',
    'rankingUpdated': 'Updated hourly',
    'rankingBasis': 'Sorted by likes',
    'changeBatch': 'Shuffle',
    'becauseYouViewed': 'Because you viewed ',
    'libraryTitle': 'Library',
    'savedProjects': 'Saved',
    'savedTakeaways': 'Takeaways',
    'meTitle': 'Me',
    'myPosts': 'My posts',
    'editProfile': 'Edit profile',
    'settings': 'Settings',
    'logout': 'Log out',
    'myContribution': 'My contribution',
    'followedDomains': 'Domains I follow',
    'followedTopics': 'Topics I follow',
    'recentlyViewed': 'Recently viewed',
    'viewAll': 'View all',
    'adjust': 'Adjust',
    'clear': 'Clear',
    'changeAvatar': 'Change avatar',
    'loginRegister': 'Log in / Sign up',
    'wantHowTo': 'How to make it',
    'deleteThisProject': 'Delete this project?',
    'projectNotExist': 'Project not found',
    'postNotExist': 'Post does not exist or has been deleted',
    'commentsLabel': 'Notes',
    'takeaway': 'Take',
    'howToUse': 'How to use',
    'codeBlock': 'Code',
    'videoBlock': 'Video',
    'fileDownload': 'File download',
    'flowCompare': 'Flow comparison',
    'composePost': 'New post',
    'publishProject': 'New project',
    'titlePlaceholder': 'Title',
    'summaryPlaceholder': 'One-line value',
    'contentPlaceholder': "What's on your mind…",
    'authorNotePlaceholder': "Author's note",
    'topicPlaceholder': '# Topic (press Enter)',
    'addMaterial': 'Add takeaway',
    'saveAction': 'Save',
    'restore': 'Restore',
    'ignore': 'Dismiss',
    'draftRestore': 'Restore last draft?',
    'quoteProject': 'Quote project',
    'publishHintPost': 'Text + images + topics + quote',
    'publishHintProject': 'Outcomes + takeaways',
    'searchHint': 'Search',
    'recentSearches': 'Recent searches',
    'clearHistory': 'Clear',
    'hotSearch': 'Trending topics',
    'noResult': 'None',
    'writeComment': 'Write a comment…',
    'replyTo': 'Reply',
    'commentDeleted': 'Comment deleted',
    'commentEdited': 'Edited',
  };
}

/// P2-i18n:当前 locale provider。
///
/// 当前写死 zh(用户:"未来会用英文,但不准备第一次就上线")。
/// 切英文上线时:
///   1) 接 settings 层的 toggleProvider 改这里(如 `StateProvider<Locale>`);
///   2) app.dart 的 locale 改 `ref.watch(kkLocaleProvider)`;
///   3) [kkStringsProvider] 自动重算 → 全 UI 切 en。
final kkLocaleProvider = Provider<Locale>((ref) => const Locale('zh'));

/// P2-i18n:字符串 SSOT provider。按当前 locale 返回对应 [KkStrings]。
///
/// 用法:`final s = ref.watch(kkStringsProvider); s.discoverTab`。
///
/// 切 gen-l10n 时:删本文件,调用方改为
/// `AppLocalizations.of(context)!.discoverTab`。
final kkStringsProvider = Provider<KkStrings>((ref) {
  final locale = ref.watch(kkLocaleProvider);
  return locale.languageCode == 'en' ? KkStrings.en() : KkStrings.zh();
});
