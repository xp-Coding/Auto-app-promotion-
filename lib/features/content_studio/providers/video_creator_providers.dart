import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../autopilot/domain/video_project_exporter.dart';
import '../../autopilot/models/video_project_model.dart';
import '../domain/ffmpeg_service.dart';
import '../domain/storyboard_planner_service.dart';
import '../domain/vimax_service.dart';
import '../repositories/video_project_repository.dart';

final videoProjectRepositoryProvider = Provider<VideoProjectRepository>((ref) {
  return VideoProjectRepository();
});

final ffmpegServiceProvider = Provider<FfmpegService>((ref) {
  return FfmpegService();
});

final storyboardPlannerServiceProvider = Provider<StoryboardPlannerService>((ref) {
  return StoryboardPlannerService();
});

final videoProjectExporterProvider = Provider<VideoProjectExporter>((ref) {
  final ffmpeg = ref.watch(ffmpegServiceProvider);
  return VideoProjectExporter(ffmpeg);
});

final ffmpegStatusProvider = FutureProvider<FfmpegStatus>((ref) async {
  final service = ref.watch(ffmpegServiceProvider);
  return service.checkAvailability();
});

final defaultExportFolderProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(ffmpegServiceProvider);
  return service.getDefaultExportFolder();
});

final currentVideoProjectProvider = StateProvider<VideoProjectModel?>((ref) => null);

class VideoExportState {
  final bool isRendering;
  final double progress;
  final String statusMessage;
  final String? errorMessage;
  final VideoExportResult? result;

  const VideoExportState({
    this.isRendering = false,
    this.progress = 0.0,
    this.statusMessage = 'Idle',
    this.errorMessage,
    this.result,
  });
}

final videoExportStateProvider = StateProvider<VideoExportState>((ref) => const VideoExportState());

class VideoProjectsListNotifier extends StateNotifier<AsyncValue<List<VideoProjectModel>>> {
  final VideoProjectRepository _repository;

  VideoProjectsListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadProjects();
  }

  Future<void> loadProjects() async {
    try {
      state = const AsyncValue.loading();
      final list = await _repository.getAllProjects();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveProject(VideoProjectModel project) async {
    await _repository.saveProject(project);
    await loadProjects();
  }

  Future<void> deleteProject(String id) async {
    await _repository.deleteProject(id);
    await loadProjects();
  }
}

final videoProjectsListProvider = StateNotifierProvider<VideoProjectsListNotifier, AsyncValue<List<VideoProjectModel>>>((ref) {
  final repo = ref.watch(videoProjectRepositoryProvider);
  return VideoProjectsListNotifier(repo);
});

final vimaxServiceProvider = Provider<ViMaxService>((ref) {
  return ViMaxService();
});

final vimaxStatusProvider = FutureProvider<ViMaxStatus>((ref) async {
  final service = ref.watch(vimaxServiceProvider);
  return service.checkStatus();
});

final wan2gpStatusProvider = FutureProvider<Wan2GPStatus>((ref) async {
  final service = ref.watch(vimaxServiceProvider);
  return service.getWan2GPStatus();
});

final diagnosticsProvider = FutureProvider<DiagnosticsReport?>((ref) async {
  final service = ref.watch(vimaxServiceProvider);
  return service.getDiagnostics();
});

/// Selectable AI video generation provider: 'vimax' or 'wan2gp'
final selectedVideoProviderProvider = StateProvider<String>((ref) => 'vimax');

final vimaxActiveJobProvider = StateProvider<ViMaxJobState?>((ref) => null);
