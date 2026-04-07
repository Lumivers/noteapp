class Constants {
  // API Configuration
  static const String OPENAI_CHAT_ENDPOINT = '/chat/completions';
  static const int OPENAI_REQUEST_TIMEOUT = 30; // seconds

  // File paths
  static const String NOTES_FOLDER = 'Notes';
  static const String METADATA_FILE = '.noteapp_metadata.json';

  // Default models
  static const String DEFAULT_MODEL = 'gpt-3.5-turbo';
  static const String ADVANCED_MODEL = 'gpt-4';

  // AI Prompts
  static const String POLISH_PROMPT_TEMPLATE = '''请对以下内容进行润色，保持原意并使表达更加清晰、专业：

内容：
{content}

请仅返回润色后的结果，不要添加任何额外说明。''';

  static const String SUMMARY_PROMPT_TEMPLATE = '''请为以下内容生成一个简洁的摘要：

内容：
{content}

摘要：''';

  static const String TRANSLATE_PROMPT_TEMPLATE = '''请将以下内容翻译成中文：

内容：
{content}

翻译结果：''';

  // UI Constants
  static const double EDITOR_FONT_SIZE = 14.0;
  static const double PREVIEW_FONT_SIZE = 16.0;
  static const double MIN_SPLIT_WIDTH = 200.0;

  // Debounce timing
  static const int SEARCH_DEBOUNCE_MS = 300;
  static const int SAVE_DEBOUNCE_MS = 1000;
}
