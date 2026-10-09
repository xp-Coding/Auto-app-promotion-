import '../../apps/models/app_model.dart';
import '../../campaigns/models/campaign_model.dart';

class ContentGenerationRequest {
  final AppModel app;
  final CampaignModel? campaign;
  final String targetPlatform; // YouTube, Facebook, Instagram, TikTok
  final String contentFormat; // video_script, caption, reel, story, carousel
  final String? topicOrTheme;
  final String? customInstructions;

  const ContentGenerationRequest({
    required this.app,
    this.campaign,
    required this.targetPlatform,
    required this.contentFormat,
    this.topicOrTheme,
    this.customInstructions,
  });
}

class GeneratedContentResult {
  final String title;
  final String bodyText;
  final String scriptHook;
  final String hashtags;
  final String ctaLink;
  final String visualDirectionOrThumbnail;
  final List<String> alternativeTitles;
  final String providerName;

  const GeneratedContentResult({
    required this.title,
    required this.bodyText,
    required this.scriptHook,
    required this.hashtags,
    required this.ctaLink,
    required this.visualDirectionOrThumbnail,
    this.alternativeTitles = const [],
    required this.providerName,
  });
}

abstract class ContentGenerationProvider {
  String get name;
  Future<bool> isAvailable();
  Future<GeneratedContentResult> generateContent(ContentGenerationRequest request);
}
