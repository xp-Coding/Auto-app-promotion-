import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appgrowth_studio/core/database/sqlite_initializer.dart';
import 'package:appgrowth_studio/main.dart';

void main() {
  setUpAll(() {
    SqliteInitializer.initialize();
  });

  testWidgets('AppGrowthStudio desktop shell smoke test', (WidgetTester tester) async {
    // Configure standard desktop screen resolution for desktop widget test
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: AppGrowthStudioApp(),
      ),
    );

    // Initial pump and animation ticks
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Brand title and navigation items are rendered
    expect(find.text('AppGrowth'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('My Apps'), findsOneWidget);
  });
}
