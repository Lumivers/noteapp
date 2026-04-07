import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MarkdownEditor extends StatefulWidget {
  final String initialText;
  final TextEditingController? textController;
  final ScrollController? scrollController;
  final Function(String) onChanged;
  final Function(String) onSave;
  final bool readOnly;
  final double fontSize;

  const MarkdownEditor({
    required this.initialText,
    this.textController,
    this.scrollController,
    required this.onChanged,
    required this.onSave,
    this.readOnly = false,
    this.fontSize = 14.0,
    super.key,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _controller;
  late ScrollController _scrollController;
  late bool _ownsTextController;
  late bool _ownsScrollController;

  @override
  void initState() {
    super.initState();
    _ownsTextController = widget.textController == null;
    _ownsScrollController = widget.scrollController == null;
    _controller = widget.textController ??
        TextEditingController(text: widget.initialText);
    _scrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() {
    if (_ownsTextController) {
      _controller.dispose();
    }
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        _buildToolbar(context),
        // 编辑区域
        Expanded(
          child: TextField(
            controller: _controller,
            scrollController: _scrollController,
            onChanged: (value) {
              widget.onChanged(value);
            },
            readOnly: widget.readOnly,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: '开始输入 Markdown... ',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
            ),
            style: GoogleFonts.jetBrainsMono(
              fontSize: widget.fontSize,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C172A) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarButton(
              icon: Icons.format_bold,
              label: 'Bold',
              onPressed: () => _insertMarkdown('**', '**'),
            ),
            _ToolbarButton(
              icon: Icons.format_italic,
              label: 'Italic',
              onPressed: () => _insertMarkdown('*', '*'),
            ),
            _ToolbarButton(
              icon: Icons.format_strikethrough,
              label: 'Strike',
              onPressed: () => _insertMarkdown('~~', '~~'),
            ),
            const SizedBox(width: 4),
            _ToolbarButton(
              icon: Icons.code,
              label: 'Code',
              onPressed: () => _insertMarkdown('`', '`'),
            ),
            _ToolbarButton(
              icon: Icons.data_usage,
              label: 'Code Block',
              onPressed: () => _insertMarkdown('```\n', '\n```'),
            ),
            const SizedBox(width: 4),
            _ToolbarButton(
              icon: Icons.title,
              label: 'Heading',
              onPressed: () => _insertMarkdown('# ', ''),
            ),
            _ToolbarButton(
              icon: Icons.format_list_bulleted,
              label: 'List',
              onPressed: () => _insertMarkdown('- ', ''),
            ),
            _ToolbarButton(
              icon: Icons.link,
              label: 'Link',
              onPressed: () => _insertMarkdown('[', '](url)'),
            ),
            const SizedBox(width: 4),
            _ToolbarButton(
              icon: Icons.save,
              label: 'Save',
              onPressed: () => widget.onSave(_controller.text),
            ),
          ],
        ),
      ),
    );
  }

  void _insertMarkdown(String prefix, String suffix) {
    final selection = _controller.selection;
    final text = _controller.text;
    if (selection.start < 0 || selection.end < 0) {
      final fallbackText = '$prefix$suffix';
      _controller.value = _controller.value.copyWith(
        text: text + fallbackText,
        selection: TextSelection.collapsed(offset: text.length + prefix.length),
      );
      widget.onChanged(_controller.text);
      return;
    }

    final selectedText = text.substring(selection.start, selection.end);

    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$prefix$selectedText$suffix',
    );

    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length + selectedText.length,
      ),
    );

    widget.onChanged(newText);
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_ToolbarButton> createState() => __ToolbarButtonState();
}

class __ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: IconButton(
          icon: Icon(widget.icon),
          onPressed: widget.onPressed,
          isSelected: _hovered,
          selectedIcon: Icon(widget.icon),
          tooltip: widget.label,
        ),
      ),
    );
  }
}
