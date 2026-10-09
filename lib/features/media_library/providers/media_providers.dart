import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apps/providers/app_providers.dart';
import '../models/media_item_model.dart';
import '../repositories/media_repository.dart';

final mediaRepositoryProvider = Provider((ref) => MediaRepository());

final mediaFilterTypeProvider = StateProvider<String>((ref) => 'All');
final mediaSearchQueryProvider = StateProvider<String>((ref) => '');

class MediaListNotifier extends StateNotifier<AsyncValue<List<MediaItemModel>>> {
  final MediaRepository _repository;
  final Ref _ref;

  MediaListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadMedia();
  }

  Future<void> loadMedia() async {
    state = const AsyncValue.loading();
    try {
      final selectedApp = _ref.read(selectedAppProvider);
      final type = _ref.read(mediaFilterTypeProvider);
      final query = _ref.read(mediaSearchQueryProvider);
      final items = await _repository.getAllMedia(
        appId: selectedApp?.id,
        mediaType: type == 'All' ? null : type,
        searchQuery: query.trim().isNotEmpty ? query : null,
      );
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<MediaItemModel> addMedia(MediaItemModel item) async {
    final added = await _repository.addMedia(item);
    await loadMedia();
    return added;
  }

  Future<void> deleteMedia(String id) async {
    await _repository.deleteMedia(id);
    await loadMedia();
  }
}

final mediaListProvider = StateNotifierProvider<MediaListNotifier, AsyncValue<List<MediaItemModel>>>((ref) {
  // Watch selected app to reload media when active app changes
  ref.watch(selectedAppProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return MediaListNotifier(repo, ref);
});
