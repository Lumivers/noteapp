class Settings {
  final bool isDarkMode;
  final String selectedFont;
  final double fontSize;
  final bool syncScrolling;
  final String notesStoragePath;
  final String openaiBaseUrl;
  final String? openaiApiKey;
  final String openaiModel; // gpt-4, gpt-3.5-turbo, etc.
  final String aiSystemPrompt;

  const Settings({
    this.isDarkMode = false,
    this.selectedFont = 'System',
    this.fontSize = 14.0,
    this.syncScrolling = true,
    this.notesStoragePath = '',
    this.openaiBaseUrl = '',
    this.openaiApiKey,
    this.openaiModel = 'gpt-3.5-turbo',
    this.aiSystemPrompt = '',
  });

  // 从JSON构造
  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      isDarkMode: json['isDarkMode'] ?? false,
      selectedFont: json['selectedFont'] ?? 'System',
      fontSize: (json['fontSize'] ?? 14.0).toDouble(),
      syncScrolling: json['syncScrolling'] ?? true,
      notesStoragePath: json['notesStoragePath'] ?? '',
      openaiBaseUrl: json['openaiBaseUrl'] ?? '',
      openaiApiKey: json['openaiApiKey'],
      openaiModel: json['openaiModel'] ?? 'gpt-3.5-turbo',
      aiSystemPrompt: json['aiSystemPrompt'] ?? '',
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'isDarkMode': isDarkMode,
      'selectedFont': selectedFont,
      'fontSize': fontSize,
      'syncScrolling': syncScrolling,
      'notesStoragePath': notesStoragePath,
      'openaiBaseUrl': openaiBaseUrl,
      'openaiApiKey': openaiApiKey,
      'openaiModel': openaiModel,
      'aiSystemPrompt': aiSystemPrompt,
    };
  }

  // 创建副本并修改某些字段
  Settings copyWith({
    bool? isDarkMode,
    String? selectedFont,
    double? fontSize,
    bool? syncScrolling,
    String? notesStoragePath,
    String? openaiBaseUrl,
    String? openaiApiKey,
    String? openaiModel,
    String? aiSystemPrompt,
  }) {
    return Settings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      selectedFont: selectedFont ?? this.selectedFont,
      fontSize: fontSize ?? this.fontSize,
      syncScrolling: syncScrolling ?? this.syncScrolling,
      notesStoragePath: notesStoragePath ?? this.notesStoragePath,
      openaiBaseUrl: openaiBaseUrl ?? this.openaiBaseUrl,
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      openaiModel: openaiModel ?? this.openaiModel,
      aiSystemPrompt: aiSystemPrompt ?? this.aiSystemPrompt,
    );
  }
}
