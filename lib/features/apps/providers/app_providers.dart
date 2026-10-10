import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_model.dart';
import '../repositories/app_repository.dart';

final appRepositoryProvider = Provider<AppRepository>((ref) {
  return AppRepository();
});

class AppsFilterState {
  final String searchQuery;
  final String selectedCategory;
  final bool showArchived;

  const AppsFilterState({
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.showArchived = false,
  });

  AppsFilterState copyWith({
    String? searchQuery,
    String? selectedCategory,
    bool? showArchived,
  }) {
    return AppsFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      showArchived: showArchived ?? this.showArchived,
    );
  }
}

final appsFilterProvider = StateProvider<AppsFilterState>((ref) {
  return const AppsFilterState();
});

class AppsListNotifier extends StateNotifier<AsyncValue<List<AppModel>>> {
  final AppRepository _repository;
  final Ref _ref;

  AppsListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadApps();
  }

  Future<void> loadApps() async {
    state = const AsyncValue.loading();
    try {
      final filter = _ref.read(appsFilterProvider);
      final apps = await _repository.getAllApps(
        includeArchived: filter.showArchived,
        searchQuery: filter.searchQuery,
        category: filter.selectedCategory == 'All' ? null : filter.selectedCategory,
      );
      if (!mounted) return;
      state = AsyncValue.data(apps);

      // If no app selected or selected app is archived/removed, select first active app
      final selected = _ref.read(selectedAppProvider);
      if (selected == null && apps.isNotEmpty) {
        _ref.read(selectedAppProvider.notifier).state = apps.first;
      }
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<AppModel> createApp(AppModel app) async {
    final created = await _repository.createApp(app);
    await loadApps();
    _ref.read(selectedAppProvider.notifier).state = created;
    return created;
  }

  Future<AppModel> updateApp(AppModel app) async {
    final updated = await _repository.updateApp(app);
    await loadApps();
    final currentSelected = _ref.read(selectedAppProvider);
    if (currentSelected?.id == updated.id) {
      _ref.read(selectedAppProvider.notifier).state = updated;
    }
    return updated;
  }

  Future<void> archiveApp(String id, bool archive) async {
    await _repository.archiveApp(id, archive);
    await loadApps();
  }

  Future<void> deleteApp(String id) async {
    await _repository.deleteApp(id);
    await loadApps();
    final currentSelected = _ref.read(selectedAppProvider);
    if (currentSelected?.id == id) {
      final currentList = state.value ?? [];
      _ref.read(selectedAppProvider.notifier).state =
          currentList.isNotEmpty ? currentList.first : null;
    }
  }
}

final appsListProvider = StateNotifierProvider<AppsListNotifier, AsyncValue<List<AppModel>>>((ref) {
  final repository = ref.watch(appRepositoryProvider);
  return AppsListNotifier(repository, ref);
});

final selectedAppProvider = StateProvider<AppModel?>((ref) => null);

final activeAppCountProvider = FutureProvider<int>((ref) async {
  // Watches list to update count when list changes
  ref.watch(appsListProvider);
  final repo = ref.read(appRepositoryProvider);
  return repo.getActiveAppsCount();
});
