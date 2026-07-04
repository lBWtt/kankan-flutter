// 这个文件是干什么的：把 GET /projects 包成 AsyncValue，给看看 feed（真数据模式）用。
// 它对应产品里的什么功能：feed 的加载/错误/数据三态。
// 如果它出错了：feed 无法显示真数据的加载或错误态。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/projects_api.dart';
import '../domain/models/models.dart';

/// 真数据项目列表（AsyncValue：loading→骨架 / error→重试 / data→卡片）。
/// autoDispose + 可 ref.invalidate 重拉。
final remoteProjectsProvider =
    FutureProvider.autoDispose<List<Project>>((ref) async {
  return ref.watch(projectsApiProvider).list(limit: 30);
});
