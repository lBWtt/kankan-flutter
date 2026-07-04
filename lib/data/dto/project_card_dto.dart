// 这个文件是干什么的：把后端 GET /projects 的卡片 JSON 映射成前端 Project 模型。
// 它对应产品里的什么功能：看看 feed 的每张卡（真数据模式）。
// 如果它出错了：真数据 feed 解析失败或字段错位。
//
// 已知模型分叉（B 轨，见 flutter-backend-integration 记忆）：
//   - 后端 domains 是职业枚举(design/dev/...)，前端 domain 是成果类型(ai_image/...)——
//     这里按 category 尽力映射，不透传前端 domain 筛选。
//   - 卡片无 likes（counts 为 null）→ likes 记 0；author 不展开 → authorId 置空，
//     调用方在真数据模式下用 showAuthor:false 隐藏作者行。
//   - resultData 仅填封面 media；actions/io/repo 留空（详情级数据后续接详情端点）。
import '../../domain/models/models.dart';

/// 后端 category → 前端 domain（成果类型）尽力映射，兜底 'tool'。
String _mapDomain(String? category) {
  switch (category) {
    case 'image_design':
    case 'image':
      return 'ai_image';
    case 'video':
    case 'video_edit':
      return 'ai_video';
    case 'web':
    case 'web_design':
      return 'web';
    case 'app':
    case 'mobile':
      return 'app';
    case 'prompt':
    case 'writing':
      return 'prompt';
    case 'opensource':
    case 'open_source':
      return 'opensource';
    default:
      return 'tool';
  }
}

int _parseMs(dynamic isoOrNull) {
  if (isoOrNull is String && isoOrNull.isNotEmpty) {
    final dt = DateTime.tryParse(isoOrNull);
    if (dt != null) return dt.millisecondsSinceEpoch;
  }
  return DateTime.now().millisecondsSinceEpoch;
}

/// 从后端卡片 JSON 造一个前端 Project（feed 卡片够用的最小映射）。
Project projectFromCardJson(Map<String, dynamic> j) {
  final cover = j['cover_media_url'];
  final media = <MediaItem>[
    if (cover is String && cover.isNotEmpty)
      MediaItem(type: 'image', url: cover),
  ];
  final tools = (j['tools'] is List)
      ? (j['tools'] as List).map((e) => e.toString()).toList()
      : const <String>[];

  final takeaway = j['takeaway_count'];
  return Project(
    id: j['id'].toString(),
    title: (j['title'] ?? '').toString(),
    summary: (j['tagline'] ?? j['subtitle'] ?? j['intro'] ?? '').toString(),
    authorId: '', // 后端卡片不展开作者；真数据模式下调用方隐藏作者行
    resultData: ResultData(media: media),
    actions: const [],
    tags: tools,
    domain: _mapDomain(j['category']?.toString()),
    likes: 0,
    commentCount: 0,
    takeawayCount: takeaway is int ? takeaway : int.tryParse('$takeaway') ?? 0,
    createdAtMs: _parseMs(j['published_at']),
  );
}
