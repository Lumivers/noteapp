import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noteapp/models/settings.dart';

class SettingsService {
  final _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  static const String _apiKeyKey = 'openai_api_key';
  static const String _baseUrlKey = 'openai_base_url';
  static const String _modelKey = 'openai_model';
  static const String _systemPromptKey = 'ai_system_prompt';
  static const String _notesStoragePathKey = 'notes_storage_path';
  static const String _darkModeKey = 'isDarkMode';
  static const String _fontSizeKey = 'fontSize';
  static const String _syncScrollKey = 'syncScrolling';

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 获取当前设置
  Future<Settings> getSettings() async {
    final apiKey = await _secureStorage.read(key: _apiKeyKey);
    final baseUrl = _prefs.getString(_baseUrlKey) ?? '';
    final model = _prefs.getString(_modelKey) ?? 'gpt-3.5-turbo';
    final systemPrompt = _prefs.getString(_systemPromptKey) ?? '';
    final notesStoragePath = _prefs.getString(_notesStoragePathKey) ?? '';
    final isDarkMode = _prefs.getBool(_darkModeKey) ?? false;
    final fontSize = _prefs.getDouble(_fontSizeKey) ?? 14.0;
    final syncScroll = _prefs.getBool(_syncScrollKey) ?? true;

    return Settings(
      isDarkMode: isDarkMode,
      fontSize: fontSize,
      syncScrolling: syncScroll,
      notesStoragePath: notesStoragePath,
      openaiBaseUrl: baseUrl,
      openaiApiKey: apiKey,
      openaiModel: model,
      aiSystemPrompt: systemPrompt,
    );
  }

  // 保存API密钥（使用安全存储）
  Future<void> setApiKey(String apiKey) async {
    if (apiKey.isEmpty) {
      await _secureStorage.delete(key: _apiKeyKey);
    } else {
      await _secureStorage.write(key: _apiKeyKey, value: apiKey);
    }
  }

  // 获取API密钥
  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: _apiKeyKey);
  }

  // 设置模型
  Future<void> setModel(String model) async {
    await _prefs.setString(_modelKey, model);
  }

  // 设置OpenAI兼容接口基础URL
  Future<void> setBaseUrl(String baseUrl) async {
    await _prefs.setString(_baseUrlKey, baseUrl);
  }

  // 设置全局系统提示词
  Future<void> setSystemPrompt(String prompt) async {
    await _prefs.setString(_systemPromptKey, prompt);
  }

  // 一次性保存AI配置
  Future<void> saveAiConfig({
    required String baseUrl,
    required String apiKey,
    required String model,
    String systemPrompt = '',
  }) async {
    await setBaseUrl(baseUrl);
    await setApiKey(apiKey);
    await setModel(model);
    await setSystemPrompt(systemPrompt);
  }

  // 设置深色模式
  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(_darkModeKey, isDark);
  }

  // 设置字体大小
  Future<void> setFontSize(double size) async {
    await _prefs.setDouble(_fontSizeKey, size);
  }

  // 设置滚动同步
  Future<void> setSyncScrolling(bool sync) async {
    await _prefs.setBool(_syncScrollKey, sync);
  }

  Future<void> setNotesStoragePath(String path) async {
    if (path.trim().isEmpty) {
      await _prefs.remove(_notesStoragePathKey);
      return;
    }
    await _prefs.setString(_notesStoragePathKey, path.trim());
  }

  // 清除所有设置
  Future<void> clearAll() async {
    await _secureStorage.delete(key: _apiKeyKey);
    await _prefs.clear();
  }
}
