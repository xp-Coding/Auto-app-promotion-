import '../../../core/logging/app_logger.dart';
import '../../autopilot/models/autopilot_settings_model.dart';
import 'content_generation_provider.dart';
import 'gemini_content_provider.dart';
import 'ollama_content_provider.dart';
import 'template_content_provider.dart';

/// Intelligent content provider that routes between Local Templates,
/// Google Gemini API, and Local LLM (Ollama) with guaranteed offline fallback.
class SmartContentProvider implements ContentGenerationProvider {
  final AutopilotSettingsModel settings;
  final TemplateContentProvider _templateProvider;
  final ContentGenerationProvider? customProvider;

  SmartContentProvider({
    required this.settings,
    TemplateContentProvider? templateProvider,
    this.customProvider,
  })  : _templateProvider = templateProvider ?? TemplateContentProvider();

  @override
  String get name {
    if (customProvider != null) return customProvider!.name;
    switch (settings.aiProvider) {
      case 'gemini':
        return 'Google Gemini API (${settings.aiModelName ?? 'gemini-2.0-flash'})';
      case 'local':
        return 'Ollama Local Model (${settings.aiModelName ?? 'llama3'})';
      default:
        return 'Local Template Engine (100% Offline & Free)';
    }
  }

  @override
  Future<bool> isAvailable() async => true; // Always available via offline templates

  @override
  Future<GeneratedContentResult> generateContent(ContentGenerationRequest request) async {
    // If a custom provider is injected (e.g. for testing)
    if (customProvider != null) {
      return customProvider!.generateContent(request);
    }

    // 1. Google Gemini option
    if (settings.aiProvider == 'gemini' &&
        settings.aiApiKey != null &&
        settings.aiApiKey!.trim().isNotEmpty) {
      try {
        final gemini = GeminiContentProvider(
          apiKey: settings.aiApiKey!.trim(),
          modelName: settings.aiModelName ?? 'gemini-2.0-flash',
        );
        final result = await gemini.generateContent(request);
        await AppLogger.info('ai_generation', 'Content generated via Google Gemini for ${request.targetPlatform}.');
        return result;
      } catch (e) {
        await AppLogger.warn(
          'ai_generation',
          'Gemini API request failed ($e). Falling back to Local Template Engine.',
        );
      }
    }

    // 2. Local Ollama LLM option
    if (settings.aiProvider == 'local') {
      try {
        final ollama = OllamaContentProvider(
          modelName: settings.aiModelName ?? 'llama3',
        );
        final isAvail = await ollama.isAvailable();
        if (isAvail) {
          final result = await ollama.generateContent(request);
          await AppLogger.info('ai_generation', 'Content generated via Ollama Local LLM for ${request.targetPlatform}.');
          return result;
        } else {
          await AppLogger.info('ai_generation', 'Ollama service offline. Falling back to Local Template Engine.');
        }
      } catch (e) {
        await AppLogger.warn('ai_generation', 'Ollama generation failed ($e). Falling back to Local Template Engine.');
      }
    }

    // 3. Guaranteed Local Template Fallback (Zero cost, offline, instantaneous)
    final templateResult = await _templateProvider.generateContent(request);
    return GeneratedContentResult(
      title: templateResult.title,
      bodyText: templateResult.bodyText,
      scriptHook: templateResult.scriptHook,
      hashtags: templateResult.hashtags,
      ctaLink: templateResult.ctaLink,
      visualDirectionOrThumbnail: templateResult.visualDirectionOrThumbnail,
      alternativeTitles: templateResult.alternativeTitles,
      providerName: 'Local Template Engine (Offline)',
    );
  }
}
