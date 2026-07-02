import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// 入口。
///
/// HANDOFF §0:看看 = "看 AI 做出的有意思的东西 + 心得"的目的地。
/// Phase 1:ProviderScope 包根 → KankanApp(MaterialApp.router)。
void main() {
  runApp(const ProviderScope(child: KankanApp()));
}
