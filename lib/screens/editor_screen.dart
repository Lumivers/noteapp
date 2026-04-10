import 'package:flutter/material.dart';
import 'package:noteapp/models/note.dart';
import 'package:noteapp/models/settings.dart';
import 'package:noteapp/services/file_service.dart';
import 'package:noteapp/services/ai_service.dart';
import 'package:noteapp/services/settings_service.dart';
import 'package:noteapp/widgets/split_view.dart';
import 'package:noteapp/widgets/markdown_editor.dart';
import 'package:noteapp/widgets/markdown_preview.dart';
import 'dart:async';

class EditorScreen extends StatefulWidget {
  final Note initialNote;
  final FileService fileService;
  final AIService aiService;
  final SettingsService settingsService;
  final Function() onNoteUpdated;

  const EditorScreen({
    required this.initialNote,
    required this.fileService,
    required this.aiService,
    required this.settingsService,
    required this.onNoteUpdated,
    super.key,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Note _currentNote;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late ScrollController _editorScroll;
  late ScrollController _previewScroll;
  late Future<List<Note>> _notesFuture;
  Timer? _saveDebounce;
  Timer? _sidebarDebounce;
  Timer? _editorUiRefreshThrottle;
  bool _isSaving = false;
  bool _isSyncingScroll = false;
  bool _isAiProcessing = false;
  _AiDiffResult? _pendingAiDiff;
  String? _pendingAiActionName;
  int _currentReviewBlockIndex = 0;
  bool _showPreview = true;
  bool _isSidebarCollapsed = false;
  String _sidebarQuery = '';
  int _nonWhitespaceCharCount = 0;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.initialNote;
    _titleController = TextEditingController(text: _currentNote.title);
    _contentController = TextEditingController(text: _currentNote.content);
    _nonWhitespaceCharCount = _countNonWhitespaceChars(_currentNote.content);
    _editorScroll = ScrollController();
    _previewScroll = ScrollController();
    _loadNotes();

    // 设置同步滚动
    _editorScroll.addListener(_syncScroll);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _editorScroll.dispose();
    _previewScroll.dispose();
    _saveDebounce?.cancel();
    _sidebarDebounce?.cancel();
    _editorUiRefreshThrottle?.cancel();
    super.dispose();
  }

  void _loadNotes() {
    _notesFuture = widget.fileService.getAllNotes();
  }

  void _syncScroll() {
    if (_isSyncingScroll ||
        !_editorScroll.hasClients ||
        !_previewScroll.hasClients) {
      return;
    }

    final maxEditor = _editorScroll.position.maxScrollExtent;
    final maxPreview = _previewScroll.position.maxScrollExtent;
    if (maxEditor <= 0 || maxPreview <= 0) {
      return;
    }

    _isSyncingScroll = true;
    final ratio = (_editorScroll.offset / maxEditor).clamp(0.0, 1.0);
    _previewScroll.jumpTo(ratio * maxPreview);
    _isSyncingScroll = false;
  }

  void _saveNote({bool silent = false}) {
    if (!silent) {
      _isSaving = true;
      setState(() {});
    }

    widget.fileService.saveNote(_currentNote).then((_) {
      _isSaving = false;
      if (mounted) {
        if (!silent) {
          setState(() {});
          _loadNotes();
        }
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('笔记已保存'),
              duration: Duration(milliseconds: 1200),
            ),
          );
        }
      }
    }).catchError((e) {
      _isSaving = false;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    });
  }

  void _debouncedSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(seconds: 1),
      () => _saveNote(silent: true),
    );
  }

  void _handleEditorContentChanged(String value) {
    _currentNote = _currentNote.copyWith(content: value);
    _debouncedSave();
    _scheduleEditorUiRefresh();
  }

  void _scheduleEditorUiRefresh() {
    if (_editorUiRefreshThrottle?.isActive ?? false) {
      return;
    }
    _editorUiRefreshThrottle = Timer(
      const Duration(milliseconds: 120),
      () {
        if (!mounted) {
          return;
        }
        _nonWhitespaceCharCount =
            _countNonWhitespaceChars(_currentNote.content);
        setState(() {});
      },
    );
  }

  int _countNonWhitespaceChars(String content) {
    var count = 0;
    for (final rune in content.runes) {
      if (String.fromCharCode(rune).trim().isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  Future<void> _handleAiAction(_AiAction action) async {
    if (_isAiProcessing) {
      return;
    }

    switch (action) {
      case _AiAction.polish:
        await _runAiFlow(
          actionName: '润色',
          request: (settings) =>
              widget.aiService.polishText(_currentNote.content),
        );
        break;
      case _AiAction.summary:
        await _runAiFlow(
          actionName: '摘要',
          request: (settings) async {
            final summary =
                await widget.aiService.generateSummary(_currentNote.content);
            return '${_currentNote.content}\n\n---\n\n## AI 摘要\n\n$summary';
          },
        );
        break;
      case _AiAction.continueWrite:
        await _runAiFlow(
          actionName: '续写',
          request: (settings) async {
            final continued =
                await widget.aiService.completeContent(_currentNote.content);
            return '${_currentNote.content}\n\n$continued';
          },
        );
        break;
      case _AiAction.custom:
        final instruction = await _showCustomInstructionDialog();
        if (instruction == null || instruction.trim().isEmpty) {
          return;
        }
        await _runAiFlow(
          actionName: '自定义改写',
          request: (settings) => widget.aiService.rewriteWithInstruction(
            text: _currentNote.content,
            instruction: instruction,
            systemMessage: settings.aiSystemPrompt.trim().isEmpty
                ? null
                : settings.aiSystemPrompt.trim(),
          ),
        );
        break;
    }
  }

  Future<void> _runAiFlow({
    required String actionName,
    required Future<String> Function(Settings settings) request,
  }) async {
    final settings = await widget.settingsService.getSettings();

    final baseUrl = settings.openaiBaseUrl.trim();
    final apiKey = (settings.openaiApiKey ?? '').trim();
    final model = settings.openaiModel.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty || model.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在设置中填写 API 地址、API Key 和模型')),
        );
      }
      return;
    }

    setState(() {
      _isAiProcessing = true;
    });

    try {
      widget.aiService
          .configure(baseUrl: baseUrl, apiKey: apiKey, model: model);
      final result = await request(settings);

      if (!mounted) {
        return;
      }
      await _reviewAiChangesAndApply(
        originalText: _currentNote.content,
        aiText: result,
        actionName: actionName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI $actionName 失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiProcessing = false;
        });
      }
    }
  }

  Future<String?> _showCustomInstructionDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('自定义 AI 指令'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '例如：改成更口语化，保留技术术语，并补充结论小节。',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('执行'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _reviewAiChangesAndApply({
    required String originalText,
    required String aiText,
    required String actionName,
  }) async {
    if (aiText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI $actionName 返回为空，未应用修改')),
      );
      return;
    }

    if (originalText == aiText) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 返回内容与原文一致，无需应用')),
      );
      return;
    }

    final diffResult = _buildLineDiff(originalText, aiText);
    if (diffResult.blocks.isEmpty) {
      _applyContent(aiText);
      return;
    }

    setState(() {
      _pendingAiDiff = diffResult;
      _pendingAiActionName = actionName;
      _currentReviewBlockIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已进入 AI 变更审阅模式，请在编辑区逐块确认')),
    );
  }

  void _applyContent(String content) {
    setState(() {
      _currentNote = _currentNote.copyWith(content: content);
      _contentController.text = content;
      _nonWhitespaceCharCount = _countNonWhitespaceChars(content);
    });
    _debouncedSave();
  }

  String _buildMergedText(_AiDiffResult diffResult) {
    final buffer = StringBuffer();
    for (final op in diffResult.operations) {
      if (op.type == _AiDiffType.equal) {
        buffer.write(op.text);
        continue;
      }
      final block = diffResult.blocks[op.blockIndex!];
      buffer.write(block.keepAi ? block.newText : block.oldText);
    }
    return buffer.toString();
  }

  void _setCurrentBlockDecision(bool keepAi) {
    final diff = _pendingAiDiff;
    if (diff == null || diff.blocks.isEmpty) {
      return;
    }
    setState(() {
      diff.blocks[_currentReviewBlockIndex].keepAi = keepAi;
    });
  }

  void _nextReviewBlock() {
    final diff = _pendingAiDiff;
    if (diff == null || diff.blocks.isEmpty) {
      return;
    }
    if (_currentReviewBlockIndex >= diff.blocks.length - 1) {
      return;
    }
    setState(() {
      _currentReviewBlockIndex++;
    });
  }

  void _prevReviewBlock() {
    if (_currentReviewBlockIndex <= 0) {
      return;
    }
    setState(() {
      _currentReviewBlockIndex--;
    });
  }

  void _acceptCurrentAndNext() {
    _setCurrentBlockDecision(true);
    _nextReviewBlock();
  }

  void _rejectCurrentAndNext() {
    _setCurrentBlockDecision(false);
    _nextReviewBlock();
  }

  void _applyInlineReview() {
    final diff = _pendingAiDiff;
    final actionName = _pendingAiActionName;
    if (diff == null) {
      return;
    }
    final merged = _buildMergedText(diff);
    _applyContent(merged);

    setState(() {
      _pendingAiDiff = null;
      _pendingAiActionName = null;
      _currentReviewBlockIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI ${actionName ?? '改写'} 已按逐块确认结果应用')),
    );
  }

  void _cancelInlineReview() {
    setState(() {
      _pendingAiDiff = null;
      _pendingAiActionName = null;
      _currentReviewBlockIndex = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已取消本次 AI 变更审阅')),
    );
  }

  _AiDiffResult _buildLineDiff(String oldText, String newText) {
    final oldLines = _splitLinesKeepNewline(oldText);
    final newLines = _splitLinesKeepNewline(newText);

    if (oldLines.length > 700 || newLines.length > 700) {
      return _AiDiffResult(
        operations: [
          _AiDiffOperation(type: _AiDiffType.block, text: ''),
        ],
        blocks: [
          _AiChangeBlock(oldText: oldText, newText: newText),
        ],
      );
    }

    final m = oldLines.length;
    final n = newLines.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (var i = m - 1; i >= 0; i--) {
      for (var j = n - 1; j >= 0; j--) {
        if (oldLines[i] == newLines[j]) {
          dp[i][j] = dp[i + 1][j + 1] + 1;
        } else {
          dp[i][j] = dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }

    final raw = <_AiRawOperation>[];
    var i = 0;
    var j = 0;
    while (i < m && j < n) {
      if (oldLines[i] == newLines[j]) {
        raw.add(_AiRawOperation(type: _AiRawType.equal, text: oldLines[i]));
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        raw.add(_AiRawOperation(type: _AiRawType.delete, text: oldLines[i]));
        i++;
      } else {
        raw.add(_AiRawOperation(type: _AiRawType.insert, text: newLines[j]));
        j++;
      }
    }
    while (i < m) {
      raw.add(_AiRawOperation(type: _AiRawType.delete, text: oldLines[i++]));
    }
    while (j < n) {
      raw.add(_AiRawOperation(type: _AiRawType.insert, text: newLines[j++]));
    }

    final operations = <_AiDiffOperation>[];
    final blocks = <_AiChangeBlock>[];
    var cursor = 0;

    while (cursor < raw.length) {
      final current = raw[cursor];
      if (current.type == _AiRawType.equal) {
        operations
            .add(_AiDiffOperation(type: _AiDiffType.equal, text: current.text));
        cursor++;
        continue;
      }

      final oldBuffer = StringBuffer();
      final newBuffer = StringBuffer();
      while (cursor < raw.length && raw[cursor].type != _AiRawType.equal) {
        final part = raw[cursor];
        if (part.type == _AiRawType.delete) {
          oldBuffer.write(part.text);
        } else if (part.type == _AiRawType.insert) {
          newBuffer.write(part.text);
        }
        cursor++;
      }

      final blockIndex = blocks.length;
      blocks.add(
        _AiChangeBlock(
          oldText: oldBuffer.toString(),
          newText: newBuffer.toString(),
        ),
      );
      operations.add(
        _AiDiffOperation(
          type: _AiDiffType.block,
          text: '',
          blockIndex: blockIndex,
        ),
      );
    }

    return _AiDiffResult(operations: operations, blocks: blocks);
  }

  List<String> _splitLinesKeepNewline(String text) {
    if (text.isEmpty) {
      return const [];
    }

    final lines = <String>[];
    var start = 0;
    while (start < text.length) {
      final index = text.indexOf('\n', start);
      if (index == -1) {
        lines.add(text.substring(start));
        break;
      }
      lines.add(text.substring(start, index + 1));
      start = index + 1;
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_isSaving) {
          _saveNote(silent: true);
        }
        widget.onNoteUpdated();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
            onPressed: () {
              if (_isSaving) {
                _saveNote(silent: true);
              }
              widget.onNoteUpdated();
            },
          ),
          title: TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '输入笔记标题',
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            onChanged: (value) {
              _currentNote = _currentNote.copyWith(title: value);
              _debouncedSave();
            },
          ),
          actions: [
            PopupMenuButton<_AiAction>(
              tooltip: 'AI 助手',
              enabled: !_isAiProcessing,
              icon: _isAiProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              onSelected: _handleAiAction,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _AiAction.polish,
                  child: Text('润色全文'),
                ),
                PopupMenuItem(
                  value: _AiAction.summary,
                  child: Text('生成摘要并追加'),
                ),
                PopupMenuItem(
                  value: _AiAction.continueWrite,
                  child: Text('智能续写'),
                ),
                PopupMenuItem(
                  value: _AiAction.custom,
                  child: Text('自定义指令改写'),
                ),
              ],
            ),
            // 保存
            _isSaving
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => _saveNote(),
                    tooltip: '保存',
                  ),
            const SizedBox(width: 8),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF050C18), Color(0xFF0B1424)]
                  : const [Color(0xFFF1F5F9), Color(0xFFEAF1F8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              _buildStatusBar(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSidebar(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 12, 12),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (_pendingAiDiff != null) {
                                return _buildInlineAiReview();
                              }

                              final isNarrow = constraints.maxWidth < 900;

                              if (!_showPreview || isNarrow) {
                                return MarkdownEditor(
                                  initialText: _currentNote.content,
                                  textController: _contentController,
                                  scrollController: _editorScroll,
                                  onChanged: _handleEditorContentChanged,
                                  onSave: (content) => _saveNote(),
                                );
                              }

                              return SplitView(
                                isVertical: false,
                                initialDividerPos: 0.5,
                                leftChild: MarkdownEditor(
                                  initialText: _currentNote.content,
                                  textController: _contentController,
                                  scrollController: _editorScroll,
                                  onChanged: _handleEditorContentChanged,
                                  onSave: (content) => _saveNote(),
                                ),
                                rightChild: _PreviewPane(
                                  content: _currentNote.content,
                                  scrollController: _previewScroll,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineAiReview() {
    final diff = _pendingAiDiff!;
    final total = diff.blocks.length;
    final index = _currentReviewBlockIndex.clamp(0, total - 1);
    final currentBlock = diff.blocks[index];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rule_folder_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI 逐块审阅 · ${_pendingAiActionName ?? '改写'}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text('第 ${index + 1} / $total 块'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _AiChangeBlockCard(
                      index: index + 1,
                      block: currentBlock,
                      onToggle: (value) => _setCurrentBlockDecision(value),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: index > 0 ? _prevReviewBlock : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('上一块'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed:
                              index < total - 1 ? _nextReviewBlock : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('下一块'),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: _rejectCurrentAndNext,
                          child: const Text('保留原文并下一条'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _acceptCurrentAndNext,
                          child: const Text('采用 AI 并下一条'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: _cancelInlineReview,
                icon: const Icon(Icons.close),
                label: const Text('取消审阅'),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    for (final block in diff.blocks) {
                      block.keepAi = false;
                    }
                  });
                },
                child: const Text('全部保留原文'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    for (final block in diff.blocks) {
                      block.keepAi = true;
                    }
                  });
                },
                child: const Text('全部采用 AI'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _applyInlineReview,
                icon: const Icon(Icons.done_all),
                label: const Text('应用所有选择'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          _StatusChip(
            icon: _isSaving ? Icons.sync : Icons.check_circle_outline,
            label: _isSaving ? '自动保存中' : '已同步到本地',
          ),
          const SizedBox(width: 8),
          _StatusChip(
            icon: Icons.text_fields,
            label: '$_nonWhitespaceCharCount 字',
          ),
          const Spacer(),
          _StatusChip(
            icon:
                _showPreview ? Icons.splitscreen_outlined : Icons.edit_outlined,
            label: _showPreview ? '双栏模式' : '纯编辑模式',
            onTap: () {
              setState(() {
                _showPreview = !_showPreview;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF0C172A) : const Color(0xFFF8FAFC);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSidebarCollapsed ? 64 : 260,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: _isSidebarCollapsed
                ? const EdgeInsets.all(8)
                : const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: _isSidebarCollapsed
                ? Center(
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_right),
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _isSidebarCollapsed = false;
                        });
                      },
                    ),
                  )
                : Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_left),
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _isSidebarCollapsed = true;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          '笔记目录',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _loadNotes();
                          });
                        },
                      ),
                    ],
                  ),
          ),
          if (!_isSidebarCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '过滤笔记',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) {
                  _sidebarDebounce?.cancel();
                  _sidebarDebounce = Timer(
                    const Duration(milliseconds: 240),
                    () {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _sidebarQuery = value;
                      });
                    },
                  );
                },
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Note>>(
              future: _notesFuture,
              builder: (context, snapshot) {
                final notes = snapshot.data ?? [];
                final filtered = _sidebarQuery.isEmpty
                    ? notes
                    : notes
                        .where(
                          (note) =>
                              note.title.toLowerCase().contains(
                                    _sidebarQuery.toLowerCase(),
                                  ) ||
                              note.content.toLowerCase().contains(
                                    _sidebarQuery.toLowerCase(),
                                  ),
                        )
                        .toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final note = filtered[index];
                    final isActive = note.title == _currentNote.title;
                    if (_isSidebarCollapsed) {
                      return Tooltip(
                        message: note.title,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openNote(note),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
                              child: Text(
                                note.title.isEmpty
                                    ? '?'
                                    : note.title.characters.first,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openNote(note),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title.isEmpty ? '未命名' : note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              note.content.isEmpty ? '空白内容' : note.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.blueGrey[200]
                                    : Colors.blueGrey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openNote(Note note) {
    if (note.title == _currentNote.title &&
        note.content == _currentNote.content) {
      return;
    }

    _saveNote(silent: true);
    setState(() {
      _currentNote = note;
      _titleController.text = note.title;
      _contentController.text = note.content;
    });
    _editorScroll.jumpTo(0);
    _previewScroll.jumpTo(0);
  }
}

class _PreviewPane extends StatelessWidget {
  final String content;
  final ScrollController scrollController;

  const _PreviewPane({
    required this.content,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C172A) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.visibility,
                size: 18,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(width: 8),
              Text(
                '预览',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: MarkdownPreview(
            content: content,
            scrollController: scrollController,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _StatusChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111D31) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

enum _AiAction { polish, summary, continueWrite, custom }

enum _AiRawType { equal, delete, insert }

enum _AiDiffType { equal, block }

class _AiRawOperation {
  final _AiRawType type;
  final String text;

  const _AiRawOperation({required this.type, required this.text});
}

class _AiDiffOperation {
  final _AiDiffType type;
  final String text;
  final int? blockIndex;

  const _AiDiffOperation({
    required this.type,
    required this.text,
    this.blockIndex,
  });
}

class _AiChangeBlock {
  final String oldText;
  final String newText;
  bool keepAi = true;

  _AiChangeBlock({
    required this.oldText,
    required this.newText,
  });
}

class _AiDiffResult {
  final List<_AiDiffOperation> operations;
  final List<_AiChangeBlock> blocks;

  const _AiDiffResult({required this.operations, required this.blocks});
}

class _AiChangeBlockCard extends StatelessWidget {
  final int index;
  final _AiChangeBlock block;
  final ValueChanged<bool> onToggle;

  const _AiChangeBlockCard({
    required this.index,
    required this.block,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasOld = block.oldText.trim().isNotEmpty;
    final hasNew = block.newText.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '变更块 $index',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Switch(
                  value: block.keepAi,
                  onChanged: onToggle,
                ),
                const SizedBox(width: 4),
                Text(block.keepAi ? '采用 AI' : '保留原文'),
              ],
            ),
            if (hasOld) ...[
              _DiffTextPane(
                title: '删除',
                text: block.oldText,
                color: Colors.red,
                background: const Color(0xFFFFEEF0),
              ),
              const SizedBox(height: 8),
            ],
            if (hasNew)
              _DiffTextPane(
                title: '新增',
                text: block.newText,
                color: Colors.green,
                background: const Color(0xFFEFFAF2),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiffTextPane extends StatelessWidget {
  final String title;
  final String text;
  final Color color;
  final Color background;

  const _DiffTextPane({
    required this.title,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          SelectableText(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
