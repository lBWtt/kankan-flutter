import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/seed/mock_seed.dart';
import '../../domain/models/models.dart';

/// 通知 Repository — HANDOFF §6.8 5 类精准跳转。
///
/// Web 版重灾区:通知点击无差别跳转或跳错宿主。Flutter 端从零做对:
/// NotificationItem.type + targetId + hostType 三字段共同决定跳转目的地,
/// NotifScreen 根据 type 调不同路由(见 _routeFor 方法)。
///
/// 计数铁律(HANDOFF §6.10):未读数 = unread 集合真实长度,不放大。
class NotificationRepository {
  final List<NotificationItem> _items;

  NotificationRepository(this._items);

  /// F-36:先 sort 可变副本再返回(不再 `List.unmodifiable(_items..sort())`
  /// 那样会污染内部 _items 顺序)。约定(Codex 规则 C):all() 返回可变副本,
  /// 调用方可直接 sort。
  List<NotificationItem> all() {
    final list = List.of(_items);
    list.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return list;
  }

  /// 未读列表(真实长度)
  List<NotificationItem> unread() =>
      all().where((n) => !n.read).toList();

  /// 已读列表
  List<NotificationItem> read() =>
      all().where((n) => n.read).toList();

  /// 标记单条已读
  void markRead(String id) {
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0 && !_items[i].read) {
      _items[i] = _items[i].copyWith(read: true);
    }
  }

  /// 全部标记已读
  void markAllRead() {
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
      }
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(List.of(mockNotifications));
});
