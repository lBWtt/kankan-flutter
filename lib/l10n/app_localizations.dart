import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you'll need to edit this
/// file.
///
/// First, open your project's ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project's Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// App 名称(MaterialApp.title、顶栏标题)。
  ///
  /// In zh, this message translates to:
  /// **'看看'**
  String get appTitle;

  /// 底栏 Tab 1:发现页。
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get discoverTab;

  /// 底栏 Tab 2:项目 feed。
  ///
  /// In zh, this message translates to:
  /// **'看看'**
  String get kankanTab;

  /// 底栏 Tab 3:内容库。
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get libraryTab;

  /// 底栏 Tab 4:个人页。
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get meTab;

  /// 发布动作(FAB、发布入口 sheet 标题)。
  ///
  /// In zh, this message translates to:
  /// **'发布'**
  String get publish;

  /// 搜索动作(顶栏搜索图标 semanticLabel、搜索页标题)。
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// 收藏动作(项目卡收藏按钮 semanticLabel)。
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get save;

  /// 点赞动作(动态/项目卡点赞按钮 semanticLabel)。
  ///
  /// In zh, this message translates to:
  /// **'点赞'**
  String get like;

  /// 评论动作(动态/项目卡评论按钮 semanticLabel)。
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get comment;

  /// 分享动作(详情页分享按钮 semanticLabel)。
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// 关注作者按钮(未关注态)。
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get follow;

  /// 关注作者按钮(已关注态)。
  ///
  /// In zh, this message translates to:
  /// **'已关注'**
  String get unfollow;

  /// 删除动作(拿走物长按菜单等)。
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// 取消(sheet 末项、对话框)。
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// 确认对话框主按钮。
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// 错误态重试按钮(RemoteError)。
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// 编辑动作(资料、评论 own 等)。
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// 复制动作(代码块、文本 take 等)。
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// 完成动作(对话框、输入完成等)。
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// 刷新动作(下拉刷新提示、推荐条「换一批」图标 alt)。
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// 返回动作(返回按钮 semanticLabel、post_detail 返回按钮文字)。
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// 更多动作(顶栏 more_horiz 图标 semanticLabel)。
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// 举报动作(more sheet 举报项)。
  ///
  /// In zh, this message translates to:
  /// **'举报'**
  String get report;

  /// 拉黑作者动作(profile more sheet)。
  ///
  /// In zh, this message translates to:
  /// **'拉黑'**
  String get block;

  /// 加载更多文案(无限滚动底部指示器)。
  ///
  /// In zh, this message translates to:
  /// **'加载更多'**
  String get loadMore;

  /// 移除动作(chip × 关闭按钮 semanticLabel)。
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// 清空动作(历史/缓存的 section action)。
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearAll;

  /// 看看页顶栏榜单图标 semanticLabel。
  ///
  /// In zh, this message translates to:
  /// **'榜单'**
  String get ranking;

  /// 加载中文案。
  ///
  /// In zh, this message translates to:
  /// **'加载中'**
  String get loading;

  /// 空通用文案(极短)。
  ///
  /// In zh, this message translates to:
  /// **'空'**
  String get empty;

  /// 通用错误文案(极短)。
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get error;

  /// 离线状态文案。
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get offline;

  /// 操作成功 snackbar 兜底。
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get success;

  /// 操作失败 snackbar 兜底。
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failed;

  /// 网络异常 snackbar/错误态文案。
  ///
  /// In zh, this message translates to:
  /// **'网络异常'**
  String get networkError;

  /// feed 空状态(发现页推荐/关注流)。
  ///
  /// In zh, this message translates to:
  /// **'还没有动态'**
  String get emptyFeed;

  /// 通用空状态(EmptyState generic variant,看看无项目/topic 空等)。
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get emptyGeneric;

  /// 搜索结果空状态。
  ///
  /// In zh, this message translates to:
  /// **'没有结果'**
  String get emptySearch;

  /// 收藏空状态(EmptyState saved variant 标题)。
  ///
  /// In zh, this message translates to:
  /// **'还没收藏'**
  String get emptySaved;

  /// 拿走物空状态(EmptyState takeaway variant 标题)。
  ///
  /// In zh, this message translates to:
  /// **'还没存过素材'**
  String get emptyTakeaway;

  /// 关注列表空状态(EmptyState followers variant 标题)。
  ///
  /// In zh, this message translates to:
  /// **'还没关注'**
  String get emptyFollowers;

  /// 加载失败兜底文案。
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// 远程数据加载失败文案(RemoteError message)。
  ///
  /// In zh, this message translates to:
  /// **'连不上服务器'**
  String get connectFailed;

  /// 加载失败通用文案(RemoteError 默认 message)。
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get errorLoad;

  /// 网络错误文案(分页 feed 首屏失败)。
  ///
  /// In zh, this message translates to:
  /// **'连不上服务器'**
  String get errorNetwork;

  /// 错误态重试按钮文字(RemoteError 内部按钮)。
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retryButton;

  /// 项目卡整体无障碍标签(读屏念「项目:标题」)。占位符 {title} 替换为项目标题。
  ///
  /// In zh, this message translates to:
  /// **'项目:{title}'**
  String projectSemantic(Object title);

  /// 动态卡整体无障碍标签。占位符 {author} 替换为作者名。
  ///
  /// In zh, this message translates to:
  /// **'动态:{author}'**
  String postSemantic(Object author);

  /// 动态计数文案(profile tab、topic tile 计数行)。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 动态'**
  String postCount(Object n);

  /// 粉丝计数文案。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 粉丝'**
  String followerCount(Object n);

  /// 关注计数文案。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 关注'**
  String followingCount(Object n);

  /// 点赞计数文案(me/profile/推荐小卡)。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 赞'**
  String likeCount(Object n);

  /// 评论计数文案。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 评论'**
  String commentCount(Object n);

  /// 浏览计数文案。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 浏览'**
  String viewCount(Object n);

  /// 拿走计数文案。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 拿走'**
  String takeawayCount(Object n);

  /// 「N 人想知道」计数(详情页 clue 入口)。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 人想知道'**
  String wantHowToCount(Object n);

  /// 「回复 {name}」评论输入框 placeholder。占位符 {name} 替换为被回复者昵称。
  ///
  /// In zh, this message translates to:
  /// **'回复 {name}'**
  String replyToName(Object name);

  /// 时间相对文案「刚刚」(time_ago 对齐)。
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get justNow;

  /// 时间相对文案「N 分钟前」。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 分钟前'**
  String minutesAgo(Object n);

  /// 时间相对文案「N 小时前」。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 小时前'**
  String hoursAgo(Object n);

  /// 时间相对文案「昨天」(也用作通知/搜索时间桶标题)。
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterday;

  /// 时间相对文案「N 天前」。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 天前'**
  String daysAgo(Object n);

  /// 时间相对文案「N 周前」。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 周前'**
  String weeksAgo(Object n);

  /// 时间相对文案「N 个月前」。占位符 {n} 替换为整数。
  ///
  /// In zh, this message translates to:
  /// **'{n} 个月前'**
  String monthsAgo(Object n);

  /// 时间桶标题「今天」(通知/搜索)。
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get today;

  /// 时间桶标题「本周」(通知)。
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get thisWeek;

  /// 时间桶标题「更早」(通知/搜索)。
  ///
  /// In zh, this message translates to:
  /// **'更早'**
  String get earlier;

  /// 发现页顶栏标题。
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get discoverTitle;

  /// 发现页推荐流顶部「今日话题」横条标题。
  ///
  /// In zh, this message translates to:
  /// **'今日话题'**
  String get todayTopic;

  /// 发现页推荐流 Tab 标签。
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get recommendFeed;

  /// 发现页关注流 Tab 标签。
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get followingFeed;

  /// 话题广场入口(发现页 + 话题广场屏标题)。
  ///
  /// In zh, this message translates to:
  /// **'话题广场'**
  String get topicPlaza;

  /// 看看页顶栏标题。
  ///
  /// In zh, this message translates to:
  /// **'看看'**
  String get kankanTitle;

  /// 榜单页更新说明。
  ///
  /// In zh, this message translates to:
  /// **'榜单每小时更新'**
  String get rankingUpdated;

  /// 榜单页排序说明。
  ///
  /// In zh, this message translates to:
  /// **'按获赞数排序'**
  String get rankingBasis;

  /// 「换一批」推荐条刷新按钮(看看页 _RecommendStrip)。
  ///
  /// In zh, this message translates to:
  /// **'换一批'**
  String get changeBatch;

  /// 「因为你看过 X」推荐条前缀(末尾空格便于拼接项目标题)。
  ///
  /// In zh, this message translates to:
  /// **'因为你看过 '**
  String get becauseYouViewed;

  /// 收藏页顶栏标题。
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get libraryTitle;

  /// 收藏页 Tab 1 标签(收藏的项目)。
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get savedProjects;

  /// 收藏页 Tab 2 标签(我拿走的素材)。
  ///
  /// In zh, this message translates to:
  /// **'素材'**
  String get savedTakeaways;

  /// 我的页顶栏标题(目前未显式渲染,banner 上方留白)。
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get meTitle;

  /// 我的页「我发布的」section 标题。
  ///
  /// In zh, this message translates to:
  /// **'我发布的'**
  String get myPosts;

  /// 编辑资料按钮/标题(me、profile、profile_edit)。
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get editProfile;

  /// 设置入口/设置页标题。
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// 退出登录动作(more sheet、settings)。
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// 我的页「我的贡献」卡片标题。
  ///
  /// In zh, this message translates to:
  /// **'我的贡献'**
  String get myContribution;

  /// 我的页「我关注的领域」section 标题。
  ///
  /// In zh, this message translates to:
  /// **'我关注的领域'**
  String get followedDomains;

  /// 我的页「我关注的话题」section 标题。
  ///
  /// In zh, this message translates to:
  /// **'我关注的话题'**
  String get followedTopics;

  /// 我的页「最近看过」section 标题。
  ///
  /// In zh, this message translates to:
  /// **'最近看过'**
  String get recentlyViewed;

  /// 「查看全部」section action(我发布的)。
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get viewAll;

  /// 「+调整」chip 文字(我关注的领域末尾幽灵 chip)。
  ///
  /// In zh, this message translates to:
  /// **'调整'**
  String get adjust;

  /// 「清空」section action(最近看过/通知全部已读外的清空入口)。
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// profile_edit 头像区「更换头像」按钮。
  ///
  /// In zh, this message translates to:
  /// **'更换头像'**
  String get changeAvatar;

  /// 未登录态的「登录 / 注册」入口(me / settings)。
  ///
  /// In zh, this message translates to:
  /// **'登录 / 注册'**
  String get loginRegister;

  /// 详情页 clue 入口标题文字。
  ///
  /// In zh, this message translates to:
  /// **'想看怎么做'**
  String get wantHowTo;

  /// 详情页删除自己项目的二次确认对话框内容。
  ///
  /// In zh, this message translates to:
  /// **'删除这个项目?'**
  String get deleteThisProject;

  /// 详情页加载项目为 null 时的兜底文案。
  ///
  /// In zh, this message translates to:
  /// **'项目不存在'**
  String get projectNotExist;

  /// 动态详情页加载 post 为 null 时的 EmptyState title。
  ///
  /// In zh, this message translates to:
  /// **'动态不存在或已删除'**
  String get postNotExist;

  /// 「心得」短文案(详情页底栏「心得 N」前缀,CommentThread header)。
  ///
  /// In zh, this message translates to:
  /// **'心得'**
  String get commentsLabel;

  /// 「拿走」短文案(action chip 兜底 label)。
  ///
  /// In zh, this message translates to:
  /// **'拿走'**
  String get takeaway;

  /// 「怎么用」action chip 兜底 label。
  ///
  /// In zh, this message translates to:
  /// **'怎么用'**
  String get howToUse;

  /// 「代码块」io block 标题。
  ///
  /// In zh, this message translates to:
  /// **'代码块'**
  String get codeBlock;

  /// 「视频块」io block 标题。
  ///
  /// In zh, this message translates to:
  /// **'视频块'**
  String get videoBlock;

  /// 「文件下载」action chip 兜底 label。
  ///
  /// In zh, this message translates to:
  /// **'文件下载'**
  String get fileDownload;

  /// 「流程对比」io block 标题。
  ///
  /// In zh, this message translates to:
  /// **'流程对比'**
  String get flowCompare;

  /// publish_entry_sheet 发动态入口标题。
  ///
  /// In zh, this message translates to:
  /// **'发动态'**
  String get composePost;

  /// publish_entry_sheet 发作品入口标题(原「发作品(项目)」简化)。
  ///
  /// In zh, this message translates to:
  /// **'发作品'**
  String get publishProject;

  /// publish 屏标题输入框 placeholder。
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get titlePlaceholder;

  /// publish 屏一句话价值输入框 placeholder。
  ///
  /// In zh, this message translates to:
  /// **'一句话说价值'**
  String get summaryPlaceholder;

  /// compose 屏正文输入框 placeholder。
  ///
  /// In zh, this message translates to:
  /// **'这一刻的想法…'**
  String get contentPlaceholder;

  /// publish 屏作者的话输入框 placeholder。
  ///
  /// In zh, this message translates to:
  /// **'作者的话'**
  String get authorNotePlaceholder;

  /// publish 屏标签输入框 placeholder。
  ///
  /// In zh, this message translates to:
  /// **'# 话题(回车加)'**
  String get topicPlaceholder;

  /// publish 屏「+ 加素材」按钮。
  ///
  /// In zh, this message translates to:
  /// **'加素材'**
  String get addMaterial;

  /// 保存动作(profile_edit 顶栏「保存」按钮)。
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get saveAction;

  /// 草稿横条「恢复」按钮。
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// 草稿横条「忽略」按钮。
  ///
  /// In zh, this message translates to:
  /// **'忽略'**
  String get ignore;

  /// 草稿恢复横条主文案。
  ///
  /// In zh, this message translates to:
  /// **'恢复上次草稿?'**
  String get draftRestore;

  /// compose 屏「引用项目」section / sheet 标题。
  ///
  /// In zh, this message translates to:
  /// **'引用项目'**
  String get quoteProject;

  /// publish_entry_sheet 发动态入口副标题。
  ///
  /// In zh, this message translates to:
  /// **'文字 + 图 + 话题 + 引用'**
  String get publishHintPost;

  /// publish_entry_sheet 发作品入口副标题。
  ///
  /// In zh, this message translates to:
  /// **'成果 + 素材'**
  String get publishHintProject;

  /// 搜索框 placeholder。
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchHint;

  /// 搜索页「最近搜索」section 标题。
  ///
  /// In zh, this message translates to:
  /// **'最近搜索'**
  String get recentSearches;

  /// 搜索页「清空」搜索历史按钮。
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearHistory;

  /// 搜索页「热门话题」section 标题。
  ///
  /// In zh, this message translates to:
  /// **'热门话题'**
  String get hotSearch;

  /// 搜索建议空、热门话题空时的兜底文案。
  ///
  /// In zh, this message translates to:
  /// **'暂无'**
  String get noResult;

  /// 评论输入框 placeholder。
  ///
  /// In zh, this message translates to:
  /// **'写评论…'**
  String get writeComment;

  /// 「回复」短文案(评论 action)。
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get replyTo;

  /// 评论被删除后的占位文案。
  ///
  /// In zh, this message translates to:
  /// **'评论已删除'**
  String get commentDeleted;

  /// 评论被编辑后的「已编辑」标记。
  ///
  /// In zh, this message translates to:
  /// **'已编辑'**
  String get commentEdited;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
