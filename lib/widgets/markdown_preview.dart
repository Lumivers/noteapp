import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

class MarkdownPreview extends StatefulWidget {
  final String content;
  final ScrollController? scrollController;
  final bool syncScroll;

  const MarkdownPreview({
    required this.content,
    this.scrollController,
    this.syncScroll = false,
    super.key,
  });

  @override
  State<MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<MarkdownPreview> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    final markdownStyle =
        MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
      a: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      h2: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      h3: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      code: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      blockquoteDecoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      listBullet: Theme.of(context).textTheme.bodyMedium,
    );

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        child: widget.content.trim().isEmpty
            ? Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: double.infinity,
                  child: SelectableText(
                    '开始输入 Markdown，右侧会实时渲染预览。',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: hintColor,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
              )
            : Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: double.infinity,
                  child: MarkdownBody(
                    data: widget.content,
                    selectable: true,
                    styleSheet: markdownStyle,
                    softLineBreak: true,
                  ),
                ),
              ),
      ),
    );
  }
}
