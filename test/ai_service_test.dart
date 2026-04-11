import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteapp/services/ai_service.dart';

void main() {
  group('AIService', () {
    test('completeContent truncates very long context to reduce request failures',
        () async {
      late String capturedPrompt;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final data = options.data as Map<String, dynamic>;
            final messages = data['messages'] as List<dynamic>;
            capturedPrompt =
                (messages.last as Map<String, dynamic>)['content'].toString();

            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {'content': '续写成功段落'}
                    }
                  ]
                },
              ),
            );
          },
        ),
      );

      final service = AIService(dio: dio)
        ..configure(
          baseUrl: 'https://example.com/v1/',
          apiKey: 'test-key',
          model: 'test-model',
        );

      const headMarker = 'HEAD_MARKER_';
      const tailMarker = '_TAIL_MARKER';
      final longText = '$headMarker${List.filled(9000, 'a').join()}$tailMarker';

      final result = await service.completeContent(longText);

      expect(result, '续写成功段落');
      expect(capturedPrompt, contains(tailMarker));
      expect(capturedPrompt, isNot(contains(headMarker)));
      expect(capturedPrompt, contains('请只输出新增续写内容'));
    });

    test('callAI exposes API status and error detail for badResponse', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 429,
                  data: {
                    'error': {'message': 'rate limit exceeded'}
                  },
                ),
              ),
            );
          },
        ),
      );

      final service = AIService(dio: dio)
        ..configure(
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
          model: 'test-model',
        );

      await expectLater(
        () => service.callAI(prompt: 'hello'),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('API 请求失败 (429): rate limit exceeded'),
          ),
        ),
      );
    });

    test('completeContent rejects blank source text', () async {
      final service = AIService();

      await expectLater(
        () => service.completeContent('   '),
        throwsA(predicate((error) => error.toString().contains('原文为空'))),
      );
    });

    test('callAI auto-continues when finish_reason is length', () async {
      var requestCount = 0;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            if (requestCount == 1) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'choices': [
                      {
                        'message': {'content': '第一段'},
                        'finish_reason': 'length',
                      }
                    ]
                  },
                ),
              );
              return;
            }

            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {'content': '第二段'},
                      'finish_reason': 'stop',
                    }
                  ]
                },
              ),
            );
          },
        ),
      );

      final service = AIService(dio: dio)
        ..configure(
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
          model: 'test-model',
        );

      final result = await service.callAI(prompt: 'hello', maxTokens: 32);

      expect(requestCount, 2);
      expect(result, '第一段\n第二段');
    });

    test('callAI uses adaptive timeout for large prompt', () async {
      Duration? receiveTimeout;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            receiveTimeout = options.receiveTimeout;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {'content': 'ok'},
                      'finish_reason': 'stop',
                    }
                  ]
                },
              ),
            );
          },
        ),
      );

      final service = AIService(dio: dio)
        ..configure(
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
          model: 'test-model',
        );

      await service.callAI(
        prompt: List.filled(14000, 'x').join(),
        maxTokens: 3000,
      );

      expect(receiveTimeout, isNotNull);
      expect(receiveTimeout!.inSeconds, greaterThan(30));
    });

    test('generateSummary chunk-compresses very long text', () async {
      var requestCount = 0;
      final capturedPrompts = <String>[];

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            final data = options.data as Map<String, dynamic>;
            final messages = data['messages'] as List<dynamic>;
            capturedPrompts.add(
              (messages.last as Map<String, dynamic>)['content'].toString(),
            );

            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {'content': 'summary-$requestCount'},
                      'finish_reason': 'stop',
                    }
                  ]
                },
              ),
            );
          },
        ),
      );

      final service = AIService(dio: dio)
        ..configure(
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
          model: 'test-model',
        );

      final longText = List.filled(18000, '段').join();
      final result = await service.generateSummary(longText);

      expect(requestCount, greaterThan(1));
      expect(capturedPrompts.last, contains('分段摘要'));
      expect(result, isNotEmpty);
    });
  });
}
