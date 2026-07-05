import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/repositories/project_repository.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/project_provider.dart';
import '../../router/routes.dart';
import '../shared/empty_state.dart';
import '../shared/post_card.dart';
import '../shared/profile_header.dart';
import '../shared/project_card.dart';
import '../shared/report_sheet.dart';

/// 个人主页屏 — HANDOFF §6.5 真路由 + 三 Tab + 关注/拉黑/举报。
///
/// 三 Tab:
///   - 动态  PostRepository.byAuthor(userId)
///   - 项目  ProjectRepository.byAuthor(userId)
///   - 收藏  该用户收藏的项目(自己:appState.savedProjectIds;
///           他人:mock 假设几个,真实场景后端查)
///
/// 顶栏:
///   - 头像(点击大图,Phase 4)/ 名字 / 简介 / 关注/粉丝/获赞(真实)
///   - 关注按钮(他人)或编辑资料按钮(自己,Phase 4 跳 profile-edit)
///   - 更多按钮(拉黑/举报 action sheet)
///
/// 计数铁律(HANDOFF §6.10):所有数字取真实数组长度。
/// 零旁白(HANDOFF §3):空状态用 EmptyState。
class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _isMe => widget.userId == 'me';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userByIdProvider(widget.userId));
    final projectRepo = ref.watch(projectRepositoryProvider);
    final postRepo = ref.watch(postRepositoryProvider);
    final appState = ref.watch(appStateProvider);

    final projects = projectRepo.byAuthor(widget.userId);
    final posts = postRepo.byAuthor(widget.userId);
    final following = (user?.followingIds ?? const <String>[]).length;
    final followers = (user?.followerIds ?? const <String>[]).length;
    final totalLikes =
        projects.fold<int>(0, (s, p) => s + p.likes) +
            posts.fold<int>(0, (s, p) => s + p.likes);
    final isFollowing = appState.followedUserIds.contains(widget.userId);

    return Scaffold(
      backgroundColor: KkColors.bg,
      // 任务⑩A:头部对齐 me_screen 视觉语言(渐变 banner + 大头像 + inline 统计)。
      // 不用 AppBar(会盖住 banner 渐变),返回/更多按钮浮在 banner 右上角。
      body: Column(
        children: [
          // 头部:ProfileHeader(banner + 大头像 + 名字 + banner 右上槽 +
          // inline 统计行 关注/粉丝/获赞 + 右侧关注/编辑按钮)
          ProfileHeader(
            user: user,
            userId: widget.userId,
            followingCount: following,
            followerCount: followers,
            totalLikes: totalLikes,
            onTapFollowing: () =>
                context.push(KkRoutes.follows(widget.userId)),
            onTapFollowers: () => context.push(
                '${KkRoutes.follows(widget.userId)}?type=followers'),
            bannerActions: [
              // 返回(浮在 banner 上,半透明白底圆)
              BannerIconButton(
                icon: Icons.arrow_back,
                onTap: () {
                  // 兜底同 KkBackButton:profile 可深链(/u/:id),栈空时 pop 哑火 → 回发现页。
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(KkRoutes.discover);
                  }
                },
              ),
              // 更多(拉黑/举报 sheet)
              BannerIconButton(
                icon: Icons.more_horiz,
                onTap: () => _showMoreSheet(context),
              ),
            ],
            // 右侧操作槽:自己 → 编辑资料;他人 → 关注/已关注
            actionSlot: _isMe ? _editButton() : _followButton(isFollowing),
          ),
          const SizedBox(height: KkSpacing.sm),
          // Tab 栏
          _tabBar(projects.length, posts.length),
          // Tab 内容
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PostsTab(userId: widget.userId),
                _ProjectsTab(userId: widget.userId),
                _SavedTab(userId: widget.userId, isMe: _isMe),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 任务⑩A:旧 _profileCard / _countBlock 已删,头部复用共享 ProfileHeader
  // (渐变 banner + 大头像 + inline 统计 + 右侧关注/编辑按钮)。

  Widget _followButton(bool isFollowing) {
    return Tappable(
      onTap: () => ref
          .read(appStateProvider.notifier)
          .toggleFollow(widget.userId),
      borderRadius: BorderRadius.circular(KkRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.xl,
          vertical: KkSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isFollowing ? KkColors.bgSubtle : KkColors.teal,
          borderRadius: BorderRadius.circular(KkRadius.pill),
          border: isFollowing ? Border.all(color: KkColors.bd) : null,
        ),
        child: Text(
          isFollowing ? '已关注' : '关注',
          style: TextStyle(
            color: isFollowing ? KkColors.t2 : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'NotoSerifSC',
          ),
        ),
      ),
    );
  }

  Widget _editButton() {
    return Tappable(
      onTap: () => context.push(KkRoutes.profileEdit),
      borderRadius: BorderRadius.circular(KkRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.xl,
          vertical: KkSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: KkColors.bgSubtle,
          borderRadius: BorderRadius.circular(KkRadius.pill),
          border: Border.all(color: KkColors.bd),
        ),
        child: Text(
          '编辑资料',
          style: TextStyle(
            color: KkColors.t2,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'NotoSerifSC',
          ),
        ),
      ),
    );
  }

  Widget _tabBar(int projectCount, int postCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KkSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KkColors.divider)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: KkColors.t1,
        unselectedLabelColor: KkColors.t3,
        labelStyle: KkType.body.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: KkType.body,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: KkColors.teal,
        indicatorWeight: 2,
        tabs: [
          Tab(text: '动态 $postCount'),
          Tab(text: '项目 $projectCount'),
          const Tab(text: '收藏'),
        ],
      ),
    );
  }

  /// 更多操作 sheet(拉黑 / 举报)
  /// HANDOFF §3 零旁白:不写"举报后会怎样",只列动作。
  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KkColors.bgCard,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isMe) ...[
              _sheetItem(
                icon: Icons.edit_outlined,
                label: '编辑资料',
                onTap: () {
                  Navigator.pop(context);
                  context.push(KkRoutes.profileEdit);
                },
              ),
              const Divider(height: 1, color: KkColors.divider, indent: 56),
              // HANDOFF §5:珊瑚橙只给 take。破坏性操作用 t1 深色 + 字重,
              // 不用珊瑚橙(避免视觉与 take 混淆)。
              _sheetItem(
                icon: Icons.logout_outlined,
                label: '退出登录',
                color: KkColors.t1,
                weight: FontWeight.w600,
                onTap: () => Navigator.pop(context),
              ),
            ] else ...[
              _sheetItem(
                icon: Icons.person_remove_outlined,
                label: '拉黑',
                color: KkColors.t1,
                weight: FontWeight.w600,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('已拉黑'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: KkColors.t1,
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: KkColors.divider, indent: 56),
              _sheetItem(
                icon: Icons.flag_outlined,
                label: '举报',
                color: KkColors.t1,
                weight: FontWeight.w600,
                onTap: () {
                  Navigator.pop(context);
                  showReportSheet(
                    context,
                    targetType: 'user',
                    targetId: widget.userId,
                  );
                },
              ),
            ],
            const Divider(height: 1, color: KkColors.divider),
            _sheetItem(
              icon: Icons.close,
              label: '取消',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem({
    required IconData icon,
    required String label,
    Color? color,
    FontWeight? weight,
    VoidCallback? onTap,
  }) {
    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.md,
          vertical: KkSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? KkColors.t2),
            const SizedBox(width: KkSpacing.md),
            Text(
              label,
              style: KkType.body.copyWith(
                color: color ?? KkColors.t1,
                fontWeight: weight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// 动态 Tab
// ──────────────────────────────────────────────────────────────────

class _PostsTab extends ConsumerWidget {
  final String userId;
  const _PostsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    final posts = repo.byAuthor(userId)
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    if (posts.isEmpty) {
      return ListView(
        children: const [EmptyState(variant: EmptyStateVariant.feed)],
      );
    }
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, i) => PostCard(
        post: posts[i],
        onTap: () => context.push(KkRoutes.postDetail(posts[i].id)),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// 项目 Tab
// ──────────────────────────────────────────────────────────────────

class _ProjectsTab extends ConsumerWidget {
  final String userId;
  const _ProjectsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(projectRepositoryProvider);
    final projects = repo.byAuthor(userId)
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    if (projects.isEmpty) {
      return ListView(
        children: const [EmptyState(variant: EmptyStateVariant.generic)],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        KkSpacing.lg, KkSpacing.sm, KkSpacing.lg, KkSpacing.xxl),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: KkSpacing.md),
      itemBuilder: (context, i) =>
          ProjectCard(project: projects[i], showAuthor: false),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// 收藏 Tab
// ──────────────────────────────────────────────────────────────────

class _SavedTab extends ConsumerWidget {
  final String userId;
  final bool isMe;
  const _SavedTab({required this.userId, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(projectRepositoryProvider);
    final appState = ref.watch(appStateProvider);

    // 自己:从 appState.savedProjectIds 读真实收藏
    // 他人:mock 假设展示该用户最近发的 2 个项目作为"收藏"
    //   (真实场景后端查 savedProject 表,Phase 5 接 Drift)
    final saved = isMe
        ? repo.all().where((p) => appState.savedProjectIds.contains(p.id)).toList()
        : repo.byAuthor(userId).take(2).toList();

    if (saved.isEmpty) {
      return ListView(
        children: const [EmptyState(variant: EmptyStateVariant.saved)],
      );
    }
    return ListView.builder(
      itemCount: saved.length,
      itemBuilder: (context, i) =>
          ProjectCard(project: saved[i], compact: true),
    );
  }
}
