import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:noteapp/widgets/markdown_preview.dart';

void main() {
  testWidgets('MarkdownPreview shows empty hint when content is blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(content: '   '),
        ),
      ),
    );

    expect(find.text('开始输入 Markdown，右侧会实时渲染预览。'), findsOneWidget);
  });

  testWidgets('MarkdownPreview renders markdown text content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(content: '# 标题\n\n这里是正文'),
        ),
      ),
    );

    expect(find.text('标题'), findsOneWidget);
    expect(find.text('这里是正文'), findsOneWidget);
  });
}
