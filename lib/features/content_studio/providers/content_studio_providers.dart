import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apps/providers/app_providers.dart';
import '../../campaigns/providers/campaign_providers.dart';
import '../domain/content_generation_provider.dart';
import '../domain/template_content_provider.dart';
import '../models/content_post_model.dart';
import '../repositories/content_post_repository.dart';

final contentPostRepositoryProvider = Provider((ref) => ContentPostRepository());

final contentGenerationProvider = Provider<ContentGenerationProvider>((ref) {
  return TemplateContentProvider();
});

class ContentFilterState {
  final String selectedPlatform;
  final String selectedStatus;
  final String? selectedCampaignId;

  const ContentFilterState({
    this.selectedPlatform = 'All',
    this.selectedStatus = 'All',
    this.selectedCampaignId,
  });

  ContentFilterState copyWith({
    String? selectedPlatform,
    String? selectedStatus,
    String? selectedCampaignId,
  }) {
    return ContentFilterState(
      selectedPlatform: selectedPlatform ?? this.selectedPlatform,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedCampaignId: selectedCampaignId ?? this.selectedCampaignId,
    );
  }
}

final contentFilterProvider = StateProvider<ContentFilterState>((ref) {
  return const ContentFilterState();
});

class ContentPostsNotifier extends StateNotifier<AsyncValue<List<ContentPostModel>>> {
  final ContentPostRepository _repository;
  final Ref _ref;

  ContentPostsNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadPosts();
  }

  Future<void> loadPosts() async {
    state = const AsyncValue.loading();
    try {
      final selectedApp = _ref.read(selectedAppProvider);
      final filter = _ref.read(contentFilterProvider);
      final posts = await _repository.getAllPosts(
        appId: selectedApp?.id,
        campaignId: filter.selectedCampaignId,
        platform: filter.selectedPlatform == 'All' ? null : filter.selectedPlatform,
        status: filter.selectedStatus == 'All' ? null : filter.selectedStatus,
      );
      state = AsyncValue.data(posts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ContentPostModel> savePost(ContentPostModel post) async {
    final existing = await _repository.getPostById(post.id);
    ContentPostModel result;
    if (existing == null) {
      result = await _repository.createPost(post);
    } else {
      result = await _repository.updatePost(post);
    }
    await loadPosts();
    return result;
  }

  Future<void> deletePost(String id) async {
    await _repository.deletePost(id);
    await loadPosts();
  }
}

final contentPostsListProvider = StateNotifierProvider<ContentPostsNotifier, AsyncValue<List<ContentPostModel>>>((ref) {
  // Reload posts whenever selected app or selected campaign changes
  ref.watch(selectedAppProvider);
  ref.watch(selectedCampaignProvider);
  final repo = ref.watch(contentPostRepositoryProvider);
  return ContentPostsNotifier(repo, ref);
});
