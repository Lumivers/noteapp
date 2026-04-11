import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noteapp/widgets/markdown_editor.dart';
import 'package:noteapp/widgets/markdown_preview.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macro-like rapid input and scrolling keeps editor responsive',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: _MacroStressHarness(),
          ),
        ),
      ),
    );

    final editorFinder = find.byType(TextField).first;
    expect(editorFinder, findsOneWidget);

    var content = '# Stress Test';
    for (var i = 0; i < 140; i++) {
      content += '\n\n- line $i: macro typing burst';
      await tester.enterText(editorFinder, content);
      await tester.pump(const Duration(milliseconds: 8));
    }

    for (var i = 0; i < 18; i++) {
      await tester.fling(editorFinder, const Offset(0, -420), 2600);
      await tester.pump(const Duration(milliseconds: 16));
    }

    final boldButton = find.byIcon(Icons.format_bold);
    expect(boldButton, findsOneWidget);
    for (var i = 0; i < 24; i++) {
      await tester.tap(boldButton);
      await tester.pump(const Duration(milliseconds: 12));
    }

    await tester.pumpAndSettle();

    expect(find.textContaining('line 120'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _MacroStressHarness extends StatefulWidget {
  const _MacroStressHarness();

  @override
  State<_MacroStressHarness> createState() => _MacroStressHarnessState();
}

class _MacroStressHarnessState extends State<_MacroStressHarness> {
  String _content = '# Stress Test\n\nStart.';
  final TextEditingController _textController =
      TextEditingController(text: '# Stress Test\n\nStart.');
  final ScrollController _editorScroll = ScrollController();
  final ScrollController _previewScroll = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _editorScroll.dispose();
    _previewScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MarkdownEditor(
            initialText: _content,
            textController: _textController,
            scrollController: _editorScroll,
            onChanged: (value) {
              setState(() {
                _content = value;
              });
            },
            onSave: (_) {},
          ),
        ),
        Expanded(
          child: MarkdownPreview(
            content: _content,
            scrollController: _previewScroll,
          ),
        ),
      ],
    );
  }
}
