import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/sqlite_initializer.dart';
import 'core/services/safe_background_worker.dart';
import 'core/theme/app_theme.dart';
import 'features/publishing/providers/publishing_providers.dart';
import 'features/shell/desktop_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for Windows Desktop
  SqliteInitializer.initialize();

  // Perform startup restart recovery for interrupted jobs
  await SafeBackgroundWorker.instance.performStartupRecovery();

  runApp(
    const ProviderScope(
      child: AppGrowthStudioApp(),
    ),
  );
}

class AppGrowthStudioApp extends ConsumerStatefulWidget {
  const AppGrowthStudioApp({super.key});

  @override
  ConsumerState<AppGrowthStudioApp> createState() => _AppGrowthStudioAppState();
}

class _AppGrowthStudioAppState extends ConsumerState<AppGrowthStudioApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = ref.read(publishingEngineProvider);
      SafeBackgroundWorker.instance.start(engine: engine);
    });
  }

  @override
  void dispose() {
    SafeBackgroundWorker.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'AppGrowth Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const DesktopShell(),
    );
  }
}
