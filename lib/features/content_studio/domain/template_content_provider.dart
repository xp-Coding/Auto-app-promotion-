import '../../../core/utils/utm_builder.dart';
import 'content_generation_provider.dart';

/// Algorithmic, zero-cost template provider that adapts copy specifically
/// to YouTube, Facebook, Instagram, and TikTok using registered app features.
class TemplateContentProvider implements ContentGenerationProvider {
  @override
  String get name => 'Algorithmic Template Engine (Offline & Free)';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<GeneratedContentResult> generateContent(ContentGenerationRequest request) async {
    final app = request.app;
    final platform = request.targetPlatform.toLowerCase();
    final cta = app.preferredCta ?? 'Download free on Google Play';
    final primaryFeature = app.mainFeatures.isNotEmpty ? app.mainFeatures.first : 'essential tools';
    final secondaryFeature = app.mainFeatures.length > 1 ? app.mainFeatures[1] : null;
    final usp = app.uniqueSellingPoints.isNotEmpty ? app.uniqueSellingPoints.first : 'built for speed and simplicity';
    final audience = app.targetAudience ?? 'users';
    final tone = app.brandTone ?? 'Informative & Helpful';
    final theme = request.topicOrTheme ?? 'daily workflow boost';

    // Generate campaign-specific UTM tracking link
    final trackingLink = UtmBuilder.buildPlayStoreUtmUrl(
      basePlayStoreUrl: app.playStoreUrl,
      utmSource: platform,
      utmMedium: UtmBuilder.getSuggestedMediumForPlatform(platform),
      utmCampaign: request.campaign?.name.replaceAll(' ', '_') ?? 'organic_promo',
      utmContent: request.contentFormat,
    );

    switch (platform) {
      case 'youtube':
        return _generateYouTubeContent(
          app: app,
          primaryFeature: primaryFeature,
          secondaryFeature: secondaryFeature,
          usp: usp,
          audience: audience,
          tone: tone,
          theme: theme,
          cta: cta,
          trackingLink: trackingLink,
        );

      case 'tiktok':
        return _generateTikTokContent(
          app: app,
          primaryFeature: primaryFeature,
          secondaryFeature: secondaryFeature,
          usp: usp,
          audience: audience,
          tone: tone,
          theme: theme,
          cta: cta,
          trackingLink: trackingLink,
        );

      case 'instagram':
        return _generateInstagramContent(
          app: app,
          format: request.contentFormat,
          primaryFeature: primaryFeature,
          secondaryFeature: secondaryFeature,
          usp: usp,
          audience: audience,
          tone: tone,
          theme: theme,
          cta: cta,
          trackingLink: trackingLink,
        );

      case 'facebook':
      default:
        return _generateFacebookContent(
          app: app,
          primaryFeature: primaryFeature,
          secondaryFeature: secondaryFeature,
          usp: usp,
          audience: audience,
          tone: tone,
          theme: theme,
          cta: cta,
          trackingLink: trackingLink,
        );
    }
  }

