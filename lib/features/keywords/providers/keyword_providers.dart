import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apps/providers/app_providers.dart';
import '../models/keyword_model.dart';
import '../repositories/keyword_repository.dart';

final keywordRepositoryProvider = Provider((ref) => KeywordRepository());

final keywordTopicFilterProvider = StateProvider<String>((ref) => 'All');
final keywordIntentFilterProvider = StateProvider<String>((ref) => 'All');
final keywordSearchQueryProvider = StateProvider<String>((ref) => '');

class KeywordsListNotifier extends StateNotifier<AsyncValue<List<KeywordModel>>> {
  final KeywordRepository _repository;
  final Ref _ref;

  KeywordsListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadKeywords();
  }

  Future<void> loadKeywords() async {
    state = const AsyncValue.loading();
    try {
      final selectedApp = _ref.read(selectedAppProvider);
      final topic = _ref.read(keywordTopicFilterProvider);
      final intent = _ref.read(keywordIntentFilterProvider);
      final query = _ref.read(keywordSearchQueryProvider);

      final list = await _repository.getAllKeywords(
        appId: selectedApp?.id,
        topicCluster: topic == 'All' ? null : topic,
        intent: intent == 'All' ? null : intent,
        searchQuery: query.trim().isNotEmpty ? query : null,
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<KeywordModel> addKeyword(KeywordModel keyword) async {
    final added = await _repository.addKeyword(keyword);
    await loadKeywords();
    return added;
  }

  Future<void> deleteKeyword(String id) async {
    await _repository.deleteKeyword(id);
    await loadKeywords();
  }

  Future<int> importFromCsv(String appId, String csvContent) async {
    final count = await _repository.importKeywordsFromCsv(appId, csvContent);
    await loadKeywords();
    return count;
  }
}

final keywordsListProvider = StateNotifierProvider<KeywordsListNotifier, AsyncValue<List<KeywordModel>>>((ref) {
  // Watch active app to reload keywords when app switcher is toggled
  ref.watch(selectedAppProvider);
  final repo = ref.watch(keywordRepositoryProvider);
  return KeywordsListNotifier(repo, ref);
});
