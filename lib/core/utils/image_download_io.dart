import 'dart:typed_data';

/// 非 web 平台 stub(移动端不编译 dart:html,条件导入走这里)。
/// 任务 B:移动端真保存到相册要 gallery_saver(不在本任务范围),这里返回 false。
/// share_sheet 据此 toast「保存失败(仅支持 Web)」。
Future<bool> platformDownloadPngBytes(Uint8List bytes, String filename) async {
  return false;
}
