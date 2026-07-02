import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/project_repository.dart';
import '../domain/models/models.dart';

/// 按 ID 取单个 Project(family provider)。
///
/// detail 页用法:final project = ref.watch(projectByIdProvider(projectId));
final projectByIdProvider =
    FutureProvider.family<Project?, String>((ref, id) async {
  final repo = ref.watch(projectRepositoryProvider);
  // 模拟异步(Phase 5 接 Drift 时是真异步)
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return repo.byId(id);
});

/// 作者 by ID(同步,从 repo 读)
final userByIdProvider =
    Provider.family<KkUser?, String>((ref, id) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.userById(id);
});

/// 三 Tab 排序 provider(kankan 屏用)
final projectsSortedProvider =
    Provider.family<List<Project>, ({String sort, String? domain})>(
        (ref, params) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.sorted(params.sort, domain: params.domain);
});

/// 热门标签(从所有 project 的 tags 聚合,真实计数)
final popularTagsProvider = Provider<List<({String tag, int count})>>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  final counts = <String, int>{};
  for (final p in repo.all()) {
    for (final t in p.tags) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  final list = counts.entries
      .map((e) => (tag: e.key, count: e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return list;
});