  GeneratedContentResult _generateYouTubeContent({
    required dynamic app,
    required String primaryFeature,
    required String? secondaryFeature,
    required String usp,
    required String audience,
    required String tone,
    required String theme,
    required String cta,
    required String trackingLink,
  }) {
    final title = 'How to Simplify $theme With ${app.name} (Android Demo)';
    final altTitles = [
      'Stop Wasting Time on $theme: Try ${app.name} on Google Play',
      'The Best Free Android App for $audience in 2026: ${app.name}',
      'Why Everyone is Switching to ${app.name} ($primaryFeature Spotlight)',
    ];

    final hook = 'If you are tired of complicated solutions for $theme, wait until you see how ${app.name} handles $primaryFeature.';

    final body = '''
🎬 FULL VIDEO SCRIPT & TIMESTAMPS:

[0:00 - Hook]
$hook In this video, we're taking a deep dive into ${app.name}, designed specifically for $audience.

[0:30 - The Problem]
Most tools struggle with $theme. You get bogged down by clutter, ads, or clunky navigation.

[1:15 - Feature Showcase: $primaryFeature]
Here's how ${app.name} solves this: With $primaryFeature, you can get things done in just seconds. Notice how clean the interface is.
${secondaryFeature != null ? '[2:00 - Bonus: $secondaryFeature]\nPlus, you get $secondaryFeature out of the box.' : ''}

[2:45 - What Makes It Different ($usp)]
Unlike alternatives, ${app.name} gives you $usp.

[3:30 - Call to Action]
👉 Get ${app.name} directly from Google Play:
$trackingLink

--------------------------------------------------
📌 DESCRIPTION COPY:
Looking for an easier way to master $theme? Discover ${app.name} on the Google Play Store! 
Key Highlights:
• $primaryFeature
${secondaryFeature != null ? '• $secondaryFeature\n' : ''}• $usp
• 100% Verified Android Listing

Download now on Google Play:
$trackingLink
''';

    final hashtags = '#${app.name.replaceAll(' ', '')} #AndroidApps #GooglePlay #Productivity #AppTutorial';
    final visual = 'Thumbnail Idea: Bold high-contrast text "STOP DOING THIS!" with an arrow pointing to a split before/after app screenshot.';

    return GeneratedContentResult(
      title: title,
      bodyText: body.trim(),
      scriptHook: hook,
      hashtags: hashtags,
      ctaLink: trackingLink,
      visualDirectionOrThumbnail: visual,
      alternativeTitles: altTitles,
      providerName: name,
    );
  }

  GeneratedContentResult _generateTikTokContent({
    required dynamic app,
    required String primaryFeature,
    required String? secondaryFeature,
    required String usp,
    required String audience,
    required String tone,
    required String theme,
    required String cta,
    required String trackingLink,
  }) {
    final title = '${app.name}: The Android Lifehack You Did Not Know Existed';
    final hook = 'This tiny Android app just saved me 2 hours on $theme...';

    final body = '''
⏱️ SCENE-BY-SCENE SHORT VIDEO STORYBOARD (30-45 SECONDS):

[Scene 1: 0-3s | The Scroll Stopper]
Visual: Fast camera movement showing screen frustration, then tapping ${app.name} icon.
On-Screen Text: "If you have an Android phone, you need this app 📲"
Voiceover Hook: "$hook"

[Scene 2: 4-15s | The Demonstration]
Visual: Screen recording demonstrating "$primaryFeature". Smooth taps, instant response.
On-Screen Text: "$primaryFeature in 3 taps ⚡"
Voiceover: "Instead of dealing with complicated setups, ${app.name} lets you activate $primaryFeature instantly."

[Scene 3: 16-25s | The Secret Sauce]
Visual: Zoom in on key benefit.
On-Screen Text: "Secret Benefit: $usp ✨"
Voiceover: "And the best part? It's $usp, built specifically for $audience."

[Scene 4: 26-30s | Call To Action]
Visual: Play Store listing screen showing Install button.
On-Screen Text: "Free on Google Play Store 🟢"
Voiceover: "$cta. Link is right on Google Play or in bio!"

--------------------------------------------------
📝 CAPTION SUGGESTION:
Honestly obsessed with this Android find 🤯 Anyone else struggle with $theme? Try ${app.name} on Google Play!
''';

    final hashtags = '#AndroidHacks #AppOfTheDay #AndroidTips #LifeHacks #FreeApp #PlayStore';
    final visual = 'Dynamic 9:16 vertical video with bright yellow on-screen captions and subtle background audio.';

    return GeneratedContentResult(
      title: title,
      bodyText: body.trim(),
      scriptHook: hook,
      hashtags: hashtags,
      ctaLink: trackingLink,
      visualDirectionOrThumbnail: visual,
      alternativeTitles: [
        'Android users, stop scrolling right now 📱',
        '3 reasons ${app.name} is permanently on my home screen',
      ],
      providerName: name,
    );
  }

