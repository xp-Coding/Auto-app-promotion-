import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apps/providers/app_providers.dart';
import '../models/campaign_model.dart';
import '../repositories/campaign_repository.dart';

final campaignRepositoryProvider = Provider((ref) => CampaignRepository());

final campaignFilterStatusProvider = StateProvider<String>((ref) => 'All');

class CampaignsListNotifier extends StateNotifier<AsyncValue<List<CampaignModel>>> {
  final CampaignRepository _repository;
  final Ref _ref;

  CampaignsListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadCampaigns();
  }

  Future<void> loadCampaigns() async {
    state = const AsyncValue.loading();
    try {
      final selectedApp = _ref.read(selectedAppProvider);
      final status = _ref.read(campaignFilterStatusProvider);
      final list = await _repository.getAllCampaigns(
        appId: selectedApp?.id,
        status: status == 'All' ? null : status,
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CampaignModel> createCampaign(CampaignModel campaign) async {
    final created = await _repository.createCampaign(campaign);
    await loadCampaigns();
    return created;
  }

  Future<CampaignModel> updateCampaign(CampaignModel campaign) async {
    final updated = await _repository.updateCampaign(campaign);
    await loadCampaigns();
    return updated;
  }

  Future<void> updateStatus(String id, String status) async {
    await _repository.updateCampaignStatus(id, status);
    await loadCampaigns();
  }

  Future<void> deleteCampaign(String id) async {
    await _repository.deleteCampaign(id);
    await loadCampaigns();
  }
}

final campaignsListProvider = StateNotifierProvider<CampaignsListNotifier, AsyncValue<List<CampaignModel>>>((ref) {
  // Reload campaigns whenever the selected app changes
  ref.watch(selectedAppProvider);
  final repo = ref.watch(campaignRepositoryProvider);
  return CampaignsListNotifier(repo, ref);
});

final selectedCampaignProvider = StateProvider<CampaignModel?>((ref) => null);
