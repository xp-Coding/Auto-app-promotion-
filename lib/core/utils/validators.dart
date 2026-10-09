/// Validation utilities and Play Store metadata checks.
class Validators {
  /// Regular expression for Android package name: e.g. com.example.app
  static final RegExp packageNameRegex = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
  );

  /// Validates Google Play Store URL.
  static bool isValidPlayStoreUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) return false;
    return uri.host.contains('play.google.com') &&
        uri.path.contains('/store/apps/details') &&
        uri.queryParameters.containsKey('id');
  }

  /// Extracts the Android package name from a Google Play Store URL if present.
  static String? extractPackageName(String url) {
    if (url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri != null && uri.queryParameters.containsKey('id')) {
      final id = uri.queryParameters['id']?.trim();
      if (id != null && isValidPackageName(id)) {
        return id;
      }
    }
    return null;
  }

  /// Validates standard Android application package identifier format.
  static bool isValidPackageName(String packageName) {
    final trimmed = packageName.trim();
    if (trimmed.isEmpty || trimmed.length > 255) return false;
    return packageNameRegex.hasMatch(trimmed);
  }

  /// Evaluates Listing Quality Score (0 to 100) and returns actionable checklist items.
  static ListingQualityResult evaluateListingQuality({
    required String name,
    required String packageName,
    required String? shortDescription,
    required String? fullDescription,
    required List<String> mainFeatures,
    required List<String> uniqueSellingPoints,
    required String? targetAudience,
    required String? iconPath,
    required String? privacyPolicyUrl,
  }) {
    final items = <ListingChecklistItem>[];
    int score = 0;

    // 1. App Name
    if (name.trim().isNotEmpty && name.trim().length <= 30) {
      score += 15;
      items.add(const ListingChecklistItem(
        title: 'App Name is optimal (under 30 characters)',
        isPassed: true,
        points: 15,
      ));
    } else if (name.trim().isNotEmpty) {
      score += 10;
      items.add(const ListingChecklistItem(
        title: 'App Name exceeds recommended 30 characters',
        isPassed: false,
        points: 10,
        recommendation: 'Shorten app title to under 30 characters to match Play Store guidelines.',
      ));
    } else {
      items.add(const ListingChecklistItem(
        title: 'App Name is required',
        isPassed: false,
        points: 0,
        recommendation: 'Enter a distinctive name for your application.',
      ));
    }

    // 2. Package Name
    if (isValidPackageName(packageName)) {
      score += 10;
      items.add(const ListingChecklistItem(
        title: 'Package Name is valid',
        isPassed: true,
        points: 10,
      ));
    } else {
      items.add(const ListingChecklistItem(
        title: 'Package Name format is invalid',
        isPassed: false,
        points: 0,
        recommendation: 'Format must follow reverse-DNS notation (e.g., com.studio.app).',
      ));
    }

    // 3. Short Description (up to 80 chars)
    final shortDesc = shortDescription?.trim() ?? '';
    if (shortDesc.isNotEmpty && shortDesc.length <= 80) {
      score += 15;
      items.add(const ListingChecklistItem(
        title: 'Short Description conforms to Play Store 80-char limit',
        isPassed: true,
        points: 15,
      ));
    } else if (shortDesc.length > 80) {
      items.add(ListingChecklistItem(
        title: 'Short Description exceeds 80 characters (${shortDesc.length}/80)',
        isPassed: false,
        points: 0,
        recommendation: 'Trim short description to maximum 80 characters.',
      ));
    } else {
      items.add(const ListingChecklistItem(
        title: 'Short Description is missing',
        isPassed: false,
        points: 0,
        recommendation: 'Add a punchy short description (up to 80 characters) highlighting primary benefit.',
      ));
    }

    // 4. Full Description
    final fullDesc = fullDescription?.trim() ?? '';
    if (fullDesc.length >= 500) {
      score += 15;
      items.add(const ListingChecklistItem(
        title: 'Full Description has sufficient depth (>= 500 characters)',
        isPassed: true,
        points: 15,
      ));
    } else if (fullDesc.isNotEmpty) {
      score += 5;
      items.add(ListingChecklistItem(
        title: 'Full Description is brief (${fullDesc.length} characters)',
        isPassed: false,
        points: 5,
        recommendation: 'Expand description to at least 500 characters detailing core use cases and value.',
      ));
    } else {
      items.add(const ListingChecklistItem(
        title: 'Full Description is missing',
        isPassed: false,
        points: 0,
        recommendation: 'Provide full description for better organic search keyword coverage.',
      ));
    }

    // 5. Main Features (at least 3)
    if (mainFeatures.length >= 3) {
      score += 15;
      items.add(ListingChecklistItem(
        title: 'Main Features listed (${mainFeatures.length} features)',
        isPassed: true,
        points: 15,
      ));
    } else if (mainFeatures.isNotEmpty) {
      score += 5;
      items.add(ListingChecklistItem(
        title: 'Only ${mainFeatures.length} features recorded',
        isPassed: false,
        points: 5,
        recommendation: 'List at least 3 distinct features to power automated campaign script generation.',
      ));
    } else {
      items.add(const ListingChecklistItem(
        title: 'No Main Features specified',
        isPassed: false,
        points: 0,
        recommendation: 'Add at least 3 core features.',
      ));
    }

    // 6. Unique Selling Points (USPs)
    if (uniqueSellingPoints.isNotEmpty) {
      score += 10;
      items.add(ListingChecklistItem(
        title: 'USPs defined (${uniqueSellingPoints.length} points)',
        isPassed: true,
        points: 10,
      ));
    } else {
      items.add(const ListingChecklistItem(
        title: 'Unique Selling Points (USPs) missing',
        isPassed: false,
        points: 0,
        recommendation: 'Define what makes your app stand out versus competitors for marketing angles.',
      ));
    }

    // 7. Privacy Policy URL
    final privacy = privacyPolicyUrl?.trim() ?? '';
    if (privacy.startsWith('http://') || privacy.startsWith('https://')) {
      score += 10;
      items.add(const ListingChecklistItem(
        title: 'Privacy Policy URL provided',
        isPassed: true,
        points: 10,
      ));
    } else {
      items.add(const ListingChecklistItem(
        title: 'Privacy Policy URL missing',
        isPassed: false,
        points: 0,
        recommendation: 'Google Play strictly requires a public Privacy Policy URL for all listings.',
      ));
    }

    // 8. Icon Reference
    if (iconPath != null && iconPath.trim().isNotEmpty) {
      score += 10;
      items.add(const ListingChecklistItem(
        title: 'App Icon configured',
        isPassed: true,
        points: 10,
      ));
    } else {
      items.add(const ListingChecklistItem(
        title: 'App Icon not set',
        isPassed: false,
        points: 0,
        recommendation: 'Set an app icon file or image path for promotional media generation.',
      ));
    }

    return ListingQualityResult(
      score: score.clamp(0, 100),
      items: items,
    );
  }
}

class ListingQualityResult {
  final int score;
  final List<ListingChecklistItem> items;

  const ListingQualityResult({
    required this.score,
    required this.items,
  });

  String get grade {
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Needs Improvement';
  }
}

class ListingChecklistItem {
  final String title;
  final bool isPassed;
  final int points;
  final String? recommendation;

  const ListingChecklistItem({
    required this.title,
    required this.isPassed,
    required this.points,
    this.recommendation,
  });
}
