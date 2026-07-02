// 冒烟测试:app 能否正常启动并挂载 MaterialApp。
// flutter create 的默认 counter 模板与本项目无关,已替换。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kankan_flutter/app.dart';

void main() {
  testWidgets('app 启动冒烟:挂载 MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KankanApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
