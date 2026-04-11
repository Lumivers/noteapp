import 'package:dio/dio.dart';
import 'package:noteapp/utils/constants.dart';
import 'dart:convert';

class AIService {
  static const int _maxSinglePassInputChars = 12000;
  static const int _chunkSizeChars = 5000;
  static const int _maxAutoContinueRounds = 3;
  static const int _maxContinuationContextChars = 6000;

  final Dio _dio;
  String? _apiKey;
  String? _baseUrl;
  String _model = Constants.DEFAULT_MODEL;

  AIService({Dio? dio})
      : _dio =
            dio ??
                Dio(
                  BaseOptions(
                    connectTimeout: const Duration(seconds: 10),
                    receiveTimeout:
                        const Duration(seconds: Constants.OPENAI_REQUEST_TIMEOUT),
                    headers: {
                      'Content-Type': 'application/json',
                    },
                  ),
                );

  // 配置API服务
  void configure({
    required String baseUrl,
    required String apiKey,
    String? model,
  }) {
    _baseUrl = _normalizeBaseUrl(baseUrl);
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
    int? timeoutSeconds,
    bool enableAutoContinue = true,
  }) async {
    if (!isConfigured()) {
      throw Exception('请先在设置中填写 API 地址与 API Key');
    }

    try {
      final messages = <Map<String, String>>[
        if (systemMessage != null) {'role': 'system', 'content': systemMessage},
        {'role': 'user', 'content': prompt},
      ];

      final resolvedTimeout = timeoutSeconds ??
          _estimateTimeoutSeconds(
            promptChars: prompt.length,
            maxTokens: maxTokens,
          );

      final first = await _requestChatCompletion(
        messages: messages,
        temperature: temperature,
        maxTokens: maxTokens,
        timeoutSeconds: resolvedTimeout,
      );

      var merged = first.content;
      var lastChunk = first.content;
      var finishReason = first.finishReason;
      var rounds = 0;

      while (enableAutoContinue &&
          finishReason == 'length' &&
          rounds < _maxAutoContinueRounds) {
        messages.add({'role': 'assistant', 'content': lastChunk});
        messages.add({
          'role': 'user',
          'content': '请从上次结束处继续输出剩余内容，不要重复已输出文本。',
        });

        final next = await _requestChatCompletion(
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
          timeoutSeconds: resolvedTimeout,
        );

        if (next.content.trim().isEmpty) {
          break;
        }

        lastChunk = next.content;
        merged = '${merged.trim()}\n${next.content.trim()}';
        finishReason = next.finishReason;
        rounds++;
      }

      return merged.trim();
    } on DioException catch (e) {
      throw Exception(_formatDioException(e));
    }
  }

  Future<_ChatCompletionResult> _requestChatCompletion({
    required List<Map<String, String>> messages,
    required double temperature,
    required int maxTokens,
    required int timeoutSeconds,
  }) async {
    final response = await _dio.post(
      Constants.OPENAI_CHAT_ENDPOINT,
      data: {
        'model': _model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      },
      options: Options(
        receiveTimeout: Duration(seconds: timeoutSeconds),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final data = response.data;
    final choices =
        data is Map<String, dynamic> ? data['choices'] as List<dynamic>? : null;
    if (choices == null || choices.isEmpty) {
      throw Exception('API 返回格式异常：缺少 choices');
    }

    final firstChoice = choices.first as Map<String, dynamic>;
    final result = firstChoice['message']?['content'];
    if (result == null) {
      throw Exception('API 返回格式异常：缺少 message.content');
    }

    final finishReason = firstChoice['finish_reason']?.toString();
    return _ChatCompletionResult(
      content: result.toString().trim(),
      finishReason: finishReason,
    );
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
          receiveTimeout: Duration(
            seconds: _estimateTimeoutSeconds(
              promptChars: prompt.length,
              maxTokens: 2000,
            ),
          ),
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
      throw Exception(_formatDioException(e));
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
    final chunks = _splitTextIntoChunks(text);

    if (chunks.length == 1) {
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

    final rewritten = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final prompt = '''你将处理一篇长文的分片 ${i + 1}/${chunks.length}。

指令：
$instruction

分片原文：
$chunk

要求：
1. 仅返回此分片改写后的正文。
2. 不要添加解释或标题。
3. 保持与原分片对应的语义。''';
      final part = await callAI(
        prompt: prompt,
        systemMessage: systemMessage,
        temperature: 0.5,
        maxTokens: 1400,
      );
      rewritten.add(part);
    }

    return rewritten.join('\n\n');
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
    final chunks = _splitTextIntoChunks(text);

    if (chunks.length == 1) {
      final prompt =
          Constants.POLISH_PROMPT_TEMPLATE.replaceAll('{content}', text);
      return await callAI(
        prompt: prompt,
        systemMessage:
            'You are a professional writer who excels at refining and polishing text.',
        temperature: 0.5,
      );
    }

    final polished = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      final prompt = '''请对以下长文分片进行润色，保持原意并提升表达质量。

当前分片：${i + 1}/${chunks.length}

内容：
${chunks[i]}

请仅返回润色后的分片文本。''';
      polished.add(
        await callAI(
          prompt: prompt,
          systemMessage:
              'You are a professional writer who excels at refining and polishing text.',
          temperature: 0.5,
          maxTokens: 1400,
        ),
      );
    }

    return polished.join('\n\n');
  }

  // 生成摘要
  Future<String> generateSummary(String text) async {
    final chunks = _splitTextIntoChunks(text);

    if (chunks.length == 1) {
      final prompt =
          Constants.SUMMARY_PROMPT_TEMPLATE.replaceAll('{content}', text);
      return await callAI(
        prompt: prompt,
        systemMessage:
            'You are a skilled summarizer. Create concise, clear summaries.',
        temperature: 0.3,
      );
    }

    final partialSummaries = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      final partPrompt = '''请先总结长文第 ${i + 1}/${chunks.length} 段，输出该段的关键要点（3-6条）。

内容：
${chunks[i]}

仅输出要点，不要解释。''';
      partialSummaries.add(
        await callAI(
          prompt: partPrompt,
          systemMessage:
              'You are a skilled summarizer. Create concise, clear summaries.',
          temperature: 0.2,
          maxTokens: 700,
        ),
      );
    }

    final mergedPrompt = '''以下是同一篇长文的分段摘要，请将它们合并成一份结构清晰的总摘要。

${partialSummaries.join('\n\n')}

要求：
1. 信息不重复。
2. 覆盖核心结论与关键细节。
3. 输出简洁。''';

    return await callAI(
      prompt: mergedPrompt,
      systemMessage:
          'You are a skilled summarizer. Create concise, clear summaries.',
      temperature: 0.3,
      maxTokens: 1000,
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
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw Exception('原文为空，无法续写');
    }

    final isTruncated = normalized.length > _maxContinuationContextChars;
    final context = isTruncated
        ? normalized.substring(
            normalized.length - _maxContinuationContextChars,
          )
        : normalized;

    final prompt = isTruncated
        ? '请基于以下“文章末尾片段”继续写作，保持语气与逻辑一致。\n\n'
            '注意：这是截取的末尾上下文，不是全文。\n\n'
            '$context\n\n'
            '请只输出新增续写内容，不要重复片段里的原文。'
        : 'Based on the following content, continue and expand it naturally:\n\n'
            '$context\n\n'
            'Please return only the newly continued content and do not repeat the original content.';
    return await callAI(
      prompt: prompt,
      systemMessage:
          'You are a helpful writing assistant. Continue the user\'s content naturally and coherently.',
      temperature: 0.7,
    );
  }

  String _normalizeBaseUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  String _formatDioException(DioException e) {
    if (e.type == DioExceptionType.badResponse) {
      final status = e.response?.statusCode;
      final responseData = e.response?.data;
      String apiMessage = '服务端返回异常';

      if (responseData is Map<String, dynamic>) {
        final error = responseData['error'];
        if (error is Map<String, dynamic> && error['message'] != null) {
          apiMessage = error['message'].toString();
        } else if (responseData['message'] != null) {
          apiMessage = responseData['message'].toString();
        }
      } else if (responseData != null) {
        apiMessage = responseData.toString();
      }

      return 'API 请求失败 (${status ?? 'unknown'}): $apiMessage';
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '请求超时，请检查网络或稍后重试';
    }

    if (e.type == DioExceptionType.connectionError) {
      return '网络连接失败，请检查网络后重试';
    }

    if (e.type == DioExceptionType.cancel) {
      return '请求已取消';
    }

    return '网络请求失败: ${e.message ?? 'unknown'}';
  }

  int _estimateTimeoutSeconds({
    required int promptChars,
    required int maxTokens,
  }) {
    final base = Constants.OPENAI_REQUEST_TIMEOUT;
    final byPrompt = (promptChars / 2500).ceil() * 8;
    final byTokens = (maxTokens / 700).ceil() * 8;
    final estimated = base + byPrompt + byTokens;

    if (estimated < 30) {
      return 30;
    }
    if (estimated > 180) {
      return 180;
    }
    return estimated;
  }

  List<String> _splitTextIntoChunks(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const [''];
    }

    if (normalized.length <= _maxSinglePassInputChars) {
      return [normalized];
    }

    final paragraphs = normalized.split(RegExp(r'\n{2,}'));
    final chunks = <String>[];
    var current = '';

    for (final paragraph in paragraphs) {
      final part = paragraph.trim();
      if (part.isEmpty) {
        continue;
      }

      final next = current.isEmpty ? part : '$current\n\n$part';
      if (next.length <= _chunkSizeChars) {
        current = next;
        continue;
      }

      if (current.isNotEmpty) {
        chunks.add(current);
        current = '';
      }

      if (part.length <= _chunkSizeChars) {
        current = part;
      } else {
        var start = 0;
        while (start < part.length) {
          final end = (start + _chunkSizeChars > part.length)
              ? part.length
              : start + _chunkSizeChars;
          chunks.add(part.substring(start, end));
          start = end;
        }
      }
    }

    if (current.isNotEmpty) {
      chunks.add(current);
    }

    return chunks;
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

class _ChatCompletionResult {
  final String content;
  final String? finishReason;

  const _ChatCompletionResult({
    required this.content,
    required this.finishReason,
  });
}
