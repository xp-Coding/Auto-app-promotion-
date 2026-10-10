import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/logging/app_logger.dart';
import 'content_generation_provider.dart';

/// Local LLM Content Provider (Ollama / LocalAI / LM Studio)
class OllamaContentProvider implements ContentGenerationProvider {
  final String hostUrl;
  final String modelName;
  final http.Client _client;

  OllamaContentProvider({
    this.hostUrl = 'http://127.0.0.1:11434',
    this.modelName = 'llama3',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Ollama Local Model ($modelName)';

  @override
  Future<bool> isAvailable() async {
    try {
      final res = await _client.get(Uri.parse('$hostUrl/api/tags')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<GeneratedContentResult> generateContent(ContentGenerationRequest request) async {
    final prompt = '''
Create marketing promotional post for ${request.app.name} on ${request.targetPlatform} (${request.contentFormat}).
Category: ${request.app.category}
Features: ${request.app.mainFeatures.join(', ')}
Theme: ${request.topicOrTheme ?? 'General'}
URL: ${request.app.playStoreUrl}

Output valid JSON only:
{"title":"...","scriptHook":"...","bodyText":"...","hashtags":"...","ctaLink":"${request.app.playStoreUrl}","visualDirection":"..."}
''';

    final response = await _client.post(
      Uri.parse('$hostUrl/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': modelName,
        'prompt': prompt,
        'format': 'json',
        'stream': false,
      }),
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode != 200) {
      await AppLogger.warn('ai_generation', 'Ollama returned HTTP ${response.statusCode}');
      throw Exception('Ollama error HTTP ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['response'] as String? ?? '';
    final parsed = jsonDecode(text) as Map<String, dynamic>;

    return GeneratedContentResult(
      title: parsed['title'] as String? ?? '${request.app.name} Post',
      bodyText: parsed['bodyText'] as String? ?? '',
      scriptHook: parsed['scriptHook'] as String? ?? '',
      hashtags: parsed['hashtags'] as String? ?? '#${request.app.category.replaceAll(' ', '')}',
      ctaLink: parsed['ctaLink'] as String? ?? request.app.playStoreUrl,
      visualDirectionOrThumbnail: parsed['visualDirection'] as String? ?? 'Show UI screenshot',
      providerName: name,
    );
  }
}
