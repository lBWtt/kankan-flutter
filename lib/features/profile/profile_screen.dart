import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/kk_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/parse_count.dart';
import '../../core/widgets/kk_back_button.dart';
import '../../core/widgets/tappable.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/repositories/project_repository.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/project_provider.dart';
import '../../router/routes.dart';
import '../shared/avatar.dart';
import '../shared/empty_state.dart';
import '../shared/post_card.dart';
import '../shared/project_card.dart';

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
      appBar: AppBar(
        backgroundColor: KkColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const KkBackButton(),
        titleSpacing: 0,
        title: Text(
          user?.name ?? widget.userId,
          style: KkType.h3,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Tappable(
            onTap: () => _showMoreSheet(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: KkSpacing.lg),
              child: Icon(Icons.more_horiz, size: 22, color: KkColors.t1),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 个人信息卡
          _profileCard(
            user: user,
            following: following,
            followers: followers,
            totalLikes: totalLikes,
            isFollowing: isFollowing,
          ),
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

  Widget _profileCard({
    required KkUser? user,
    required int following,
    required int followers,
    required int totalLikes,
    required bool isFollowing,
  }) {
    return Container(
      margin: const EdgeInsets.all(KkSpacing.lg),
      padding: const EdgeInsets.all(KkSpacing.lg),
      decoration: BoxDecoration(
        color: KkColors.bgCard,
        borderRadius: BorderRadius.circular(KkRadius.lg),
        border: Border.all(color: KkColors.bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              KkAvatar(userId: widget.userId, user: user, size: 64),
              const SizedBox(width: KkSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.name ?? widget.userId,
                      style: KkType.h2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.bio!,
                        style: KkType.bodySm.copyWith(color: KkColors.t3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KkSpacing.lg),
          // 真实数字三档(等宽)
          Row(
            children: [
              Tappable(
                onTap: () =>
                    context.push(KkRoutes.follows(widget.userId)),
                child: _countBlock('关注', following),
              ),
              const SizedBox(width: KkSpacing.xxl),
              Tappable(
                onTap: () => context.push(
                    '${KkRoutes.follows(widget.userId)}?type=followers'),
                child: _countBlock('粉丝', followers),
              ),
              const SizedBox(width: KkSpacing.xxl),
              _countBlock('获赞', totalLikes),
              const Spacer(),
              // 关注 / 编辑按钮
              if (_isMe)
                _editButton()
              else
                _followButton(isFollowing),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countBlock(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatCount(value), style: KkType.monoLg),
        Text(
          label,
          style: KkType.bodySm.copyWith(color: KkColors.t3, fontSize: 11),
        ),
      ],
    );
  }

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
                onTap: () => Navigator.pop(context),
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
