import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/validators.dart';
import '../../apps/models/app_model.dart';
import '../../media_library/models/media_item_model.dart';
import '../../media_library/repositories/media_repository.dart';

class ScrapedAppResult {
  final AppModel app;
  final String? localIconPath;
  final List<String> localScreenshotPaths;
  final List<String> extractedFeatures;
  final List<String> extractedUsps;
  final String targetAudience;
  final String? developerName;
  final List<String> extractedUseCases;
  final String valueProposition;
  final Map<String, bool> validationChecklist;
  final Map<String, String> fieldSources;
  final List<String> warnings;
  final bool isLiveListingFound;

  const ScrapedAppResult({
    required this.app,
    this.localIconPath,
    this.localScreenshotPaths = const [],
    this.extractedFeatures = const [],
    this.extractedUsps = const [],
    required this.targetAudience,
    this.developerName,
    this.extractedUseCases = const [],
    this.valueProposition = '',
    this.validationChecklist = const {},
    this.fieldSources = const {},
    this.warnings = const [],
    this.isLiveListingFound = true,
  });
}

class PlayStoreScraperService {
  final http.Client _client;
  final MediaRepository _mediaRepo;
  final Uuid _uuid = const Uuid();

  PlayStoreScraperService({http.Client? client, MediaRepository? mediaRepo})
      : _client = client ?? http.Client(),
        _mediaRepo = mediaRepo ?? MediaRepository();

  /// Parse user input (URL or package name) into a normalized package ID
  String normalizePackageName(String input) {
    final trimmed = input.trim();
    final fromUrl = Validators.extractPackageName(trimmed);
    if (fromUrl != null) return fromUrl;
    if (Validators.isValidPackageName(trimmed)) return trimmed;

    // Fallback: extract id= query parameter if present in any format
    final match = RegExp(r'id=([a-zA-Z0-9_\.]+)').firstMatch(trimmed);
    if (match != null) {
      final id = match.group(1)!;
      if (Validators.isValidPackageName(id)) return id;
    }

    return trimmed;
  }

