import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:noteapp/models/note.dart';

class FileService {
  static const String _defaultFolderName = 'docs';
  static const String _welcomeNoteFileName = 'Welcome to NoteApp.md';
  static const String _welcomeNoteContent = '''# Welcome to NoteApp

你好，欢迎使用 NoteApp。

这是一篇自动创建的初始笔记，帮助你快速上手。

## 30 秒上手

1. 回到首页，点击右下角“新建笔记”
2. 输入标题并开始记录
3. 在编辑区输入 Markdown，右侧可实时预览

## AI 功能（可选）

如果你想使用润色、摘要、续写：

1. 打开右上角 Settings
2. 填写 API Base URL、API Key、Model
3. 先“测试连接”，再“保存配置”

## 数据存储说明

- 你的笔记默认保存在本机文档目录下的 `docs` 文件夹
- 你可以在 Settings 中切换到任何本地目录
- API Key 使用系统安全存储保存

## 试试看

下面是一段 Markdown 示例：

```markdown
## 今日待办

- [ ] 完成第一篇笔记
- [ ] 配置 AI（可选）
- [ ] 试试搜索功能
```

祝你使用愉快。
''';
  late Directory notesDirectory;

  String get storagePath => notesDirectory.path;

  Future<String> getDefaultStoragePath() async {
    final documentDir = await getApplicationDocumentsDirectory();
    return '${documentDir.path}${Platform.pathSeparator}$_defaultFolderName';
  }

  // 初始化笔记文件夹
  Future<void> initialize({String? customDirectoryPath}) async {
    final customPath = customDirectoryPath?.trim() ?? '';
    final targetPath =
        customPath.isEmpty ? await getDefaultStoragePath() : customPath;

    notesDirectory = Directory(targetPath);

    // 如果文件夹不存在则创建
    if (!await notesDirectory.exists()) {
      await notesDirectory.create(recursive: true);
    }

    await _ensureWelcomeNoteExists();
  }

  Future<void> _ensureWelcomeNoteExists() async {
    final files = notesDirectory.listSync();
    final hasMarkdownNotes = files.any(
      (file) => file is File && file.path.toLowerCase().endsWith('.md'),
    );
    if (hasMarkdownNotes) {
      return;
    }

    final welcomeFile = File(
      '${notesDirectory.path}${Platform.pathSeparator}$_welcomeNoteFileName',
    );
    if (!await welcomeFile.exists()) {
      await welcomeFile.writeAsString(_welcomeNoteContent);
    }
  }

  // 获取所有笔记
  Future<List<Note>> getAllNotes() async {
    final files = notesDirectory.listSync();
    final notes = <Note>[];

    for (var file in files) {
      if (file is File && file.path.endsWith('.md')) {
        try {
          final note = await readNote(file);
          notes.add(note);
        } catch (e) {
          debugPrint('Error reading file ${file.path}: $e');
        }
      }
    }

    // 按修改时间排序，最新的在前
    notes.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return notes;
  }

  // 读取单个笔记
  Future<Note> readNote(File file) async {
    final content = await file.readAsString();
    final fileName = file.path.split(Platform.pathSeparator).last;
    final title = fileName.replaceAll('.md', '');

    // 获取文件统计信息
    final stat = await file.stat();

    return Note(
      title: title,
      content: content,
      createdAt: stat.changed,
      modifiedAt: stat.modified,
    );
  }

  // 创建新笔记
  Future<Note> createNote(String title, {String content = ''}) async {
    final fileName = _sanitizeFileName(title);
    final file = File('${notesDirectory.path}/$fileName.md');

    // 处理文件名冲突
    int counter = 1;
    String finalPath = file.path;
    while (await File(finalPath).exists()) {
      final baseName = fileName.replaceAll(RegExp(r'_\(\d+\)$'), '');
      finalPath = '${notesDirectory.path}/$baseName ($counter).md';
      counter++;
    }

    await File(finalPath).writeAsString(content);

    return Note(title: title, content: content);
  }

  // 保存笔记
  Future<void> saveNote(Note note) async {
    final fileName = _sanitizeFileName(note.title);
    final file = File('${notesDirectory.path}/$fileName.md');

    await file.writeAsString(note.content);
  }

  // 删除笔记
  Future<void> deleteNote(Note note) async {
    final fileName = _sanitizeFileName(note.title);
    final file = File('${notesDirectory.path}/$fileName.md');

    if (await file.exists()) {
      await file.delete();
    }
  }

  // 重命名笔记
  Future<void> renameNote(Note oldNote, String newTitle) async {
    final oldFileName = _sanitizeFileName(oldNote.title);
    final newFileName = _sanitizeFileName(newTitle);

    final oldFile = File('${notesDirectory.path}/$oldFileName.md');
    final newFile = File('${notesDirectory.path}/$newFileName.md');

    if (await oldFile.exists()) {
      await oldFile.rename(newFile.path);
    }
  }

  // 搜索笔记（内容和标题）
  Future<List<Note>> searchNotes(String query) async {
    final allNotes = await getAllNotes();
    final lowerQuery = query.toLowerCase();

    return allNotes
        .where(
          (note) =>
              note.title.toLowerCase().contains(lowerQuery) ||
              note.content.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  // 文件名清理
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\.md$'), '')
        .trim();
  }

  // 导出为HTML
  Future<String> exportAsHtml(Note note) async {
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>${note.title}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
    h1, h2, h3, h4, h5, h6 { margin-top: 24px; margin-bottom: 16px; }
    code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-family: 'Courier New', monospace; }
    pre { background: #f5f5f5; padding: 12px; border-radius: 4px; overflow-x: auto; }
  </style>
</head>
<body>
  <h1>${note.title}</h1>
  <p><small>Created: ${note.createdAt} | Modified: ${note.modifiedAt}</small></p>
  <hr>
  <div id="content">
    <!-- Markdown content will be rendered here -->
  </div>
</body>
</html>
''';
    return html;
  }
}
