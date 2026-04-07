import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:noteapp/models/note.dart';
import 'package:noteapp/models/settings.dart';
import 'package:noteapp/services/ai_service.dart';
import 'package:noteapp/services/file_service.dart';
import 'package:noteapp/services/settings_service.dart';

class HomeScreen extends StatefulWidget {
  final FileService fileService;
  final SettingsService settingsService;
  final Function(Note) onEditNote;
  final Function() onThemeToggle;

  const HomeScreen({
    required this.fileService,
    required this.settingsService,
    required this.onEditNote,
    required this.onThemeToggle,
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Note>> _notesFuture;
  Settings _settings = const Settings();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadSettings();
  }

  void _loadNotes() {
    _notesFuture = widget.fileService.getAllNotes();
  }

  void _loadSettings() {
    widget.settingsService.getSettings().then((settings) {
      setState(() {
        _settings = settings;
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NoteApp Studio'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: widget.onThemeToggle,
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF070D1A), Color(0xFF0A1322)]
                : const [Color(0xFFF4F7FA), Color(0xFFEAF2F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<Note>>(
          future: _notesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadNotes();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            var notes = snapshot.data ?? [];

            if (_searchQuery.isNotEmpty) {
              notes = notes
                  .where(
                    (note) =>
                        note.title.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                        note.content.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                  )
                  .toList();
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _buildHeader(notes.length),
                ),
                Expanded(
                  child: notes.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            return _NoteCard(
                              note: notes[index],
                              onTap: () => widget.onEditNote(notes[index]),
                              onDelete: () => _deleteNote(notes[index]),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewNote,
        icon: const Icon(Icons.add),
        label: const Text('新建笔记'),
      ),
    );
  }

  Widget _buildHeader(int visibleCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本地 Markdown 工作区',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前可见 $visibleCount 篇笔记',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? Colors.blueGrey[200]
                                  : Colors.blueGrey[700],
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF111D31)
                        : const Color(0xFFE6F6FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.note_alt_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索标题或正文内容',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 260), () {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _searchQuery = value;
                  });
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message =
        _searchQuery.isEmpty ? '还没有笔记，点击右下角按钮开始创建。' : '没有匹配“$_searchQuery”的结果。';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewNote() async {
    final TextEditingController titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建笔记'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: '输入标题',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                return;
              }

              final note = await widget.fileService.createNote(
                titleController.text.trim(),
              );

              if (!mounted) {
                return;
              }
              if (!dialogContext.mounted) {
                return;
              }

              Navigator.of(dialogContext).pop();
              widget.onEditNote(note);
              setState(() {
                _loadNotes();
              });
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _deleteNote(Note note) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确认删除“${note.title}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.fileService.deleteNote(note);
              if (!mounted) {
                return;
              }
              if (!dialogContext.mounted) {
                return;
              }

              Navigator.of(dialogContext).pop();
              setState(() {
                _loadNotes();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除“${note.title}”')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
            child: _SettingsPanel(
              fileService: widget.fileService,
              settings: _settings,
              onSettingsChanged: _loadSettings,
              onStoragePathChanged: () {
                setState(() {
                  _loadNotes();
                });
              },
              settingsService: widget.settingsService,
            ),
          ),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = note.content.length > 100
        ? '${note.content.substring(0, 100)}...'
        : note.content;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preview.isEmpty ? '空白笔记' : preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark
                            ? Colors.blueGrey[200]
                            : Colors.blueGrey[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '最近修改 ${note.modifiedAt.toString().split('.')[0]}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: onDelete,
                    child: const Text('删除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatefulWidget {
  final FileService fileService;
  final Settings settings;
  final VoidCallback onSettingsChanged;
  final VoidCallback onStoragePathChanged;
  final SettingsService settingsService;

  const _SettingsPanel({
    required this.fileService,
    required this.settings,
    required this.onSettingsChanged,
    required this.onStoragePathChanged,
    required this.settingsService,
  });

  @override
  State<_SettingsPanel> createState() => __SettingsPanelState();
}

class __SettingsPanelState extends State<_SettingsPanel> {
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late TextEditingController _systemPromptController;
  String _storagePath = '';
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isSwitchingStorage = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.settings.openaiBaseUrl,
    );
    _apiKeyController = TextEditingController(
      text: widget.settings.openaiApiKey ?? '',
    );
    _modelController = TextEditingController(
      text: widget.settings.openaiModel,
    );
    _systemPromptController = TextEditingController(
      text: widget.settings.aiSystemPrompt,
    );
    _storagePath = widget.fileService.storagePath;
  }

  Future<void> _chooseStoragePath() async {
    final messenger = ScaffoldMessenger.of(context);
    final selectedPath = await getDirectoryPath(
      confirmButtonText: '选择此目录',
      initialDirectory: _storagePath,
    );

    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }

    setState(() {
      _isSwitchingStorage = true;
    });
    try {
      await widget.fileService.initialize(customDirectoryPath: selectedPath);
      await widget.settingsService.setNotesStoragePath(selectedPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _storagePath = widget.fileService.storagePath;
      });
      widget.onSettingsChanged();
      widget.onStoragePathChanged();
      messenger.showSnackBar(
        const SnackBar(content: Text('笔记存储目录已切换')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('切换目录失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingStorage = false;
        });
      }
    }
  }

  Future<void> _resetStoragePath() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSwitchingStorage = true;
    });
    try {
      await widget.settingsService.setNotesStoragePath('');
      await widget.fileService.initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _storagePath = widget.fileService.storagePath;
      });
      widget.onSettingsChanged();
      widget.onStoragePathChanged();
      messenger.showSnackBar(
        const SnackBar(content: Text('已恢复默认存储目录')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('恢复默认目录失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingStorage = false;
        });
      }
    }
  }

  bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _saveConfig() async {
    final messenger = ScaffoldMessenger.of(context);
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    final systemPrompt = _systemPromptController.text.trim();

    if (!_isValidUrl(baseUrl)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请输入有效的 API 地址（http/https）')),
      );
      return;
    }
    if (apiKey.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('API Key 不能为空')),
      );
      return;
    }
    if (model.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('模型名称不能为空')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      await widget.settingsService.saveAiConfig(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        systemPrompt: systemPrompt,
      );
      if (!mounted) {
        return;
      }
      widget.onSettingsChanged();
      messenger.showSnackBar(
        const SnackBar(content: Text('AI 配置已保存')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    final messenger = ScaffoldMessenger.of(context);
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();

    if (!_isValidUrl(baseUrl) || apiKey.isEmpty || model.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先填写 API 地址、API Key 和模型名称')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
    });

    try {
      final service = AIService();
      service.configure(baseUrl: baseUrl, apiKey: apiKey, model: model);
      await service.testConnection();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('连接测试成功')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('连接测试失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              '笔记存储',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _storagePath,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSwitchingStorage ? null : _chooseStoragePath,
                    icon: _isSwitchingStorage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open),
                    label: const Text('选择目录'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSwitchingStorage ? null : _resetStoragePath,
                    icon: const Icon(Icons.restore),
                    label: const Text('恢复默认'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'AI 配置（OpenAI 协议兼容）',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                hintText: 'https://your-provider.example/v1',
                labelText: 'API Base URL',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: '输入你的 API Key',
                labelText: 'API Key',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                hintText: '例如：deepseek-chat / qwen-plus / gpt-4o-mini',
                labelText: 'Model',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _systemPromptController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '可选：例如“你是专业中文技术写作助手，输出简洁清晰。”',
                labelText: '全局 System Prompt（可选）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: const Text('测试连接'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveConfig,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('保存配置'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '说明：这里兼容 OpenAI 协议格式，但可以接入任意厂商接口。',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }
}
