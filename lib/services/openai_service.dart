import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// OpenAI-compatible chat service (works with SiliconFlow, OpenAI, etc.)
///
/// Base URL example: https://api.siliconflow.cn/v1
class OpenAIService {
  final String apiKey;
  final String model;
  final String baseUrl;

  final Map<String, List<Map<String, String>>> _sessionHistory = {};

  OpenAIService({
    required this.apiKey,
    required this.model,
    required this.baseUrl,
  });

  /// Clear conversation history for a session.
  void clearConversation(String sessionId) {
    _sessionHistory.remove(sessionId);
  }

  String get _chatUrl => '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions';

  /// Fetch available models from /models endpoint.
  static Future<List<String>> fetchModels({
    required String apiUrl,
    required String apiKey,
  }) async {
    try {
      final base = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/models');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw Exception('接口返回${res.statusCode}: ${res.body}');
      }
      final data = jsonDecode(res.body);
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => (e as Map<String, dynamic>)['id'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      return list;
    } catch (e) {
      throw Exception('无法获取模型列表: $e');
    }
  }

  /// Stream a chat completion; callback receives incremental text chunks.
  Future<void> streamChat(
    String message, {
    required void Function(String delta) onDelta,
    required void Function(String full) onDone,
    required void Function(String error) onError,
    String sessionId = 'default',
    bool forceNewConversation = false,
  }) async {
    try {
      if (forceNewConversation) {
        _sessionHistory.remove(sessionId);
      }
      final history = _sessionHistory.putIfAbsent(sessionId, () => []);
      history.add({'role': 'user', 'content': message});

      final body = jsonEncode({
        'model': model,
        'messages': history,
        'temperature': 0.7,
        'max_tokens': 4096,
        'stream': true,
      });

      final request = http.Request('POST', Uri.parse(_chatUrl))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        })
        ..body = body;

      final response = await request.send().timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        onError('接口返回${response.statusCode}: ${errBody.length > 200 ? errBody.substring(0, 200) : errBody}');
        return;
      }

      final buffer = StringBuffer();
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer.write(chunk);
        final text = buffer.toString();
        // Process complete SSE lines
        final lines = text.split('\n');
        if (lines.length > 1) {
          buffer.clear();
          buffer.write(lines.removeLast());
          for (final line in lines) {
            _handleSseLine(line, onDelta);
          }
        }
      }
      // Flush remaining buffer
      _handleSseLine(buffer.toString(), onDelta);

      final full = _assistantText.toString();
      _assistantText.clear();
      // Save assistant reply to history
      history.add({'role': 'assistant', 'content': full});
      onDone(full);
    } catch (e) {
      onError('请求失败: $e');
    }
  }

  final StringBuffer _assistantText = StringBuffer();

  void _handleSseLine(String line, void Function(String) onDelta) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.startsWith('data:')) {
      final data = trimmed.substring(5).trim();
      if (data == '[DONE]') return;
      try {
        final obj = jsonDecode(data);
        final choices = obj['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) return;
        final delta = choices[0]['delta'] as Map<String, dynamic>? ?? {};
        // Some reasoning models put text in reasoning_content first
        String? content = delta['content'] as String?;
        if (content == null || content.isEmpty) {
          content = delta['reasoning_content'] as String?;
        }
        if (content != null && content.isNotEmpty) {
          _assistantText.write(content);
          onDelta(content);
        }
      } catch (e) {
        // ignore malformed JSON chunks
      }
    }
  }

  /// Generate speech via OpenAI-compatible TTS endpoint (/audio/speech).
  static Future<File?> tts({
    required String apiUrl,
    required String apiKey,
    required String ttsModel,
    required String ttsVoice,
    required String text,
    required String outputPath,
  }) async {
    try {
      final base = apiUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/audio/speech');
      final body = jsonEncode({
        'model': ttsModel,
        'input': text,
        'voice': ttsVoice,
        'response_format': 'mp3',
        'speed': 1.0,
      });
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        print('TTS失败: ${res.statusCode} ${res.body}');
        return null;
      }
      final file = File(outputPath);
      await file.writeAsBytes(res.bodyBytes, flush: true);
      return file;
    } catch (e) {
      print('TTS异常: $e');
      return null;
    }
  }
}
