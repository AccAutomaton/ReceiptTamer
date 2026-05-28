import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:receipt_tamer/data/models/llm_backend.dart';
import 'package:receipt_tamer/data/services/openai_compatible_backend.dart';

void main() {
  test('normalizes endpoint and merges safe extra JSON params', () {
    final backend = OpenAiCompatibleBackend(
      config: const OpenAiCompatibleConfig(
        endpoint: 'https://api.example.com/v1',
        modelName: 'qwen-plus',
        apiKey: 'secret',
        extraParamsJson:
            '{"temperature":0,"enable_thinking":false,"messages":"ignored"}',
      ),
    );

    final body = backend.buildRequestBody(
      const LlmRequest.text(prompt: 'Extract JSON'),
    );

    expect(
      OpenAiCompatibleBackend.chatCompletionsUri(
        'https://api.example.com/v1',
      ).toString(),
      'https://api.example.com/v1/chat/completions',
    );
    expect(body['model'], 'qwen-plus');
    expect(body['temperature'], 0);
    expect(body['enable_thinking'], false);
    expect(body['messages'], isA<List<dynamic>>());
  });

  test('normalizes models endpoint for OpenAI-compatible providers', () {
    expect(
      OpenAiCompatibleBackend.modelsUri('https://api.example.com').toString(),
      'https://api.example.com/v1/models',
    );
    expect(
      OpenAiCompatibleBackend.modelsUri(
        'https://api.example.com/v1',
      ).toString(),
      'https://api.example.com/v1/models',
    );
    expect(
      OpenAiCompatibleBackend.modelsUri(
        'https://api.example.com/v1/chat/completions',
      ).toString(),
      'https://api.example.com/v1/models',
    );
  });

  test('multimodal requests send base64 image_url content parts', () {
    final backend = OpenAiCompatibleBackend(
      config: const OpenAiCompatibleConfig(
        endpoint: 'https://api.example.com',
        modelName: 'qwen-vl',
        apiKey: 'secret',
        isMultimodal: true,
      ),
    );

    final body = backend.buildRequestBody(
      LlmRequest.image(
        prompt: 'Read the receipt',
        imageBytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      ),
    );

    final messages = body['messages'] as List<dynamic>;
    final content =
        (messages.single as Map<String, dynamic>)['content'] as List<dynamic>;

    expect(content.first, {'type': 'text', 'text': 'Read the receipt'});
    expect(content.last, {
      'type': 'image_url',
      'image_url': {'url': 'data:image/png;base64,AQID'},
    });
  });

  test('complete parses content and ignores returned token usage', () async {
    late http.Request captured;
    final backend = OpenAiCompatibleBackend(
      config: const OpenAiCompatibleConfig(
        endpoint: 'https://api.example.com/v1/chat/completions',
        modelName: 'qwen-plus',
        apiKey: 'secret',
      ),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '{"amount":12.3}'},
              },
            ],
            'usage': {
              'prompt_tokens': 11,
              'completion_tokens': 7,
              'total_tokens': 18,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final completion = await backend.complete(
      const LlmRequest.text(prompt: 'Extract JSON'),
    );

    expect(
      captured.url.toString(),
      'https://api.example.com/v1/chat/completions',
    );
    expect(captured.headers['authorization'], 'Bearer secret');
    expect(completion.text, '{"amount":12.3}');
  });

  test('complete reports HTTP failures without leaking response body', () async {
    final backend = OpenAiCompatibleBackend(
      config: const OpenAiCompatibleConfig(
        endpoint: 'https://api.example.com/v1',
        modelName: 'qwen-plus',
        apiKey: 'secret',
      ),
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'bad_request',
              'message':
                  'invalid request for secret-prompt data:image/png;base64,AAAA',
            },
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      backend.complete(const LlmRequest.text(prompt: 'secret-prompt')),
      throwsA(
        predicate((Object error) {
          final message = error.toString();
          return message.contains('HTTP 400') &&
              message.contains('bad_request') &&
              !message.contains('secret-prompt') &&
              !message.contains('data:image') &&
              !message.contains('AAAA');
        }),
      ),
    );
  });

  test('listModels fetches model ids with authorization header', () async {
    late http.Request captured;
    final backend = OpenAiCompatibleBackend(
      config: const OpenAiCompatibleConfig(
        endpoint: 'https://api.example.com/v1',
        modelName: 'qwen-plus',
        apiKey: 'secret',
      ),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'object': 'list',
            'data': [
              {'id': 'model-a'},
              {'id': 'model-b'},
              {'not_id': 'ignored'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final models = await backend.listModels();

    expect(captured.method, 'GET');
    expect(captured.url.toString(), 'https://api.example.com/v1/models');
    expect(captured.headers['authorization'], 'Bearer secret');
    expect(models, ['model-a', 'model-b']);
  });

  test('listModels reports API key error for unauthorized responses', () async {
    final backend = OpenAiCompatibleBackend(
      config: const OpenAiCompatibleConfig(
        endpoint: 'https://api.example.com/v1',
        modelName: 'qwen-plus',
        apiKey: 'wrong-secret',
      ),
      client: MockClient((request) async {
        return http.Response('Unauthorized', 401);
      }),
    );

    expect(
      backend.listModels(),
      throwsA(
        predicate(
          (Object error) => error.toString().contains('API Key 错误'),
          'error text contains API Key 错误',
        ),
      ),
    );
  });
}
