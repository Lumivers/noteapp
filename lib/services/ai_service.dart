import 'package:dio/dio.dart';
import 'package:noteapp/utils/constants.dart';
import 'dart:convert';

class AIService {
  late Dio _dio;
  String? _apiKey;
  String? _baseUrl;
  String _model = Constants.DEFAULT_MODEL;

  AIService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout:
            const Duration(seconds: Constants.OPENAI_REQUEST_TIMEOUT),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  // 配置API服务
  void configure({
    required String baseUrl,
    required String apiKey,
    String? model,
  }) {
    _baseUrl = baseUrl.trim();
    _apiKey = apiKey;
    if (model != null) {
      _model = model;
    }
    _dio.options.baseUrl = _baseUrl!;
    _dio.options.headers['Authorization'] = 'Bearer $_apiKey';
  }

  bool isConfigured() {
    return _baseUrl != null &&
        _baseUrl!.isNotEmpty &&
        _apiKey != null &&
        _apiKey!.isNotEmpty;
  }

  // 通用的AI调用方法（文本完成）
  Future<String> callAI({
    required String prompt,
    String? systemMessage,
    double temperature = 0.7,
    int maxTokens = 2000,
  }) async {
    if (!isConfigured()) {
      throw Exception('请先在设置中填写 API 地址与 API Key');
    }

    try {
      final messages = <Map<String, String>>[
        if (systemMessage != null) {'role': 'system', 'content': systemMessage},
        {'role': 'user', 'content': prompt},
      ];

      final response = await _dio.post(
        Constants.OPENAI_CHAT_ENDPOINT,
        data: {
          'model': _model,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        },
      );

      if (response.statusCode == 200) {
        final result = response.data['choices'][0]['message']['content'];
        return result.toString().trim();
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求失败: ${e.message}');
    }
  }

  // 流式调用AI（用于实时显示）
  Stream<String> callAIStreaming({
    required String prompt,
    String? systemMessage,
    double temperature = 0.7,
  }) async* {
    if (!isConfigured()) {
      throw Exception('请先在设置中填写 API 地址与 API Key');
    }

    try {
      final messages = <Map<String, String>>[
        if (systemMessage != null) {'role': 'system', 'content': systemMessage},
        {'role': 'user', 'content': prompt},
      ];

      final response = await _dio.post(
        Constants.OPENAI_CHAT_ENDPOINT,
        data: {
          'model': _model,
          'messages': messages,
          'temperature': temperature,
          'stream': true,
        },
        options: Options(
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode == 200) {
        await for (var line in _parseStreamResponse(response.data)) {
          yield line;
        }
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('网络请求失败: ${e.message}');
    }
  }

  // 测试当前配置是否可用
  Future<void> testConnection() async {
    await callAI(
      prompt: 'Reply with OK only.',
      systemMessage: 'You are a health check assistant.',
      temperature: 0,
      maxTokens: 8,
    );
  }

  // 按用户自定义指令改写文本
  Future<String> rewriteWithInstruction({
    required String text,
    required String instruction,
    String? systemMessage,
  }) async {
    final prompt = '''请根据以下指令处理文本。

指令：
$instruction

原文：
$text

请直接返回处理后的文本，不要输出解释。''';
    return await callAI(
      prompt: prompt,
      systemMessage: systemMessage,
      temperature: 0.5,
    );
  }

  // 解析流式响应
  Stream<String> _parseStreamResponse(ResponseBody responseBody) async* {
    final stream = responseBody.stream;

    await for (var chunk in stream) {
      final str = String.fromCharCodes(chunk);
      final lines = str.split('\n');

      for (var line in lines) {
        if (line.isEmpty || line == '[DONE]') continue;

        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6);
          try {
            final json = jsonDecode(jsonStr);
            final content = json['choices'][0]['delta']['content'];
            if (content != null) {
              yield content as String;
            }
          } catch (e) {
            // Skip invalid JSON
          }
        }
      }
    }
  }

  // 润色文本
  Future<String> polishText(String text) async {
    final prompt =
        Constants.POLISH_PROMPT_TEMPLATE.replaceAll('{content}', text);
    return await callAI(
      prompt: prompt,
      systemMessage:
          'You are a professional writer who excels at refining and polishing text.',
      temperature: 0.5,
    );
  }

  // 生成摘要
  Future<String> generateSummary(String text) async {
    final prompt =
        Constants.SUMMARY_PROMPT_TEMPLATE.replaceAll('{content}', text);
    return await callAI(
      prompt: prompt,
      systemMessage:
          'You are a skilled summarizer. Create concise, clear summaries.',
      temperature: 0.3,
    );
  }

  // 翻译文本
  Future<String> translateText(String text,
      {String targetLang = 'Chinese'}) async {
    final prompt =
        'Please translate the following content to $targetLang:\n\n$text\n\nTranslation:';
    return await callAI(
      prompt: prompt,
      systemMessage:
          'You are a professional translator. Provide accurate translations.',
      temperature: 0.3,
    );
  }

  // AI内容补全
  Future<String> completeContent(String text) async {
    final prompt =
        'Based on the following content, continue and expand it naturally:\n\n$text\n\nContinued content:';
    return await callAI(
      prompt: prompt,
      systemMessage:
          'You are a helpful writing assistant. Continue the user\'s content naturally and coherently.',
      temperature: 0.7,
    );
  }

  // 搜索相关笔记的AI建议
  Future<List<String>> getSearchSuggestions(String query) async {
    final prompt =
        'Given the search query "$query", suggest 5 related search terms or topics that might be helpful. Return only the suggestions as a comma-separated list.';
    final result = await callAI(
      prompt: prompt,
      temperature: 0.5,
      maxTokens: 200,
    );
    return result.split(',').map((s) => s.trim()).toList();
  }
}