  GeneratedContentResult _generateInstagramContent({
    required dynamic app,
    required String format,
    required String primaryFeature,
    required String? secondaryFeature,
    required String usp,
    required String audience,
    required String tone,
    required String theme,
    required String cta,
    required String trackingLink,
  }) {
    final isReel = format.toLowerCase().contains('reel') || format.toLowerCase().contains('video');
    final title = '${app.name} • Master $theme On Android';
    final hook = 'Ready to upgrade your Android experience? Check out this secret weapon.';

    final body = isReel
        ? '''
🎥 INSTAGRAM REEL SCRIPT & CAPTION:

[Hook - 0-4s]: "$hook"
[Visual]: Aesthetic desk shot, Android device waking up with ${app.name} open.
[Core - 5-20s]: "If you are a $audience, managing $theme used to be annoying. But with $primaryFeature, everything stays streamlined."
[USP - 21-28s]: "Plus, unlike others, it is $usp."
[Outro]: "Tap the link in bio to get ${app.name} free on Google Play!"

--------------------------------------------------
📸 POST CAPTION:
Elevate your routine with ${app.name} ✨
Designed for $audience who want seamless performance without the bloatware.

Key features you will love:
✓ $primaryFeature
${secondaryFeature != null ? '✓ $secondaryFeature\n' : ''}✓ $usp

📲 Available now on Google Play Store!
Get it here: $trackingLink
'''
        : '''
🎨 CAROUSEL POST COPY (5 SLIDES):

Slide 1 (Cover): "How To Solve $theme In 3 Simple Steps 📱"
Slide 2: "Step 1: Eliminate the clutter. Why traditional tools slow you down."
Slide 3: "Step 2: Enter ${app.name}. Built with $primaryFeature to speed up your routine."
Slide 4: "Step 3: Why users love it. Because it is $usp."
Slide 5 (CTA): "$cta! Search '${app.name}' on Google Play Store or tap the link in bio."

--------------------------------------------------
📸 POST CAPTION:
Swipe through to discover how ${app.name} changes the game for $audience 👆
Save this post for later! 💾
''';

    final hashtags = '#AndroidApp #AppDesign #TechTips #ProductivityLife #AndroidCommunity #GooglePlayStore';
    final visual = 'Clean minimalist aesthetic using the brand colors, rounded mockup frames, and clear typography.';

    return GeneratedContentResult(
      title: title,
      bodyText: body.trim(),
      scriptHook: hook,
      hashtags: hashtags,
      ctaLink: trackingLink,
      visualDirectionOrThumbnail: visual,
      alternativeTitles: [
        '5 things you did not know your Android phone could do',
        'The aesthetic app every $audience needs in 2026',
      ],
      providerName: name,
    );
  }

  GeneratedContentResult _generateFacebookContent({
    required dynamic app,
    required String primaryFeature,
    required String? secondaryFeature,
    required String usp,
    required String audience,
    required String tone,
    required String theme,
    required String cta,
    required String trackingLink,
  }) {
    final title = '${app.name} Launch & Feature Spotlight';
    final hook = 'Struggling with $theme? Here is a dedicated Android solution.';

    final body = '''
📢 FACEBOOK PAGE POST:

$hook

If you belong to our $audience community, you know how hard it can be to find reliable, straightforward tools. 

We built ${app.name} to change that:
🔹 $primaryFeature — Get things done faster and with zero hassle.
${secondaryFeature != null ? '🔹 $secondaryFeature — Enhanced capability directly on your phone.\n' : ''}🔹 $usp — Clean, secure, and respectful of your device.

See what real users are saying and check out the full listing on Google Play Store:
👉 $trackingLink

💬 Have questions or feature requests? Drop them in the comments below! We read and respond to every note from our community.
''';

    final hashtags = '#Android #MobileApp #GooglePlay #${app.name.replaceAll(' ', '')} #TechCommunity';
    final visual = 'Clear Facebook link preview image (1200x630px) featuring app logo, primary benefit headline, and 5-star review graphic.';

    return GeneratedContentResult(
      title: title,
      bodyText: body.trim(),
      scriptHook: hook,
      hashtags: hashtags,
      ctaLink: trackingLink,
      visualDirectionOrThumbnail: visual,
      alternativeTitles: [
        'Announcing ${app.name}: The new way to handle $theme on Android',
        'Why $audience are downloading ${app.name} this month',
      ],
      providerName: name,
    );
  }
}
