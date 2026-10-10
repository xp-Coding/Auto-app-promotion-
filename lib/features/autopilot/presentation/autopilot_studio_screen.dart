import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/models/app_model.dart';
import '../../apps/providers/app_providers.dart';
import '../domain/play_store_scraper.dart';
import '../models/autopilot_run_model.dart';
import '../models/autopilot_settings_model.dart';
import '../providers/autopilot_providers.dart';

class AutopilotStudioScreen extends ConsumerStatefulWidget {
  const AutopilotStudioScreen({super.key});

  @override
  ConsumerState<AutopilotStudioScreen> createState() => _AutopilotStudioScreenState();
}

class _AutopilotStudioScreenState extends ConsumerState<AutopilotStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Single-input controller
  final _urlOrPackageController = TextEditingController();
  bool _isLaunching = false;
  bool _isAnalyzing = false;
  String? _inlineError;

  // Editable app profile state (post-analysis)
  ScrapedAppResult? _analyzedResult;
  final _editNameController = TextEditingController();
  final _editCategoryController = TextEditingController();
  final _editShortDescController = TextEditingController();
  final _editAudienceController = TextEditingController();
  final _editBrandToneController = TextEditingController();
  final _editPrivacyController = TextEditingController();
  final _newFeatureController = TextEditingController();
  List<String> _editableFeatures = [];
  List<String> _editableUsps = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlOrPackageController.dispose();
    _editNameController.dispose();
    _editCategoryController.dispose();
    _editShortDescController.dispose();
    _editAudienceController.dispose();
    _editBrandToneController.dispose();
    _editPrivacyController.dispose();
    _newFeatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(autopilotRunsProvider);
    final settingsAsync = ref.watch(autopilotSettingsProvider);
    final selectedApp = ref.watch(selectedAppProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryIndigo, AppTheme.accentCyan],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'App Promotion Autopilot',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentEmerald.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.accentEmerald.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'Autonomous Engine',
                                style: TextStyle(
                                  color: AppTheme.accentEmerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Provide a Google Play Store URL or package name. The system scrapes listing details, builds a 30-day strategy, renders local media, and queues posts.',
                          style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Start New Autopilot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    _tabController.animateTo(0);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.primaryIndigo,
              unselectedLabelColor: AppTheme.darkTextSecondary,
              indicatorColor: AppTheme.primaryIndigo,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.bolt, size: 18), text: '⚡ One-Input Onboarding'),
                Tab(icon: Icon(Icons.history_toggle_off, size: 18), text: '📊 Autopilot Activity & Runs'),
                Tab(icon: Icon(Icons.tune, size: 18), text: '⚙️ Autopilot Configuration'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOneInputOnboardingTab(selectedApp),
                  _buildActivityTab(runsAsync),
                  _buildSettingsTab(settingsAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: ONE-INPUT ONBOARDING
  // ==========================================
  Widget _buildOneInputOnboardingTab(AppModel? selectedApp) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Launch Automatic App Promotion',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your Google Play Store URL or package name. Autopilot extracts metadata, downloads assets, creates 30 days of multi-format content, and pushes to the queue.',
                  style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _urlOrPackageController,
                            decoration: InputDecoration(
                              hintText: 'e.g. https://play.google.com/store/apps/details?id=com.spotify.music or com.whatsapp',
                              prefixIcon: const Icon(Icons.link, color: AppTheme.primaryIndigo),
                              suffixIcon: _urlOrPackageController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _urlOrPackageController.clear();
                                          _inlineError = null;
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Theme.of(context).canvasColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Theme.of(context).dividerColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Theme.of(context).dividerColor),
                              ),
                            ),
                            onChanged: (_) {
                              if (_inlineError != null) setState(() => _inlineError = null);
                            },
                          ),
                          if (_inlineError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _inlineError!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Row(
                      children: [
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            icon: _isAnalyzing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.manage_search, size: 20),
                            label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Listing'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryIndigo,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: AppTheme.primaryIndigo, width: 1.5),
                            ),
                            onPressed: _isAnalyzing || _isLaunching ? null : _handleAnalyzeListing,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            icon: _isLaunching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.rocket_launch, size: 18),
                            label: Text(_isLaunching ? 'Promoting...' : 'Start Autopilot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryIndigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isLaunching || _isAnalyzing ? null : _handleLaunchAutopilot,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Quick Presets:',
                      style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                    ),
                    ActionChip(
                      label: const Text('Habit Tracker (com.habit.tracker)'),
                      labelStyle: const TextStyle(fontSize: 11),
                      onPressed: () {
                        setState(() {
                          _urlOrPackageController.text = 'com.habit.tracker';
                          _inlineError = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Mindful Meditation (com.mindful.meditation)'),
                      labelStyle: const TextStyle(fontSize: 11),
                      onPressed: () {
                        setState(() {
                          _urlOrPackageController.text = 'com.mindful.meditation';
                          _inlineError = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Fitness Workout (com.fitness.workout)'),
                      labelStyle: const TextStyle(fontSize: 11),
                      onPressed: () {
                        setState(() {
                          _urlOrPackageController.text = 'com.fitness.workout';
                          _inlineError = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Analysis Loading State
          if (_isAnalyzing) ...[
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.4)),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text(
                    'Extracting Public Google Play Store Listing...',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Downloading verified app icon, screenshots, category, description, and identifying core features without fabricating metrics.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Extracted & Editable App Profile Card
          if (_analyzedResult != null) ...[
            _buildAnalyzedProfileCard(),
            const SizedBox(height: 24),
          ],

          // Default state when not analyzing and no profile extracted yet
          if (_analyzedResult == null && !_isAnalyzing) ...[
            // Or promote currently selected app card
            if (selectedApp != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primaryIndigo.withOpacity(0.1),
                      backgroundImage: selectedApp.iconPath != null && selectedApp.iconPath!.isNotEmpty
                          ? (selectedApp.iconPath!.startsWith('http')
                              ? NetworkImage(selectedApp.iconPath!) as ImageProvider
                              : null)
                          : null,
                      child: selectedApp.iconPath == null || selectedApp.iconPath!.isEmpty
                          ? const Icon(Icons.android, color: AppTheme.primaryIndigo)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Currently Selected: ${selectedApp.name}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${selectedApp.packageName} • Category: ${selectedApp.category} • Target: ${selectedApp.targetAudience ?? "General"}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('Run Autopilot on This App'),
                      onPressed: _isLaunching ? null : () => _handleLaunchForApp(selectedApp),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Pipeline Workflow Cards
            const Text(
              'Autonomous Execution Pipeline',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.1,
              children: const [
                _PipelineStepCard(
                  stepNumber: '1',
                  title: 'Listing Scraping',
                  description: 'Extracts title, category, full description, USP, app icon, and store screenshots.',
                  icon: Icons.cloud_download_outlined,
                ),
                _PipelineStepCard(
                  stepNumber: '2',
                  title: 'Market & Keyword Clustering',
                  description: 'Researches category tags, high-intent keywords, and relevance scores.',
                  icon: Icons.tag_outlined,
                ),
                _PipelineStepCard(
                  stepNumber: '3',
                  title: '30-Day Strategy Calendar',
                  description: 'Generates daily multi-platform content with hook copy, CTAs, and hashtags.',
                  icon: Icons.calendar_month_outlined,
                ),
                _PipelineStepCard(
                  stepNumber: '4',
                  title: 'High-Res Graphic Cards',
                  description: 'Renders genuine 1080x1920 (9:16) and 1920x1080 (16:9) PNG posters locally.',
                  icon: Icons.photo_size_select_actual_outlined,
                ),
                _PipelineStepCard(
                  stepNumber: '5',
                  title: '7 Video Archetypes',
                  description: 'Builds scene manifests, narration scripts, and visual timelines for vertical video.',
                  icon: Icons.video_collection_outlined,
                ),
                _PipelineStepCard(
                  stepNumber: '6',
                  title: 'Publishing Queue Dispatch',
                  description: 'Enqueues scheduled jobs with compliance safeguards and official YouTube support.',
                  icon: Icons.schedule_send_outlined,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: AUTOPILOT ACTIVITY & RUNS
  // ==========================================
  Widget _buildActivityTab(AsyncValue<List<AutopilotRunModel>> runsAsync) {
    return runsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading runs: $e')),
      data: (runs) {
        if (runs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rocket_outlined, size: 56, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text(
                  'No Autopilot Runs Yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start a promotion from the One-Input Onboarding tab to view live progress here.',
                  style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bolt, size: 16),
                  label: const Text('Go to Onboarding'),
                  onPressed: () => _tabController.animateTo(0),
                ),
              ],
            ),
          );
        }

        final activeRun = runs.firstWhere(
          (r) => r.status == 'running',
          orElse: () => runs.first,
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active / Most Recent Run Status Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: activeRun.status == 'running'
                        ? AppTheme.primaryIndigo
                        : Theme.of(context).dividerColor,
                    width: activeRun.status == 'running' ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(activeRun.status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getStatusIcon(activeRun.status),
                                color: _getStatusColor(activeRun.status),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Run: ${activeRun.id}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'App ID: ${activeRun.appId} • Updated: ${_formatDateTime(activeRun.updatedAt)}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(activeRun.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            activeRun.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(activeRun.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Progress Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              activeRun.currentStep,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${(activeRun.progress * 100).toInt()}%',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: activeRun.progress,
                            minHeight: 8,
                            backgroundColor: Theme.of(context).canvasColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              activeRun.status == 'failed' ? Colors.redAccent : AppTheme.primaryIndigo,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats row
                    Row(
                      children: [
                        _StatBox(
                          label: 'Posts Generated',
                          value: '${activeRun.totalPostsCreated}',
                          icon: Icons.article_outlined,
                        ),
                        const SizedBox(width: 16),
                        _StatBox(
                          label: 'Publishing Jobs Queued',
                          value: '${activeRun.totalJobsQueued}',
                          icon: Icons.schedule_send_outlined,
                        ),
                        const SizedBox(width: 16),
                        _StatBox(
                          label: 'Creative Assets Built',
                          value: '${activeRun.totalAssetsCreated}',
                          icon: Icons.photo_library_outlined,
                        ),
                      ],
                    ),

                    if (activeRun.errorMessage != null && activeRun.errorMessage!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activeRun.errorMessage!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Run History Table
              const Text(
                'Historical Autopilot Runs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: runs.length,
                  separatorBuilder: (context, index) => Divider(color: Theme.of(context).dividerColor, height: 1),
                  itemBuilder: (context, index) {
                    final run = runs[index];
                    return ListTile(
                      leading: Icon(_getStatusIcon(run.status), color: _getStatusColor(run.status)),
                      title: Text(run.id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(
                        '${run.currentStep} • ${run.totalPostsCreated} posts, ${run.totalJobsQueued} queued jobs • ${_formatDateTime(run.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                      ),
                      trailing: Text(
                        run.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(run.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 3: AUTOPILOT CONFIGURATION
  // ==========================================
  Widget _buildSettingsTab(AsyncValue<AutopilotSettingsModel> settingsAsync) {
    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading configuration: $e')),
      data: (settings) {
        return _AutopilotSettingsForm(
          settings: settings,
          onSave: (updated) {
            ref.read(autopilotSettingsProvider.notifier).updateSettings(updated);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Autopilot configuration updated successfully!')),
            );
          },
        );
      },
    );
  }

  // Action: Analyze Play Store Listing and extract editable profile
  Future<void> _handleAnalyzeListing() async {
    final text = _urlOrPackageController.text.trim();
    if (text.isEmpty) {
      setState(() => _inlineError = 'Please enter a Google Play Store URL or package name.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _inlineError = null;
    });

    try {
      final scraper = PlayStoreScraperService();
      final res = await scraper.scrapeAndExtractApp(urlOrPackage: text);
      setState(() {
        _analyzedResult = res;
        _editNameController.text = res.app.name;
        _editCategoryController.text = res.app.category;
        _editShortDescController.text = res.app.shortDescription ?? '';
        _editAudienceController.text = res.targetAudience;
        _editBrandToneController.text = res.app.brandTone ?? 'Informative & Modern';
        _editPrivacyController.text = res.app.privacyPolicyUrl ?? '';
        _editableFeatures = List<String>.from(res.extractedFeatures);
        _editableUsps = List<String>.from(res.extractedUsps);
      });
    } catch (e) {
      setState(() {
        _inlineError = 'Could not analyze listing: $e';
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // Action: Launch Autopilot with user-verified/edited app profile
  Future<void> _handleLaunchWithAnalyzedProfile() async {
    if (_analyzedResult == null) return;
    setState(() => _isLaunching = true);

    try {
      final updatedApp = _analyzedResult!.app.copyWith(
        name: _editNameController.text.trim().isNotEmpty ? _editNameController.text.trim() : _analyzedResult!.app.name,
        category: _editCategoryController.text.trim().isNotEmpty ? _editCategoryController.text.trim() : _analyzedResult!.app.category,
        shortDescription: _editShortDescController.text.trim().isNotEmpty ? _editShortDescController.text.trim() : null,
        targetAudience: _editAudienceController.text.trim().isNotEmpty ? _editAudienceController.text.trim() : null,
        brandTone: _editBrandToneController.text.trim().isNotEmpty ? _editBrandToneController.text.trim() : null,
        privacyPolicyUrl: _editPrivacyController.text.trim().isNotEmpty ? _editPrivacyController.text.trim() : null,
        mainFeatures: _editableFeatures,
        uniqueSellingPoints: _editableUsps,
      );

      final updatedResult = ScrapedAppResult(
        app: updatedApp,
        localIconPath: _analyzedResult!.localIconPath,
        localScreenshotPaths: _analyzedResult!.localScreenshotPaths,
        extractedFeatures: _editableFeatures,
        extractedUsps: _editableUsps,
        targetAudience: _editAudienceController.text.trim(),
        developerName: _analyzedResult!.developerName,
        extractedUseCases: _analyzedResult!.extractedUseCases,
        valueProposition: _analyzedResult!.valueProposition,
        validationChecklist: _analyzedResult!.validationChecklist,
        fieldSources: _analyzedResult!.fieldSources,
        warnings: _analyzedResult!.warnings,
        isLiveListingFound: _analyzedResult!.isLiveListingFound,
      );

      _tabController.animateTo(1); // Jump to Activity tab
      await ref.read(autopilotRunsProvider.notifier).launchAutopilot(scrapedResult: updatedResult);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🚀 Autopilot promotion started for ${updatedApp.name}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = 'Autopilot execution error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  // Builds the interactive, editable profile card generated from the listing
  Widget _buildAnalyzedProfileCard() {
    final result = _analyzedResult!;
    final app = result.app;
    final isLive = result.isLiveListingFound;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  color: AppTheme.primaryIndigo.withOpacity(0.1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: result.localIconPath != null && File(result.localIconPath!).existsSync()
                      ? Image.file(File(result.localIconPath!), fit: BoxFit.cover)
                      : const Icon(Icons.android, size: 36, color: AppTheme.primaryIndigo),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _editNameController,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              labelText: 'App Name (Editable Profile)',
                              isDense: true,
                              border: UnderlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLive ? AppTheme.accentEmerald.withOpacity(0.15) : AppTheme.accentAmber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isLive ? AppTheme.accentEmerald : AppTheme.accentAmber),
                          ),
                          child: Text(
                            isLive ? '✓ Play Store Listing Verified' : '⚠ Template Fallback',
                            style: TextStyle(
                              color: isLive ? AppTheme.accentEmerald : AppTheme.accentAmber,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${app.packageName} • Category: ${app.category}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                        ),
                        if (result.developerName != null)
                          Text(
                            '• Dev: ${result.developerName}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 14),

          // Value Proposition & Audience Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.diamond_outlined, size: 16, color: AppTheme.accentCyan),
                          SizedBox(width: 6),
                          Text('Value Proposition (Synthesized)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.valueProposition,
                        style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.people_outline, size: 16, color: AppTheme.accentAmber),
                              SizedBox(width: 6),
                              Text('Target Audience', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Statistical Estimate', style: TextStyle(fontSize: 10, color: AppTheme.accentAmber)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _editAudienceController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'e.g. Android productivity users',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Core Features Chips (Editable)
          const Text('Extracted Core Features (Click × to remove, or add new):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._editableFeatures.map((f) => Chip(
                    label: Text(f, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppTheme.primaryIndigo.withOpacity(0.12),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _editableFeatures.remove(f)),
                  )),
              SizedBox(
                width: 180,
                height: 36,
                child: TextField(
                  controller: _newFeatureController,
                  decoration: InputDecoration(
                    hintText: '+ Add feature',
                    hintStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () {
                        final val = _newFeatureController.text.trim();
                        if (val.isNotEmpty) {
                          setState(() {
                            _editableFeatures.add(val);
                            _newFeatureController.clear();
                          });
                        }
                      },
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      setState(() {
                        _editableFeatures.add(val.trim());
                        _newFeatureController.clear();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Practical Use Cases
          if (result.extractedUseCases.isNotEmpty) ...[
            const Text('Extracted Practical Use Cases:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.extractedUseCases
                  .map((u) => Chip(
                        avatar: const Icon(Icons.check, size: 14, color: AppTheme.accentEmerald),
                        label: Text(u, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppTheme.accentEmerald.withOpacity(0.1),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Store Screenshots Gallery
          if (result.localScreenshotPaths.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.photo_library_outlined, size: 16, color: AppTheme.primaryIndigo),
                const SizedBox(width: 6),
                Text(
                  'Store Screenshots Retrieved (${result.localScreenshotPaths.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: result.localScreenshotPaths.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, idx) {
                  final shotPath = result.localScreenshotPaths[idx];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 80,
                      color: Colors.black26,
                      child: Image.file(
                        File(shotPath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 20)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Listing Data Integrity Checklist
          const Text('Listing Data Integrity & Safeguards Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: result.validationChecklist.entries.map((e) {
                final source = result.fieldSources[e.key.split(' ').first] ?? 'Public Listing';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        e.value ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: e.value ? AppTheme.accentEmerald : AppTheme.accentAmber,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.key, style: const TextStyle(fontSize: 12)),
                      ),
                      Text(source, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Warnings Box (if any)
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentAmber.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppTheme.accentAmber),
                      SizedBox(width: 6),
                      Text('Listing Clarifications & Estimations:', style: TextStyle(color: AppTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...result.warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('• $w', style: const TextStyle(color: AppTheme.accentAmber, fontSize: 11)),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Clear & Analyze New URL'),
                onPressed: () {
                  setState(() {
                    _analyzedResult = null;
                    _urlOrPackageController.clear();
                  });
                },
              ),
              ElevatedButton.icon(
                icon: _isLaunching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.rocket_launch, size: 18),
                label: Text(_isLaunching ? 'Launching 30-Day Engine...' : 'Confirm Profile & Launch Autopilot'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLaunching ? null : _handleLaunchWithAnalyzedProfile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Action: Launch Autopilot from URL / Package
  Future<void> _handleLaunchAutopilot() async {
    final text = _urlOrPackageController.text.trim();
    if (text.isEmpty) {
      setState(() => _inlineError = 'Please enter a Google Play Store URL or package name.');
      return;
    }

    setState(() {
      _isLaunching = true;
      _inlineError = null;
    });

    try {
      _tabController.animateTo(1); // Jump to Activity tab to watch progress
      await ref.read(autopilotRunsProvider.notifier).launchAutopilot(rawUrlOrPackage: text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚀 Autopilot promotion finished successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = 'Autopilot execution error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  // Action: Launch Autopilot for selected app
  Future<void> _handleLaunchForApp(AppModel app) async {
    setState(() => _isLaunching = true);
    try {
      _tabController.animateTo(1);
      await ref.read(autopilotRunsProvider.notifier).launchAutopilot(existingApp: app);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🚀 Autopilot promotion finished for ${app.name}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Execution error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.accentEmerald;
      case 'running':
        return AppTheme.primaryIndigo;
      case 'paused':
        return AppTheme.accentAmber;
      case 'failed':
        return Colors.redAccent;
      default:
        return AppTheme.darkTextSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'running':
        return Icons.sync;
      case 'paused':
        return Icons.pause_circle_outline;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _PipelineStepCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String description;
  final IconData icon;

  const _PipelineStepCard({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(
                  color: AppTheme.primaryIndigo,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppTheme.primaryIndigo),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppTheme.primaryIndigo),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AutopilotSettingsForm extends StatefulWidget {
  final AutopilotSettingsModel settings;
  final ValueChanged<AutopilotSettingsModel> onSave;

  const _AutopilotSettingsForm({
    required this.settings,
    required this.onSave,
  });

  @override
  State<_AutopilotSettingsForm> createState() => _AutopilotSettingsFormState();
}

class _AutopilotSettingsFormState extends State<_AutopilotSettingsForm> {
  late bool _isAutopilotEnabled;
  late bool _requireApproval;
  late int _dailyLimit;
  late int _weeklyLimit;
  late String _postingTimeUtc;
  late String _aiProvider;
  late TextEditingController _apiKeyController;
  late String _videoFormat;
  late List<String> _platforms;
  late String _timeZone;
  late int _maxRetryAttempts;
  late int _retryDelaySeconds;
  late TextEditingController _targetAudienceController;
  late TextEditingController _contentThemesController;
  late TextEditingController _languagesController;

  static const List<String> _availablePlatforms = [
    'youtube',
    'tiktok',
    'instagram',
    'twitter',
    'linkedin',
    'facebook',
  ];

  @override
  void initState() {
    super.initState();
    _isAutopilotEnabled = widget.settings.isAutopilotEnabled;
    _requireApproval = widget.settings.requireApprovalBeforePublish;
    _dailyLimit = widget.settings.dailyPostLimit;
    _weeklyLimit = widget.settings.weeklyPostLimit;
    _postingTimeUtc = widget.settings.postingTimeUtc;
    _aiProvider = widget.settings.aiProvider;
    _apiKeyController = TextEditingController(text: widget.settings.aiApiKey ?? '');
    _videoFormat = widget.settings.videoFormat;
    _platforms = List<String>.from(widget.settings.targetPlatforms);
    _timeZone = widget.settings.timeZone;
    _maxRetryAttempts = widget.settings.maxRetryAttempts;
    _retryDelaySeconds = widget.settings.retryDelaySeconds;
    _targetAudienceController = TextEditingController(text: widget.settings.targetAudience ?? '');
    _contentThemesController = TextEditingController(text: widget.settings.contentThemes.join(', '));
    _languagesController = TextEditingController(text: widget.settings.contentLanguages.join(', '));
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _targetAudienceController.dispose();
    _contentThemesController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Autonomous Controls & Guardrails',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Autopilot Enabled'),
                  subtitle: const Text('Allows automatic orchestration and background queueing.'),
                  value: _isAutopilotEnabled,
                  activeColor: AppTheme.primaryIndigo,
                  onChanged: (val) => setState(() => _isAutopilotEnabled = val),
                ),
                SwitchListTile(
                  title: const Text('Require Approval Before Publishing'),
                  subtitle: const Text('Hold generated posts as drafts instead of scheduling directly to live queue.'),
                  value: _requireApproval,
                  activeColor: AppTheme.primaryIndigo,
                  onChanged: (val) => setState(() => _requireApproval = val),
                ),
                const Divider(),
                const SizedBox(height: 10),
                const Text('Rate Limits & Scheduling', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Daily Limit', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _dailyLimit,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: [1, 2, 3, 5, 10].map((e) => DropdownMenuItem(value: e, child: Text('$e posts / day'))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _dailyLimit = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Weekly Limit', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _weeklyLimit,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: [7, 14, 21, 35].map((e) => DropdownMenuItem(value: e, child: Text('$e posts / week'))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _weeklyLimit = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Preferred Time (UTC)', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _postingTimeUtc,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: ['09:00', '12:00', '15:00', '18:00', '21:00'].map((e) => DropdownMenuItem(value: e, child: Text('$e UTC'))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _postingTimeUtc = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Time Zone', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: ['UTC', 'Local', 'EST', 'PST', 'GMT', 'CET', 'IST'].contains(_timeZone) ? _timeZone : 'UTC',
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                              DropdownMenuItem(value: 'Local', child: Text('Local Device Time')),
                              DropdownMenuItem(value: 'EST', child: Text('US Eastern (EST)')),
                              DropdownMenuItem(value: 'PST', child: Text('US Pacific (PST)')),
                              DropdownMenuItem(value: 'GMT', child: Text('London (GMT)')),
                              DropdownMenuItem(value: 'CET', child: Text('Central European (CET)')),
                              DropdownMenuItem(value: 'IST', child: Text('India (IST)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _timeZone = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text('Retry & Failure Handling', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Retry Attempts', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _maxRetryAttempts,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: [1, 2, 3, 5, 8].map((e) => DropdownMenuItem(value: e, child: Text('$e attempts'))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _maxRetryAttempts = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Retry Delay (Seconds)', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: [30, 60, 120, 300, 600].contains(_retryDelaySeconds) ? _retryDelaySeconds : 60,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 30, child: Text('30 seconds')),
                              DropdownMenuItem(value: 60, child: Text('60 seconds (1 min)')),
                              DropdownMenuItem(value: 120, child: Text('120 seconds (2 mins)')),
                              DropdownMenuItem(value: 300, child: Text('300 seconds (5 mins)')),
                              DropdownMenuItem(value: 600, child: Text('600 seconds (10 mins)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _retryDelaySeconds = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text('Target Platforms & Publishing Destinations', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text(
                  'Select platforms for content calendar generation and automatic queue dispatch.',
                  style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availablePlatforms.map((p) {
                    final isSelected = _platforms.contains(p);
                    final isYouTube = p == 'youtube';
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.toUpperCase()),
                          if (isYouTube) ...[
                            const SizedBox(width: 4),
                            const Text('(API Ready)', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryIndigo.withOpacity(0.3),
                      checkmarkColor: AppTheme.primaryIndigo,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            if (!_platforms.contains(p)) _platforms.add(p);
                          } else {
                            if (_platforms.length > 1) {
                              _platforms.remove(p);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text('Audience & Content Strategy Themes', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: _targetAudienceController,
                  decoration: const InputDecoration(
                    labelText: 'Target Audience Profile (Optional override)',
                    hintText: 'e.g. Busy professionals, indie developers, fitness enthusiasts',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentThemesController,
                  decoration: const InputDecoration(
                    labelText: 'Content Themes (Comma-separated)',
                    hintText: 'Feature Showcase, Problem & Solution, Quick Tutorials, Tips & Tricks',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _languagesController,
                  decoration: const InputDecoration(
                    labelText: 'Content Languages (Comma-separated ISO codes)',
                    hintText: 'en, es, de, fr',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text('AI & Generation Engine', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text(
                  'No paid subscription required. Template engine works 100% offline. Optionally enter your own API key.',
                  style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _aiProvider,
                        decoration: const InputDecoration(
                          labelText: 'Engine Provider',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'template', child: Text('Local Templates (100% Free & Offline)')),
                          DropdownMenuItem(value: 'gemini', child: Text('Google Gemini (BYO API Key)')),
                          DropdownMenuItem(value: 'openai', child: Text('OpenAI GPT-4o (BYO API Key)')),
                          DropdownMenuItem(value: 'local', child: Text('Local LLM (Ollama / LocalAI)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _aiProvider = val);
                        },
                      ),
                    ),
                    if (_aiProvider == 'gemini' || _aiProvider == 'openai') ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _apiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'API Key (Stored locally in SQLite)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text('Video & Media Formats', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _videoFormat,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'both', child: Text('Both Vertical (9:16) & Landscape (16:9)')),
                    DropdownMenuItem(value: '9:16', child: Text('Vertical Only (9:16 Shorts / Reels / TikTok)')),
                    DropdownMenuItem(value: '16:9', child: Text('Landscape Only (16:9 YouTube / Web)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _videoFormat = val);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save Autopilot Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryIndigo,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final parsedThemes = _contentThemesController.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      final parsedLangs = _languagesController.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();

                      final updated = widget.settings.copyWith(
                        isAutopilotEnabled: _isAutopilotEnabled,
                        requireApprovalBeforePublish: _requireApproval,
                        dailyPostLimit: _dailyLimit,
                        weeklyPostLimit: _weeklyLimit,
                        postingTimeUtc: _postingTimeUtc,
                        aiProvider: _aiProvider,
                        aiApiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
                        videoFormat: _videoFormat,
                        targetPlatforms: _platforms,
                        timeZone: _timeZone,
                        maxRetryAttempts: _maxRetryAttempts,
                        retryDelaySeconds: _retryDelaySeconds,
                        targetAudience: _targetAudienceController.text.trim().isEmpty ? null : _targetAudienceController.text.trim(),
                        contentThemes: parsedThemes.isNotEmpty ? parsedThemes : widget.settings.contentThemes,
                        contentLanguages: parsedLangs.isNotEmpty ? parsedLangs : widget.settings.contentLanguages,
                      );
                      widget.onSave(updated);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
