/// Builder for generating compliant Google Play Store campaign and attribution URLs.
class UtmBuilder {
  /// Builds a Google Play Store URL with standard UTM campaign parameters.
  static String buildPlayStoreUtmUrl({
    required String basePlayStoreUrl,
    required String utmSource,
    String? utmMedium,
    String? utmCampaign,
    String? utmContent,
    String? utmTerm,
  }) {
    final trimmedBase = basePlayStoreUrl.trim();
    final uri = Uri.tryParse(trimmedBase);
    if (uri == null) return trimmedBase;

    // Collect campaign parameters for Google Play referrer parameter
    final referrerParams = <String>[];

    if (utmSource.trim().isNotEmpty) {
      referrerParams.add('utm_source=${Uri.encodeComponent(utmSource.trim().toLowerCase())}');
    }
    if (utmMedium != null && utmMedium.trim().isNotEmpty) {
      referrerParams.add('utm_medium=${Uri.encodeComponent(utmMedium.trim().toLowerCase())}');
    }
    if (utmCampaign != null && utmCampaign.trim().isNotEmpty) {
      referrerParams.add('utm_campaign=${Uri.encodeComponent(utmCampaign.trim().toLowerCase())}');
    }
    if (utmContent != null && utmContent.trim().isNotEmpty) {
      referrerParams.add('utm_content=${Uri.encodeComponent(utmContent.trim().toLowerCase())}');
    }
    if (utmTerm != null && utmTerm.trim().isNotEmpty) {
      referrerParams.add('utm_term=${Uri.encodeComponent(utmTerm.trim().toLowerCase())}');
    }

    if (referrerParams.isEmpty) return trimmedBase;

    final referrerValue = referrerParams.join('&');
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['referrer'] = referrerValue;

    return uri.replace(queryParameters: queryParams).toString();
  }

  /// Suggests medium parameter based on target social platform.
  static String getSuggestedMediumForPlatform(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return 'video';
      case 'instagram':
        return 'reel';
      case 'tiktok':
        return 'short_video';
      case 'facebook':
        return 'post';
      default:
        return 'social';
    }
  }
}
