import 'package:flutter_test/flutter_test.dart';
import 'package:appgrowth_studio/features/autopilot/domain/play_store_scraper.dart';

void main() {
  group('PlayStoreScraperService Unit Tests', () {
    late PlayStoreScraperService scraper;

    setUp(() {
      scraper = PlayStoreScraperService();
    });

    test('normalizePackageName parses standard play store web URLs', () {
      const url1 = 'https://play.google.com/store/apps/details?id=com.spotify.music&hl=en_US';
      expect(scraper.normalizePackageName(url1), equals('com.spotify.music'));

      const url2 = 'https://play.google.com/store/apps/details?id=com.whatsapp';
      expect(scraper.normalizePackageName(url2), equals('com.whatsapp'));
    });

    test('normalizePackageName extracts valid plain package names', () {
      expect(scraper.normalizePackageName('com.example.habit.tracker'), equals('com.example.habit.tracker'));
      expect(scraper.normalizePackageName('org.videolan.vlc'), equals('org.videolan.vlc'));
      expect(scraper.normalizePackageName('  com.duolingo  '), equals('com.duolingo'));
    });

    test('scrapeAndExtractApp offline fallback produces structured profile', () async {
      // Offline fallback test with arbitrary package name
      final result = await scraper.scrapeAndExtractApp(urlOrPackage: 'com.habit.tracker');

      expect(result.app.packageName, equals('com.habit.tracker'));
      expect(result.app.name.isNotEmpty, isTrue);
      expect(result.app.category, equals('Productivity'));
      expect(result.app.mainFeatures.isNotEmpty, isTrue);
      expect(result.targetAudience.isNotEmpty, isTrue);
    });

    test('scrapeAndExtractApp populates validation checklist, developer name, and sources', () async {
      final result = await scraper.scrapeAndExtractApp(urlOrPackage: 'com.habitmaster.productivity');
      expect(result.developerName, equals('Habitmaster Inc'));
      expect(result.valueProposition, contains('with a clean Android user experience'));
      expect(result.extractedUseCases.length, greaterThanOrEqualTo(2));
      expect(result.validationChecklist, isNotEmpty);
      expect(result.validationChecklist.keys, contains('Title & Package Identified'));
      expect(result.validationChecklist.keys, contains('Category Classified'));
      expect(result.validationChecklist.keys, contains('Core Features Extracted'));
      expect(result.validationChecklist.keys, contains('Target Audience Inferred'));
      expect(result.fieldSources.keys, contains('Title'));
      expect(result.fieldSources.keys, contains('Category'));
      expect(result.warnings, isNotEmpty); // Since it used heuristics/offline fallback, it clearly labels it as estimate
    });
  });
}
