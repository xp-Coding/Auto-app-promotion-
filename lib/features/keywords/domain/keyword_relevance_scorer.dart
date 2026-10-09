import '../../apps/models/app_model.dart';

class ScoreExplanation {
  final double score;
  final String rationale;
  final List<String> contributingFactors;

  const ScoreExplanation({
    required this.score,
    required this.rationale,
    required this.contributingFactors,
  });
}

/// Evaluates qualitative keyword relevance against a registered application profile.
/// Complies with requirement: Never fabricate fake Google Play search volumes.
class KeywordRelevanceScorer {
  static ScoreExplanation calculateScore({
    required String keyword,
    required AppModel app,
    required String intent,
    required String source,
  }) {
    final kwLower = keyword.trim().toLowerCase();
    final words = kwLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    double total = 30.0; // baseline
    final factors = <String>[];

    // 1. Direct App Name or partial name match
    final appNameLower = app.name.toLowerCase();
    if (kwLower.contains(appNameLower) || appNameLower.contains(kwLower)) {
      total += 25.0;
      factors.add('Direct match with app title (+25)');
    }

    // 2. Category match
    final categoryLower = app.category.toLowerCase();
    if (kwLower.contains(categoryLower)) {
      total += 15.0;
      factors.add('Direct match with app category "$categoryLower" (+15)');
    }

    // 3. Main features match
    int featureMatches = 0;
    for (final feat in app.mainFeatures) {
      final featWords = feat.toLowerCase().split(' ');
      if (featWords.any((fw) => fw.length > 3 && kwLower.contains(fw))) {
        featureMatches++;
      }
    }
    if (featureMatches > 0) {
      final featBoost = (featureMatches * 10.0).clamp(0.0, 20.0);
      total += featBoost;
      factors.add('Aligned with $featureMatches registered feature(s) (+$featBoost)');
    }

    // 4. USPs match
    bool uspMatched = false;
    for (final usp in app.uniqueSellingPoints) {
      final uspWords = usp.toLowerCase().split(' ');
      if (uspWords.any((uw) => uw.length > 3 && kwLower.contains(uw))) {
        uspMatched = true;
        break;
      }
    }
    if (uspMatched) {
      total += 10.0;
      factors.add('Aligned with unique selling points (+10)');
    }

    // 5. Keyword structure (Long-tail 2-4 words is optimal for discovery)
    if (words.length >= 2 && words.length <= 4) {
      total += 10.0;
      factors.add('Optimal long-tail phrase length (2-4 words) (+10)');
    } else if (words.length > 5) {
      total -= 5.0;
      factors.add('Overly specific phrase length (-5)');
    }

    // 6. Intent weights
    if (intent == 'commercial' || intent == 'transactional') {
      total += 5.0;
      factors.add('High conversion intent (+5)');
    }

    final finalScore = total.clamp(5.0, 100.0);
    final rationale = 'Qualitative relevance score based on semantic overlap with ${app.name}\'s profile and Play Store discovery structure.';

    return ScoreExplanation(
      score: finalScore,
      rationale: rationale,
      contributingFactors: factors,
    );
  }

  /// Generates long-tail keyword suggestions derived from the app's real metadata.
  static List<String> generateSuggestedKeywords(AppModel app) {
    final suggestions = <String>{};
    final name = app.name;
    final cat = app.category.split('&').first.trim().toLowerCase();
    final audience = app.targetAudience ?? 'users';

    // Combinations
    suggestions.add('best $cat app for android');
    suggestions.add('$cat app for $audience');
    suggestions.add('free $cat app');
    suggestions.add('$name android app');
    suggestions.add('how to use $name');

    for (final feat in app.mainFeatures.take(3)) {
      final cleanFeat = feat.toLowerCase();
      suggestions.add('$cleanFeat android');
      suggestions.add('best app for $cleanFeat');
      suggestions.add('$cat with $cleanFeat');
    }

    for (final usp in app.uniqueSellingPoints.take(2)) {
      suggestions.add('$cat $usp');
    }

    return suggestions.toList();
  }
}
