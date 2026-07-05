// 这个文件是干什么的：封装项目相关的后端接口调用（当前只有 GET /projects 列表）。
// 它对应产品里的什么功能：看看 feed 拉真数据。
// 如果它出错了：feed 拉不到真项目（会被 remoteProjectsProvider 转成错误态）。
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/app_exception.dart';
import '../../core/network/dio_provider.dart';
import '../../domain/models/models.dart';
import '../dto/project_card_dto.dart';

class ProjectsApi {
  final Dio _dio;
  ProjectsApi(this._dio);

  /// GET /projects → 已发布项目卡片列表。
  /// 后端返回信封 {items:[...]} 或裸数组，两种都兼容。
  Future<List<Project>> list({int limit = 30}) async {
    try {
      final resp = await _dio.get<dynamic>(
        '/projects',
        queryParameters: {'limit': limit},
      );
      final data = resp.data;
      final Object? rawItems = data is Map<dynamic, dynamic>
          ? (data['items'] ?? data['data'] ?? const <dynamic>[])
          : (data ?? const <dynamic>[]);
      final items = rawItems is List ? rawItems : const <dynamic>[];
      return items
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => projectFromCardJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  /// GET /projects/{id} → 单个项目详情（比卡片多 intro/author/media/counts）。
  Future<Project?> detail(String id) async {
    try {
      final resp = await _dio.get<dynamic>('/projects/$id');
      final data = resp.data;
      if (data is Map) {
        return projectFromDetailJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (e) {
      // 404 → 该 id 后端没有（可能是 mock id 误入）→ 返回 null 让上层兜底,不抛。
      if (e.response?.statusCode == 404) return null;
      throw AppException.fromDio(e);
    }
  }
}

final projectsApiProvider = Provider<ProjectsApi>(
  (ref) => ProjectsApi(ref.watch(dioProvider)),
);