  /// Scrapes public listing and registers local assets
  Future<ScrapedAppResult> scrapeAndExtractApp({
    required String urlOrPackage,
    String? preferredAudience,
    String? customNotes,
  }) async {
    final packageName = normalizePackageName(urlOrPackage);
    final warnings = <String>[];

    if (!Validators.isValidPackageName(packageName)) {
      throw ArgumentError(
        'Invalid Google Play package name or URL: "$urlOrPackage". '
        'Must follow standard reverse-DNS format like com.example.app.',
      );
    }

    final playStoreUrl = 'https://play.google.com/store/apps/details?id=$packageName&hl=en&gl=US';
    String htmlBody = '';
    bool liveFound = false;

    try {
      final response = await _client.get(
        Uri.parse(playStoreUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        htmlBody = response.body;
        liveFound = true;
      } else {
        warnings.add(
          'Google Play Store listing query returned HTTP ${response.statusCode}. '
          'Initialized app profile from package name with template fallback.',
        );
      }
    } catch (e) {
      warnings.add(
        'Could not connect to Google Play ($e). Created offline app profile from package name.',
      );
    }

    // Extract metadata from HTML (or offline fallback)
    final extracted = liveFound
        ? _parseHtmlListing(htmlBody, packageName, playStoreUrl)
        : _generateOfflineFallback(packageName, playStoreUrl);

    final appId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // Prepare media storage directory
    final mediaStorageDir = Directory(
      p.join(AppDatabase.getDatabaseDirectoryPath(), 'media', appId),
    );
    if (!mediaStorageDir.existsSync()) {
      mediaStorageDir.createSync(recursive: true);
    }

    // Download icon locally if available
    String? localIconPath;
    if (extracted.remoteIconUrl != null && extracted.remoteIconUrl!.startsWith('http')) {
      try {
        final iconFile = File(p.join(mediaStorageDir.path, 'icon.png'));
        final iconResp = await _client.get(Uri.parse(extracted.remoteIconUrl!)).timeout(const Duration(seconds: 10));
        if (iconResp.statusCode == 200) {
          await iconFile.writeAsBytes(iconResp.bodyBytes);
          localIconPath = iconFile.path;

          await _mediaRepo.addMedia(MediaItemModel(
            id: _uuid.v4(),
            appId: appId,
            filePath: localIconPath,
            mediaType: 'icon',
            title: '${extracted.title} App Icon',
            tags: 'official,icon,playstore',
            createdAt: now,
          ));
        }
      } catch (e) {
        warnings.add('Failed to download app icon ($e).');
      }
    }

    // Download high-resolution screenshots locally
    final localScreenshotPaths = <String>[];
    for (int i = 0; i < extracted.remoteScreenshotUrls.length && i < 8; i++) {
      final remoteUrl = extracted.remoteScreenshotUrls[i];
      try {
        final shotFile = File(p.join(mediaStorageDir.path, 'screenshot_${i + 1}.jpg'));
        final shotResp = await _client.get(Uri.parse(remoteUrl)).timeout(const Duration(seconds: 10));
        if (shotResp.statusCode == 200) {
          await shotFile.writeAsBytes(shotResp.bodyBytes);
          localScreenshotPaths.add(shotFile.path);

          await _mediaRepo.addMedia(MediaItemModel(
            id: _uuid.v4(),
            appId: appId,
            filePath: shotFile.path,
            mediaType: 'screenshot',
            title: '${extracted.title} Screenshot #${i + 1}',
            tags: 'official,screenshot,playstore',
            createdAt: now,
          ));
        }
      } catch (_) {}
    }

    // Semantic feature extraction & positioning
    final features = extracted.features.isNotEmpty
        ? extracted.features
        : _extractFeaturesFromText(extracted.fullDescription);

    final usps = extracted.usps.isNotEmpty
        ? extracted.usps
        : [
            'Engineered for speed, focus, and intuitive daily use',
            'No unnecessary bloat or complex learning curve',
          ];

    final audience = preferredAudience?.trim().isNotEmpty == true
        ? preferredAudience!
        : extracted.suggestedAudience;

    // Extract practical use cases based on category and features
    final useCases = <String>[];
    if (extracted.category == 'Productivity') {
      useCases.addAll(['Daily task prioritization', 'Habit and routine tracking', 'Focus optimization']);
    } else if (extracted.category == 'Health & Fitness') {
      useCases.addAll(['Daily workout logging', 'Calorie and meal tracking', 'Weekly habit milestones']);
    } else if (extracted.category == 'Finance') {
      useCases.addAll(['Expense and budget auditing', 'Monthly bill management', 'Personal savings goal tracking']);
    } else if (extracted.category == 'Games') {
      useCases.addAll(['Casual on-the-go entertainment', 'Skill progression', 'Offline leisure play']);
    } else {
      useCases.addAll(['Streamlining routine mobile tasks', 'Quick offline access', 'Productive daily workflow']);
    }

    final valueProp = usps.isNotEmpty
        ? '${extracted.title} delivers ${usps.first.toLowerCase()} with a clean Android user experience.'
        : '${extracted.title} provides reliable ${extracted.category} capabilities directly on your Android device.';

    // Construct listing data integrity checklist
    final checklist = <String, bool>{
      'Title & Package Identified': extracted.title.isNotEmpty,
      'Category Classified': extracted.category.isNotEmpty,
      'App Icon Downloaded': localIconPath != null,
      'Store Screenshots Retrieved': localScreenshotPaths.isNotEmpty,
      'Core Features Extracted': features.isNotEmpty,
      'Target Audience Inferred': true,
      'Privacy Policy Accessible': extracted.privacyPolicyUrl != null && extracted.privacyPolicyUrl!.isNotEmpty,
    };

    // Construct clear source attribution (official listing vs estimated fallback)
    final sources = <String, String>{
      'Title': liveFound ? 'Google Play Store Public Listing' : 'Derived from Package Name (Estimate)',
      'Category': liveFound ? 'Google Play Store Category' : 'Inferred from Package Pattern (Estimate)',
      'Icon': localIconPath != null ? 'Official High-Res Store Icon' : 'None (Template Icon Applied)',
      'Screenshots': localScreenshotPaths.isNotEmpty
          ? '${localScreenshotPaths.length} Authentic Listing Screenshots'
          : 'None Found (Template Graphic Cards Will Be Synthesized)',
      'Target Audience': 'Category Demographic Modeling (Statistical Estimate)',
      'Value Proposition': 'Synthesized from Store Features & USPs',
    };

    if (localScreenshotPaths.isEmpty) {
      warnings.add(
        'No public store screenshots were retrieved. Autopilot will synthesize clean 1080x1920 graphic cards using your official app icon and typography.',
      );
    }
    if (extracted.privacyPolicyUrl == null || extracted.privacyPolicyUrl!.isEmpty) {
      warnings.add(
        'Privacy policy URL was not detected on listing. Required for certain promotional campaigns; you can add it in the profile editor.',
      );
    }

    final appModel = AppModel(
      id: appId,
      name: extracted.title,
      packageName: packageName,
      playStoreUrl: playStoreUrl,
      iconPath: localIconPath,
      category: extracted.category,
      shortDescription: extracted.shortDescription,
      fullDescription: extracted.fullDescription,
      mainFeatures: features,
      uniqueSellingPoints: usps,
      targetAudience: audience,
      targetCountries: const ['US', 'GB', 'CA', 'AU', 'IN', 'DE'],
      supportedLanguages: const ['en'],
      brandTone: extracted.brandTone,
      preferredCta: 'Download free on Google Play',
      websiteUrl: extracted.websiteUrl,
      privacyPolicyUrl: extracted.privacyPolicyUrl,
      createdAt: now,
      updatedAt: now,
    );

    return ScrapedAppResult(
      app: appModel,
      localIconPath: localIconPath,
      localScreenshotPaths: localScreenshotPaths,
      extractedFeatures: features,
      extractedUsps: usps,
      targetAudience: audience,
      developerName: extracted.developerName,
      extractedUseCases: useCases,
      valueProposition: valueProp,
      validationChecklist: checklist,
      fieldSources: sources,
      warnings: warnings,
      isLiveListingFound: liveFound,
    );
  }

  /// Parses Play Store HTML extracting JSON-LD, OpenGraph, and semantic DOM elements
  _ExtractedListingData _parseHtmlListing(String html, String packageName, String playStoreUrl) {
    String title = '';
    String shortDesc = '';
    String fullDesc = '';
    String category = 'Tools & Utilities';
    String? iconUrl;
    final screenshotUrls = <String>[];
    String? developerName;
    String? websiteUrl;
    String? privacyPolicyUrl;

    // 1. Try JSON-LD SoftwareApplication schema
    final jsonLdMatch = RegExp(r'<script type="application/ld\+json">([\s\S]*?)<\/script>').firstMatch(html);
    if (jsonLdMatch != null) {
      try {
        final jsonStr = jsonLdMatch.group(1)?.trim() ?? '';
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        if (data['name'] != null) title = data['name'].toString().trim();
        if (data['description'] != null) fullDesc = data['description'].toString().trim();
        if (data['applicationCategory'] != null) category = _normalizeCategory(data['applicationCategory'].toString());
        if (data['image'] != null) iconUrl = data['image'].toString();
        if (data['author'] is Map && data['author']['name'] != null) {
          developerName = data['author']['name'].toString();
        }
      } catch (_) {}
    }

    // 2. OpenGraph Meta Tags Fallback
    if (title.isEmpty) {
      final ogTitle = RegExp(r'<meta property="og:title" content="(.*?)"').firstMatch(html);
      if (ogTitle != null) {
        title = _cleanHtmlEntities(ogTitle.group(1) ?? '');
        title = title.replaceAll(' - Apps on Google Play', '').trim();
      }
    }

    if (fullDesc.isEmpty) {
      final ogDesc = RegExp(r'<meta property="og:description" content="(.*?)"').firstMatch(html);
      if (ogDesc != null) {
        fullDesc = _cleanHtmlEntities(ogDesc.group(1) ?? '');
      }
    }

    if (iconUrl == null) {
      final ogImg = RegExp(r'<meta property="og:image" content="(.*?)"').firstMatch(html);
      if (ogImg != null) {
        iconUrl = ogImg.group(1);
      }
    }

    // 3. Fallback title from <title> tag
    if (title.isEmpty) {
      final titleTag = RegExp(r'<title>(.*?)<\/title>').firstMatch(html);
      if (titleTag != null) {
        title = _cleanHtmlEntities(titleTag.group(1) ?? '')
            .replaceAll(' - Apps on Google Play', '')
            .replaceAll(' - Android Apps on Google Play', '')
            .trim();
      }
    }

    if (title.isEmpty) {
      title = _prettifyPackageName(packageName);
    }

    // 4. Extract screenshots
    final imgMatches = RegExp(r'https:\/\/play-lh\.googleusercontent\.com\/[a-zA-Z0-9_\-=]+').allMatches(html);
    final seenUrls = <String>{};
    for (final match in imgMatches) {
      final url = match.group(0)!;
      // Filter out small badges/avatars
      if (!url.contains('=s') && !seenUrls.contains(url)) {
        seenUrls.add(url);
        // Request high-res image
        screenshotUrls.add('$url=w1920-h1080');
      }
    }

    // Short description from full description first 80 chars
    if (fullDesc.isNotEmpty) {
      final firstPeriod = fullDesc.indexOf('.');
      if (firstPeriod > 10 && firstPeriod <= 80) {
        shortDesc = fullDesc.substring(0, firstPeriod + 1).trim();
      } else {
        shortDesc = fullDesc.length > 80 ? '${fullDesc.substring(0, 77)}...' : fullDesc;
      }
    } else {
      shortDesc = 'Boost your daily productivity and workflow with $title.';
      fullDesc = 'Discover $title: the smart, modern solution designed for effortless daily tasks.';
    }

    // Features extraction
    final features = _extractFeaturesFromText(fullDesc);

    // Suggested audience based on category
    final audience = _inferAudience(category, title);
    final tone = _inferTone(category);

    return _ExtractedListingData(
      title: title,
      shortDescription: shortDesc,
      fullDescription: fullDesc,
      category: category,
      remoteIconUrl: iconUrl,
      remoteScreenshotUrls: screenshotUrls,
      features: features,
      usps: [
        'Streamlined interface built for zero distraction',
        'Optimized for fast performance and low battery usage',
      ],
      suggestedAudience: audience,
      brandTone: tone,
      developerName: developerName,
      websiteUrl: websiteUrl,
      privacyPolicyUrl: privacyPolicyUrl,
    );
  }

  _ExtractedListingData _generateOfflineFallback(String packageName, String playStoreUrl) {
    final title = _prettifyPackageName(packageName);
    String category = 'Productivity';
    final pkgLower = packageName.toLowerCase();
    if (pkgLower.contains('fitness') || pkgLower.contains('workout') || pkgLower.contains('gym') || pkgLower.contains('meditation') || pkgLower.contains('mind')) {
      category = 'Health & Fitness';
    } else if (pkgLower.contains('finance') || pkgLower.contains('wallet') || pkgLower.contains('budget') || pkgLower.contains('bank')) {
      category = 'Finance';
    } else if (pkgLower.contains('music') || pkgLower.contains('audio') || pkgLower.contains('podcast')) {
      category = 'Music & Audio';
    } else if (pkgLower.contains('game') || pkgLower.contains('play')) {
      category = 'Games';
    } else if (pkgLower.contains('social') || pkgLower.contains('chat') || pkgLower.contains('message')) {
      category = 'Social';
    } else if (pkgLower.contains('photo') || pkgLower.contains('video') || pkgLower.contains('camera')) {
      category = 'Photography';
    }

    // Extract developer from package segments if possible (e.g., com.habitmaster.productivity -> Habitmaster Inc)
    String? devName;
    final parts = packageName.split('.');
    if (parts.length >= 2 && parts[1] != 'example' && parts[1] != 'android') {
      final seg = parts[1];
      devName = '${seg[0].toUpperCase()}${seg.substring(1)} Inc';
    }

    return _ExtractedListingData(
      title: title,
      shortDescription: 'The smart, modern mobile solution for $title.',
      fullDescription:
          '$title provides a fast, reliable, and user-friendly experience on Android. '
          'Packed with essential daily tools, clean navigation, and smooth performance.',
      category: category,
      remoteIconUrl: null,
      remoteScreenshotUrls: const [],
      features: [
        'Intuitive interface and fluid controls',
        'Fast response with offline capabilities',
        'Customizable user preferences',
      ],
      usps: [
        'Built for speed and clean design',
        'No complicated setup required',
      ],
      suggestedAudience: _inferAudience(category, title),
      brandTone: 'Informative & Helpful',
      developerName: devName,
    );
  }

  List<String> _extractFeaturesFromText(String text) {
    final features = <String>[];
    final lines = text.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('•') ||
          trimmed.startsWith('-') ||
          trimmed.startsWith('*') ||
          trimmed.startsWith('✔') ||
          trimmed.startsWith('★')) {
        final clean = trimmed.replaceFirst(RegExp(r'^[•\-\*✔★\d\.]+\s*'), '').trim();
        if (clean.length >= 8 && clean.length <= 90 && !features.contains(clean)) {
          features.add(clean);
        }
      }
    }

