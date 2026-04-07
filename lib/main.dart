import 'package:flutter/material.dart';
import 'package:noteapp/models/note.dart';
import 'package:noteapp/screens/home_screen.dart';
import 'package:noteapp/screens/editor_screen.dart';
import 'package:noteapp/services/file_service.dart';
import 'package:noteapp/services/ai_service.dart';
import 'package:noteapp/services/theme_service.dart';
import 'package:noteapp/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化所有服务
  final settingsService = SettingsService();
  await settingsService.initialize();

  final fileService = FileService();
  final settings = await settingsService.getSettings();
  await fileService.initialize(
    customDirectoryPath: settings.notesStoragePath,
  );

  final themeService = ThemeService();
  await themeService.initialize();

  runApp(
    MyApp(
      fileService: fileService,
      themeService: themeService,
      settingsService: settingsService,
    ),
  );
}

class MyApp extends StatefulWidget {
  final FileService fileService;
  final ThemeService themeService;
  final SettingsService settingsService;

  const MyApp({
    required this.fileService,
    required this.themeService,
    required this.settingsService,
    super.key,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AIService _aiService;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _aiService = AIService();
    _isDarkMode = widget.themeService.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteApp',
      debugShowCheckedModeBanner: false,
      theme: widget.themeService.getLightTheme(),
      darkTheme: widget.themeService.getDarkTheme(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _HomePage(
        fileService: widget.fileService,
        aiService: _aiService,
        themeService: widget.themeService,
        settingsService: widget.settingsService,
        onThemeToggle: _toggleTheme,
      ),
    );
  }

  void _toggleTheme() async {
    await widget.themeService.toggleTheme();
    setState(() {
      _isDarkMode = widget.themeService.isDarkMode;
    });
  }
}

class _HomePage extends StatefulWidget {
  final FileService fileService;
  final AIService aiService;
  final ThemeService themeService;
  final SettingsService settingsService;
  final VoidCallback onThemeToggle;

  const _HomePage({
    required this.fileService,
    required this.aiService,
    required this.themeService,
    required this.settingsService,
    required this.onThemeToggle,
  });

  @override
  State<_HomePage> createState() => __HomePageState();
}

class __HomePageState extends State<_HomePage> {
  Note? _currentNote;

  @override
  Widget build(BuildContext context) {
    if (_currentNote != null) {
      return EditorScreen(
        initialNote: _currentNote!,
        fileService: widget.fileService,
        aiService: widget.aiService,
        settingsService: widget.settingsService,
        onNoteUpdated: () {
          setState(() {
            _currentNote = null;
          });
        },
      );
    }

    return HomeScreen(
      fileService: widget.fileService,
      settingsService: widget.settingsService,
      onEditNote: (note) {
        setState(() {
          _currentNote = note;
        });
      },
      onThemeToggle: widget.onThemeToggle,
    );
  }
}
