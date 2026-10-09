import 'package:flutter_test/flutter_test.dart';
import 'package:appgrowth_studio/core/utils/validators.dart';

void main() {
  group('Validators and Play Store URL tests', () {
    test('Validates Play Store URLs correctly', () {
      expect(
        Validators.isValidPlayStoreUrl(
          'https://play.google.com/store/apps/details?id=com.google.android.apps.photos',
        ),
        isTrue,
      );

      expect(
        Validators.isValidPlayStoreUrl(
          'https://play.google.com/store/apps/details?id=com.example.habit.tracker&hl=en&gl=US',
        ),
        isTrue,
      );

      expect(
        Validators.isValidPlayStoreUrl('https://google.com'),
        isFalse,
      );

      expect(
        Validators.isValidPlayStoreUrl(''),
        isFalse,
      );

      expect(
        Validators.isValidPlayStoreUrl('not-a-url'),
        isFalse,
      );
    });

    test('Extracts package name from Play Store URLs', () {
      expect(
        Validators.extractPackageName(
          'https://play.google.com/store/apps/details?id=com.studio.focusflow',
        ),
        'com.studio.focusflow',
      );

      expect(
        Validators.extractPackageName(
          'https://play.google.com/store/apps/details?id=com.company.app.pro&referrer=utm_source%3Dyoutube',
        ),
        'com.company.app.pro',
      );

      expect(
        Validators.extractPackageName('https://play.google.com/store/apps'),
        isNull,
      );
    });

    test('Validates Android package names correctly', () {
      expect(Validators.isValidPackageName('com.example.app'), isTrue);
      expect(Validators.isValidPackageName('org.studio_apps.tool'), isTrue);
      expect(Validators.isValidPackageName('com.sub.domain.app_name'), isTrue);

      expect(Validators.isValidPackageName('invalid'), isFalse);
      expect(Validators.isValidPackageName('123.com.app'), isFalse);
      expect(Validators.isValidPackageName('com..empty'), isFalse);
      expect(Validators.isValidPackageName(''), isFalse);
    });

    test('Listing Quality Score calculates correctly', () {
      final highQuality = Validators.evaluateListingQuality(
        name: 'FocusFlow Habits',
        packageName: 'com.studio.focusflow',
        shortDescription: 'Smart daily habit tracker with streaks',
        fullDescription: 'A' * 550, // 550 chars
        mainFeatures: ['Streak Tracker', 'Cloud Sync', 'Smart Reminders'],
        uniqueSellingPoints: ['Zero ads and 100% private'],
        targetAudience: 'Students and remote workers',
        iconPath: 'C:/assets/icon.png',
        privacyPolicyUrl: 'https://example.com/privacy',
      );

      expect(highQuality.score, 100);
      expect(highQuality.grade, 'Excellent');
      expect(highQuality.items.every((i) => i.isPassed), isTrue);

      final minimal = Validators.evaluateListingQuality(
        name: 'Short',
        packageName: 'com.minimal.app',
        shortDescription: null,
        fullDescription: null,
        mainFeatures: [],
        uniqueSellingPoints: [],
        targetAudience: null,
        iconPath: null,
        privacyPolicyUrl: null,
      );

      expect(minimal.score, 25);
      expect(minimal.grade, 'Needs Improvement');
    });
  });
}
