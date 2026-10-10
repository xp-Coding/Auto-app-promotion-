import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/autopilot_run_model.dart';
import '../models/autopilot_settings_model.dart';
import '../repositories/autopilot_repository.dart';
import '../domain/autopilot_orchestrator.dart';
import '../domain/play_store_scraper.dart';
import '../../apps/models/app_model.dart';
import '../../apps/providers/app_providers.dart';
import '../../apps/repositories/app_repository.dart';

final autopilotRepositoryProvider = Provider<AutopilotRepository>((ref) {
  return AutopilotRepository();
});

final autopilotOrchestratorProvider = Provider<AutopilotOrchestrator>((ref) {
  return AutopilotOrchestrator();
});

/// StateNotifier for managing Autopilot Settings
class AutopilotSettingsNotifier extends StateNotifier<AsyncValue<AutopilotSettingsModel>> {
  final AutopilotRepository _repository;

  AutopilotSettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _repository.getSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSettings(AutopilotSettingsModel newSettings) async {
    try {
      await _repository.saveSettings(newSettings);
      state = AsyncValue.data(newSettings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final autopilotSettingsProvider =
    StateNotifierProvider<AutopilotSettingsNotifier, AsyncValue<AutopilotSettingsModel>>((ref) {
  final repo = ref.watch(autopilotRepositoryProvider);
  return AutopilotSettingsNotifier(repo);
});

/// StateNotifier for managing active and past Autopilot Runs
class AutopilotRunsNotifier extends StateNotifier<AsyncValue<List<AutopilotRunModel>>> {
  final AutopilotRepository _repository;
  final AutopilotOrchestrator _orchestrator;
  final Ref _ref;

  AutopilotRunsNotifier(this._repository, this._orchestrator, this._ref)
      : super(const AsyncValue.loading()) {
    loadRuns();
  }

  Future<void> loadRuns() async {
    try {
      final runs = await _repository.getAllRuns();
      state = AsyncValue.data(runs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Launches an automated promotion workflow for the specified or created app.
  Future<AutopilotRunModel> launchAutopilot({
    String? rawUrlOrPackage,
    AppModel? existingApp,
    ScrapedAppResult? scrapedResult,
  }) async {
    final settingsAsync = _ref.read(autopilotSettingsProvider);
    final settings = settingsAsync.value ??
        AutopilotSettingsModel(
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

    AutopilotExecutionResult result;
    if (scrapedResult != null) {
      final appRepo = AppRepository();
      final existing = await appRepo.getAppByPackageName(scrapedResult.app.packageName);
      final targetApp = existing != null
          ? await appRepo.updateApp(scrapedResult.app.copyWith(id: existing.id))
          : await appRepo.createApp(scrapedResult.app);

      result = await _orchestrator.runAutopilotForApp(
        app: targetApp,
        screenshotPaths: scrapedResult.localScreenshotPaths,
        iconPath: scrapedResult.localIconPath,
        settings: settings,
        onProgress: (progress, step) {
          loadRuns();
        },
      );
    } else if (existingApp != null) {
      result = await _orchestrator.runAutopilotForApp(
        app: existingApp,
        screenshotPaths: const [],
        iconPath: existingApp.iconPath,
        settings: settings,
        onProgress: (progress, step) {
          loadRuns();
        },
      );
    } else {
      result = await _orchestrator.runAutopilotFromInput(
        urlOrPackage: rawUrlOrPackage ?? '',
        settings: settings,
        onProgress: (progress, step) {
          loadRuns();
        },
      );
    }

    // Refresh apps list and selected app if a new app was added
    _ref.read(appsListProvider.notifier).loadApps();
    await loadRuns();
    return result.run;
  }
}

final autopilotRunsProvider =
    StateNotifierProvider<AutopilotRunsNotifier, AsyncValue<List<AutopilotRunModel>>>((ref) {
  final repo = ref.watch(autopilotRepositoryProvider);
  final orchestrator = ref.watch(autopilotOrchestratorProvider);
  return AutopilotRunsNotifier(repo, orchestrator, ref);
});

/// Latest Autopilot Run Provider
final latestAutopilotRunProvider = Provider<AutopilotRunModel?>((ref) {
  final runsAsync = ref.watch(autopilotRunsProvider);
  return runsAsync.maybeWhen(
    data: (runs) => runs.isNotEmpty ? runs.first : null,
    orElse: () => null,
  );
});
