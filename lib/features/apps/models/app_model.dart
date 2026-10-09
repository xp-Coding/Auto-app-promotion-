import 'dart:convert';
import 'package:appgrowth_studio/core/utils/validators.dart';

/// Represents a registered Google Play Android application.
class AppModel {
  final String id;
  final String name;
  final String packageName;
  final String playStoreUrl;
  final String? iconPath;
  final String category;
  final String? shortDescription;
  final String? fullDescription;
  final List<String> mainFeatures;
  final List<String> uniqueSellingPoints;
  final String? targetAudience;
  final List<String> targetCountries;
  final List<String> supportedLanguages;
  final String? brandTone;
  final String? preferredCta;
  final String? websiteUrl;
  final String? privacyPolicyUrl;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppModel({
    required this.id,
    required this.name,
    required this.packageName,
    required this.playStoreUrl,
    this.iconPath,
    required this.category,
    this.shortDescription,
    this.fullDescription,
    this.mainFeatures = const [],
    this.uniqueSellingPoints = const [],
    this.targetAudience,
    this.targetCountries = const [],
    this.supportedLanguages = const [],
    this.brandTone,
    this.preferredCta,
    this.websiteUrl,
    this.privacyPolicyUrl,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculates the real-time Listing Quality Score.
  ListingQualityResult get listingQuality {
    return Validators.evaluateListingQuality(
      name: name,
      packageName: packageName,
      shortDescription: shortDescription,
      fullDescription: fullDescription,
      mainFeatures: mainFeatures,
      uniqueSellingPoints: uniqueSellingPoints,
      targetAudience: targetAudience,
      iconPath: iconPath,
      privacyPolicyUrl: privacyPolicyUrl,
    );
  }

  AppModel copyWith({
    String? id,
    String? name,
    String? packageName,
    String? playStoreUrl,
    String? iconPath,
    String? category,
    String? shortDescription,
    String? fullDescription,
    List<String>? mainFeatures,
    List<String>? uniqueSellingPoints,
    String? targetAudience,
    List<String>? targetCountries,
    List<String>? supportedLanguages,
    String? brandTone,
    String? preferredCta,
    String? websiteUrl,
    String? privacyPolicyUrl,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppModel(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      playStoreUrl: playStoreUrl ?? this.playStoreUrl,
      iconPath: iconPath ?? this.iconPath,
      category: category ?? this.category,
      shortDescription: shortDescription ?? this.shortDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      mainFeatures: mainFeatures ?? this.mainFeatures,
      uniqueSellingPoints: uniqueSellingPoints ?? this.uniqueSellingPoints,
      targetAudience: targetAudience ?? this.targetAudience,
      targetCountries: targetCountries ?? this.targetCountries,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      brandTone: brandTone ?? this.brandTone,
      preferredCta: preferredCta ?? this.preferredCta,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      privacyPolicyUrl: privacyPolicyUrl ?? this.privacyPolicyUrl,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'package_name': packageName,
      'play_store_url': playStoreUrl,
      'icon_path': iconPath,
      'category': category,
      'short_description': shortDescription,
      'full_description': fullDescription,
      'main_features': jsonEncode(mainFeatures),
      'unique_selling_points': jsonEncode(uniqueSellingPoints),
      'target_audience': targetAudience,
      'target_countries': jsonEncode(targetCountries),
      'supported_languages': jsonEncode(supportedLanguages),
      'brand_tone': brandTone,
      'preferred_cta': preferredCta,
      'website_url': websiteUrl,
      'privacy_policy_url': privacyPolicyUrl,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppModel.fromMap(Map<String, dynamic> map) {
    List<String> parseJsonList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(val.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      return [];
    }

    return AppModel(
      id: map['id'] as String,
      name: map['name'] as String,
      packageName: map['package_name'] as String,
      playStoreUrl: map['play_store_url'] as String,
      iconPath: map['icon_path'] as String?,
      category: map['category'] as String,
      shortDescription: map['short_description'] as String?,
      fullDescription: map['full_description'] as String?,
      mainFeatures: parseJsonList(map['main_features']),
      uniqueSellingPoints: parseJsonList(map['unique_selling_points']),
      targetAudience: map['target_audience'] as String?,
      targetCountries: parseJsonList(map['target_countries']),
      supportedLanguages: parseJsonList(map['supported_languages']),
      brandTone: map['brand_tone'] as String?,
      preferredCta: map['preferred_cta'] as String?,
      websiteUrl: map['website_url'] as String?,
      privacyPolicyUrl: map['privacy_policy_url'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
