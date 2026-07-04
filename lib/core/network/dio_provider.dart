// 这个文件是干什么的：提供全局唯一 Dio 实例（配好 baseUrl / 超时 / 请求头）。
// 它对应产品里的什么功能：所有走后端的接口调用都用这个 client。
// 如果它出错了：全站真数据接口失效。
//
// 说明：不碰 dart:io（web 编译不支持）。浏览器对 127.0.0.1 默认不走系统代理，
// web 端无需处理代理；移动/桌面端若被系统代理干扰，再加平台条件导入的 adapter。
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// 全局 Dio。鉴权拦截器（Bearer + 401 刷新）在接鉴权那步再加。
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json'},
    ),
  );
});
