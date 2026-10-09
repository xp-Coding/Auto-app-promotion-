import 'package:flutter_test/flutter_test.dart';
import 'package:appgrowth_studio/core/utils/utm_builder.dart';

void main() {
  group('UtmBuilder Play Store Link Attribution Tests', () {
    const basePlayUrl = 'https://play.google.com/store/apps/details?id=com.studio.habitflow';

    test('Builds valid Play Store link with referrer parameter', () {
      final url = UtmBuilder.buildPlayStoreUtmUrl(
        basePlayStoreUrl: basePlayUrl,
        utmSource: 'youtube',
        utmMedium: 'video',
        utmCampaign: 'launch_q4',
        utmContent: 'tutorial_demo',
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters['id'], 'com.studio.habitflow');
      expect(uri.queryParameters.containsKey('referrer'), isTrue);

      final referrer = uri.queryParameters['referrer']!;
      expect(referrer.contains('utm_source=youtube'), isTrue);
      expect(referrer.contains('utm_medium=video'), isTrue);
      expect(referrer.contains('utm_campaign=launch_q4'), isTrue);
      expect(referrer.contains('utm_content=tutorial_demo'), isTrue);
    });

    test('Suggests platform-specific mediums correctly', () {
      expect(UtmBuilder.getSuggestedMediumForPlatform('youtube'), 'video');
      expect(UtmBuilder.getSuggestedMediumForPlatform('tiktok'), 'short_video');
      expect(UtmBuilder.getSuggestedMediumForPlatform('instagram'), 'reel');
      expect(UtmBuilder.getSuggestedMediumForPlatform('facebook'), 'post');
      expect(UtmBuilder.getSuggestedMediumForPlatform('other'), 'social');
    });
  });
}
