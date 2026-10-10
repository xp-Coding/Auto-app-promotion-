import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/logging/app_logger.dart';
import 'content_generation_provider.dart';

/// Official Google Gemini API Content Provider (User-supplied API Key)
class GeminiContentProvider implements ContentGenerationProvider {
  final String apiKey;
  final String modelName;
  final http.Client _client;

  GeminiContentProvider({
    required this.apiKey,
    this.modelName = 'gemini-2.0-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Google Gemini API ($modelName)';

  @override
  Future<bool> isAvailable() async {
    return apiKey.trim().isNotEmpty;
  }

  @override
  Future<GeneratedContentResult> generateContent(ContentGenerationRequest request) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Google Gemini API Key is missing. Configure in Autopilot Settings.');
    }

    final prompt = _buildPrompt(request);
    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=${apiKey.trim()}',
    );

    final response = await _client.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'responseMimeType': 'application/json',
        },
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      await AppLogger.warn('ai_generation', 'Gemini API returned status ${response.statusCode}: ${response.body}');
      throw Exception('Gemini API HTTP ${response.statusCode}: ${response.body}');
    }

    final jsonResp = jsonDecode(response.body);
    final candidates = jsonResp['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini API returned empty candidates response.');
    }

    final text = candidates[0]['content']?['parts']?[0]?['text'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini API returned empty text part.');
    }

    try {
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final title = parsed['title'] as String? ?? '${request.app.name} Promotional Post';
      final bodyText = parsed['bodyText'] as String? ?? parsed['body'] as String? ?? '';
      final scriptHook = parsed['scriptHook'] as String? ?? 'Check out ${request.app.name}!';
      final hashtags = parsed['hashtags'] as String? ?? '#${request.app.category.replaceAll(' ', '')} #${request.app.name.replaceAll(' ', '')}';
      final ctaLink = parsed['ctaLink'] as String? ?? request.app.playStoreUrl;
      final visualDirection = parsed['visualDirection'] as String? ?? 'Show ${request.app.name} clean UI screenshot.';

      return GeneratedContentResult(
        title: title,
        bodyText: bodyText,
        scriptHook: scriptHook,
        hashtags: hashtags,
        ctaLink: ctaLink,
        visualDirectionOrThumbnail: visualDirection,
        providerName: name,
      );
    } catch (e) {
      // In case json parsing failed, fallback gracefully using raw text
      return GeneratedContentResult(
        title: '${request.app.name} Update',
        bodyText: text,
        scriptHook: 'Discover ${request.app.name}',
        hashtags: '#${request.app.category.replaceAll(' ', '')}',
        ctaLink: request.app.playStoreUrl,
        visualDirectionOrThumbnail: 'Showcase real app features.',
        providerName: name,
      );
    }
  }

  String _buildPrompt(ContentGenerationRequest request) {
    return '''
You are a senior mobile app growth marketing specialist creating high-converting, compliant organic social media promotional content for a Google Play Store application.

App Details:
- Name: ${request.app.name}
- Category: ${request.app.category}
- Play Store URL: ${request.app.playStoreUrl}
- Short Description: ${request.app.shortDescription ?? 'N/A'}
- Full Description: ${request.app.fullDescription ?? 'N/A'}
- Key Features: ${request.app.mainFeatures.join(', ')}
- Unique Selling Points: ${request.app.uniqueSellingPoints.join(', ')}
- Target Audience: ${request.app.targetAudience ?? 'General daily users'}
- Target Platform: ${request.targetPlatform} (e.g. YouTube, TikTok, Instagram, Facebook)
- Content Format: ${request.contentFormat} (e.g. video_script, caption, reel, story, carousel)
- Campaign Theme: ${request.topicOrTheme ?? 'Feature Awareness'}

STRICT MARKETING & COMPLIANCE RULES:
1. Do NOT fabricate false user reviews, download stats, or fake ratings.
2. Adhere strictly to platform character limits and best practices (engaging hook, concise value presentation, clear call to action).
3. Include 4-6 relevant, focused hashtags (never hashtag stuff).
4. For YouTube Shorts / TikTok / Reels, provide a compelling visual scene description and narration hook.

Respond STRICTLY in valid JSON matching this schema:
{
  "title": "Compelling video/post title",
  "scriptHook": "Attention-grabbing opening 3-second hook",
  "bodyText": "Complete post caption or video script narration",
  "hashtags": "#relevant #hashtags #clean",
  "ctaLink": "${request.app.playStoreUrl}",
  "visualDirection": "Visual and creative staging notes for creator"
}
''';
  }
}
