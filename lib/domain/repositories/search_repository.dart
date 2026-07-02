import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/seed/mock_seed.dart';
import '../../domain/models/models.dart';

/// 搜索 Repository — HANDOFF §6.2 真实 tags 索引 + 修复 Web 版两个 bug。
///
/// Web 版重灾区(规划文档 §7.5 阶段 4 验收项):
///   1. hashtag 跳空:点 #tag 没去 topic 页,而是丢回搜索框
///   2. 自发项目堵死:搜到 Post.quoteProjectId 是 null 的纯动态,
///      点了无去处(应该跳 post-detail,不是 detail)
///
/// Flutter 端从零做对:
///   - 搜项目:匹配 title / summary / tags / authorName(模糊 contains,不分大小写)
///   - 搜动态:匹配 content / tags / authorName
///   - 搜用户:匹配 name / bio
///   - 搜话题:匹配 tag,聚合真实 projectCount / postCount / totalLikes
///
/// 计数铁律(HANDOFF §6.10):所有结果数取真实数组长度,不放大。
class SearchRepository {
  final List<Project> _projects;
  final List<Post> _posts;
  final List<KkUser> _users;

  SearchRepository(this._projects, this._posts, this._users);

  /// 搜项目(title / summary / tags / authorName)
  List<Project> searchProjects(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return const [];
    final authorCache = {for (final u in _users) u.id: u.name};
    return _projects.where((p) {
      final author = authorCache[p.authorId]?.toLowerCase() ?? '';
      return p.title.toLowerCase().contains(s) ||
          p.summary.toLowerCase().contains(s) ||
          p.tags.any((t) => t.toLowerCase().contains(s)) ||
          author.contains(s);
    }).toList()
      ..sort((a, b) => b.likes.compareTo(a.likes));
  }

  /// 搜动态(content / tags / authorName)
  List<Post> searchPosts(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return const [];
    final authorCache = {for (final u in _users) u.id: u.name};
    return _posts.where((p) {
      final author = authorCache[p.authorId]?.toLowerCase() ?? '';
      return p.content.toLowerCase().contains(s) ||
          p.tags.any((t) => t.toLowerCase().contains(s)) ||
          author.contains(s);
    }).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  /// 搜用户(name / bio)
  List<KkUser> searchUsers(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return const [];
    return _users.where((u) {
      return u.name.toLowerCase().contains(s) ||
          (u.bio?.toLowerCase().contains(s) ?? false);
    }).toList();
  }

  /// 搜话题(tag 模糊匹配,聚合真实计数)
  /// HANDOFF §6.10 真实 heat:projectCount × 10 + postCount × 5 + totalLikes ÷ 100
  List<Topic> searchTopics(String q) {
    final s = q.trim().toLowerCase();
    // 聚合所有 tag
    final tagSet = <String>{};
    for (final p in _projects) {
      tagSet.addAll(p.tags);
    }
    for (final p in _posts) {
      tagSet.addAll(p.tags);
    }
    final matched = s.isEmpty
        ? tagSet.toList()
        : tagSet.where((t) => t.toLowerCase().contains(s)).toList();

    return matched.map((tag) {
      final projects = _projects.where((p) => p.tags.contains(tag)).toList();
      final posts = _posts.where((p) => p.tags.contains(tag)).toList();
      final totalLikes = projects.fold<int>(0, (s, p) => s + p.likes) +
          posts.fold<int>(0, (s, p) => s + p.likes);
      // 真实热度加权(非 ×N 编造,是聚合计算)
      final heat = projects.length * 10 + posts.length * 5 + totalLikes ~/ 100;
      return Topic(
        tag: tag,
        heat: heat,
        projectCount: projects.length,
        postCount: posts.length,
        totalLikes: totalLikes,
      );
    }).toList()
      ..sort((a, b) => b.heat.compareTo(a.heat));
  }

  /// 综合 4 类结果数(给 search 屏顶部 tab badge 用)
  SearchCounts counts(String q) {
    return SearchCounts(
      projects: searchProjects(q).length,
      posts: searchPosts(q).length,
      users: searchUsers(q).length,
      topics: searchTopics(q).length,
    );
  }
}

class SearchCounts {
  final int projects;
  final int posts;
  final int users;
  final int topics;
  const SearchCounts({
    required this.projects,
    required this.posts,
    required this.users,
    required this.topics,
  });
  int get total => projects + posts + users + topics;
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(mockProjects, mockPosts, mockUsers);
});