    if (features.isEmpty) {
      // Split by sentences if no bullet points
      final sentences = text.split(RegExp(r'[\.\!\?]\s+'));
      for (final s in sentences) {
        final clean = s.trim();
        if (clean.length >= 15 && clean.length <= 80 && !features.contains(clean)) {
          features.add(clean);
        }
        if (features.length >= 4) break;
      }
    }

    return features.take(5).toList();
  }

  String _prettifyPackageName(String pkg) {
    final segments = pkg.split('.');
    final candidate = segments.length > 1 ? segments.last : pkg;
    return candidate
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ')
        .trim();
  }

  String _cleanHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String _normalizeCategory(String raw) {
    final c = raw.toUpperCase();
    if (c.contains('GAME')) return 'Games';
    if (c.contains('PROD')) return 'Productivity';
    if (c.contains('TOOL')) return 'Tools & Utilities';
    if (c.contains('FIN')) return 'Finance';
    if (c.contains('EDU')) return 'Education';
    if (c.contains('HEALTH') || c.contains('FIT')) return 'Health & Fitness';
    if (c.contains('COMM')) return 'Communication';
    if (c.contains('ENT')) return 'Entertainment';
    if (c.contains('PHOTO')) return 'Photography';
    if (c.contains('SOC')) return 'Social';
    if (c.contains('BUS')) return 'Business';
    return 'Tools & Utilities';
  }

  String _inferAudience(String category, String title) {
    switch (category) {
      case 'Games':
        return 'Gamers looking for high-energy strategy and addictive challenges';
      case 'Productivity':
        return 'Professionals, students, and multitaskers optimizing daily efficiency';
      case 'Finance':
        return 'Budget-conscious individuals and investors tracking daily finances';
      case 'Health & Fitness':
        return 'Fitness enthusiasts aiming for daily wellness and milestone tracking';
      case 'Education':
        return 'Lifelong learners and students seeking interactive knowledge';
      default:
        return 'Mobile users looking for clean, reliable utility apps';
    }
  }

  String _inferTone(String category) {
    if (category == 'Games') return 'Excited & Energetic';
    if (category == 'Finance' || category == 'Business') return 'Professional & Trustworthy';
    if (category == 'Education') return 'Inspirational & Bold';
    return 'Informative & Helpful';
  }
}

class _ExtractedListingData {
  final String title;
  final String shortDescription;
  final String fullDescription;
  final String category;
  final String? remoteIconUrl;
  final List<String> remoteScreenshotUrls;
  final List<String> features;
  final List<String> usps;
  final String suggestedAudience;
  final String brandTone;
  final String? developerName;
  final String? websiteUrl;
  final String? privacyPolicyUrl;

  const _ExtractedListingData({
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.category,
    this.remoteIconUrl,
    required this.remoteScreenshotUrls,
    required this.features,
    required this.usps,
    required this.suggestedAudience,
    required this.brandTone,
    this.developerName,
    this.websiteUrl,
    this.privacyPolicyUrl,
  });
}
