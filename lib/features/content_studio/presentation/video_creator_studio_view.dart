import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/native_file_dialog_helper.dart';
import '../../../core/utils/url_launcher.dart';
import '../../apps/providers/app_providers.dart';
import '../../autopilot/models/video_project_model.dart';
import '../domain/ffmpeg_service.dart';
import '../domain/storyboard_planner_service.dart';
import '../domain/visual_library_service.dart';
import '../providers/video_creator_providers.dart';

class VideoCreatorStudioView extends ConsumerStatefulWidget {
  const VideoCreatorStudioView({super.key});

  @override
  ConsumerState<VideoCreatorStudioView> createState() => _VideoCreatorStudioViewState();
}

class _VideoCreatorStudioViewState extends ConsumerState<VideoCreatorStudioView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Input states
  final _urlController = TextEditingController();
  final _textPromptController = TextEditingController();
  final List<String> _selectedScreenshots = [];
  final List<String> _selectedClips = [];

  // Configuration options
  String _selectedTemplate = 'feature_showcase';
  String _selectedAspectRatio = '9:16';
  String _selectedResolution = '1080p';
  double _targetDuration = 15.0;
  final String _captionStyle = 'modern';
  final String _transitionStyle = 'fade';
  String? _backgroundMusicPath;
  final double _bgmVolume = 0.2;
  bool _enableVoiceNarration = false;

  // Selected visual library preset
  String _selectedVisualTheme = 'grad_midnight_indigo';
  String _selectedPattern = 'pat_dot_grid';

  // Request counter to ensure delayed async calls never overwrite newer user edits
  int _storyboardRequestId = 0;

  // Persistent controllers per scene ID and field to prevent text loss during tab switching/reordering
  final Map<String, TextEditingController> _sceneControllers = {};

  bool _isAnalyzingUrl = false;
  String? _urlError;
  String? _fetchedAppTitle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _textPromptController.dispose();
    for (final ctrl in _sceneControllers.values) {
      ctrl.dispose();
    }
    _sceneControllers.clear();
    super.dispose();
  }

  TextEditingController _getSceneFieldController(String sceneId, String fieldKey, String initialValue) {
    final key = '${sceneId}_$fieldKey';
    if (!_sceneControllers.containsKey(key)) {
      _sceneControllers[key] = TextEditingController(text: initialValue);
    }
    return _sceneControllers[key]!;
  }

  void _syncSceneControllers(VideoSceneModel scene) {
    _sceneControllers['${scene.id}_title']?.text = scene.sceneTitle;
    _sceneControllers['${scene.id}_onScreen']?.text = scene.onScreenText;
    _sceneControllers['${scene.id}_narration']?.text = scene.voiceOverNarration;
    _sceneControllers['${scene.id}_subtitle']?.text = scene.subtitleText;
    _sceneControllers['${scene.id}_visualDesc']?.text = scene.visualDescription;
    if (scene.callToAction != null) {
      _sceneControllers['${scene.id}_cta']?.text = scene.callToAction!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ffmpegStatusAsync = ref.watch(ffmpegStatusProvider);
    final currentProject = ref.watch(currentVideoProjectProvider);
    final exportState = ref.watch(videoExportStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-Header & Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryIndigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.video_camera_back_outlined, color: AppTheme.primaryIndigo, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Multi-Input Video Creator & Storyboard Studio',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        currentProject != null
                            ? 'Active Project: ${currentProject.title} (${currentProject.aspectRatio}, ${currentProject.scenes.length} scenes)'
                            : 'Mix any inputs: App URL, screenshots, video clips, text, and built-in visual library.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                      ),
                    ],
                  ),
                ],
              ),

              // FFmpeg Status Badge
              ffmpegStatusAsync.when(
                data: (status) {
                  return InkWell(
                    onTap: () => _showFfmpegInfoDialog(context, status),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: status.isAvailable
                            ? AppTheme.accentEmerald.withOpacity(0.15)
                            : AppTheme.accentAmber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: status.isAvailable
                              ? AppTheme.accentEmerald.withOpacity(0.4)
                              : AppTheme.accentAmber.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status.isAvailable ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                            size: 14,
                            color: status.isAvailable ? AppTheme.accentEmerald : AppTheme.accentAmber,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.isAvailable ? 'FFmpeg Ready' : 'FFmpeg Not Detected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: status.isAvailable ? AppTheme.accentEmerald : AppTheme.accentAmber,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.info_outline, size: 12, color: AppTheme.darkTextSecondary),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // Studio Navigation Tabs
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryIndigo,
          indicatorColor: AppTheme.primaryIndigo,
          tabs: [
            const Tab(icon: Icon(Icons.tune, size: 18), text: '1. Select Inputs & Media'),
            Tab(
              icon: const Icon(Icons.view_timeline_outlined, size: 18),
              text: currentProject != null ? '2. Storyboard (${currentProject.scenes.length} Scenes)' : '2. Storyboard Editor',
            ),
            Tab(
              icon: const Icon(Icons.file_download_outlined, size: 18),
              text: exportState.isRendering ? '3. Rendering Video...' : '3. Render & Local Export',
            ),
            const Tab(icon: Icon(Icons.video_library_outlined, size: 18), text: 'Saved Video Projects'),
          ],
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInputsStage(),
              _buildStoryboardStage(),
              _buildExportStage(),
              _buildSavedProjectsStage(),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STAGE 1: MULTI-INPUT & MEDIA SELECTOR
  // ==========================================
  Widget _buildInputsStage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Any Single Input or Combine Any Multiple Inputs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'You are not forced to supply all inputs. A complete promotional video can be synthesized from only a URL, only screenshots, only clips, or only text prompt.',
            style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
          ),
          const SizedBox(height: 16),

          // Multi-Input Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildUrlInputCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildScreenshotsCard()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildVideoClipsCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildTextInputCard()),
            ],
          ),
          const SizedBox(height: 16),

          // Dedicated Visual Sources Panel (Part C)
          _buildVisualSourcesPanel(),
          const SizedBox(height: 20),

          // Video Template & Styling Settings Card
          _buildConfigurationCard(),
          const SizedBox(height: 24),

          // Primary Action: Generate Storyboard
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Promotional Storyboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _handleGenerateStoryboard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.link, color: Colors.blueAccent, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('Input A: Google Play Store URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Extracts app title, category, description, and store screenshots automatically.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'https://play.google.com/store/apps/details?id=com.example.app',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _isAnalyzingUrl
                  ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(icon: const Icon(Icons.search, size: 20), tooltip: 'Quick inspect URL', onPressed: _handleAnalyzeUrl),
            ),
          ),
          if (_urlError != null) ...[
            const SizedBox(height: 6),
            Text(_urlError!, style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
          ],
          if (_fetchedAppTitle != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: AppTheme.accentEmerald),
                const SizedBox(width: 4),
                Expanded(child: Text('Detected: $_fetchedAppTitle', style: const TextStyle(fontSize: 12, color: AppTheme.accentEmerald, fontWeight: FontWeight.bold))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScreenshotsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.photo_library_outlined, color: Colors.purpleAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text('Input B: Screenshots (${_selectedScreenshots.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 14),
                label: const Text('Add Images', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: _handlePickScreenshots,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Pick 1 to 10 local screenshots to feature inside promotional scenes.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 12),
          if (_selectedScreenshots.isEmpty)
            Container(
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Theme.of(context).canvasColor, borderRadius: BorderRadius.circular(8)),
              child: const Text('No images added. Click "+ Add Images" to select.', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
            )
          else
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedScreenshots.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final path = _selectedScreenshots[idx];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(path), width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedScreenshots.removeAt(idx)),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoClipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.movie_outlined, color: Colors.amberAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text('Input C: Video Footage (${_selectedClips.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.video_call_outlined, size: 14),
                label: const Text('Add Clips', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: _handlePickClips,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Import existing MP4/MOV footage with custom start/end trimming.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 12),
          if (_selectedClips.isEmpty)
            Container(
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Theme.of(context).canvasColor, borderRadius: BorderRadius.circular(8)),
              child: const Text('No video footage added. Click "+ Add Clips" to import.', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
            )
          else
            Column(
              children: _selectedClips.asMap().entries.map((entry) {
                final idx = entry.key;
                final clip = entry.value;
                final name = p.basename(clip);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam, size: 16, color: Colors.amberAccent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        onPressed: () => setState(() => _selectedClips.removeAt(idx)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTextInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.edit_note, color: Colors.tealAccent, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('Input D: Text & Feature Prompt (Immutable Source)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Your exact message is preserved and converted into scene narration and captions.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _textPromptController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g., HabitForge is a clean habit tracker. Build streaks, stay focused with pomodoro timers, and reach your goals. Download free today!',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  // Dedicated Visual Sources Panel (Part C)
  Widget _buildVisualSourcesPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.palette_outlined, color: Colors.cyanAccent, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('Visual Sources & Built-in Creative Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.accentEmerald.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: const Text('100% Offline & Royalty-Free', style: TextStyle(fontSize: 11, color: AppTheme.accentEmerald, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'AppGrowth Studio automatically synthesizes high-definition backgrounds, procedural geometric compositions, and domain icons when screenshots are not provided.',
            style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
          ),
          const SizedBox(height: 14),

          // Gradient Presets Swatches
          const Text('Procedural Background Gradients:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VisualLibraryService.builtInGradients.map((g) {
              final isSelected = _selectedVisualTheme == g.id;
              return InkWell(
                onTap: () => setState(() => _selectedVisualTheme = g.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: g.gradientColors),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) const Icon(Icons.check, size: 12, color: Colors.white),
                      if (isSelected) const SizedBox(width: 4),
                      Text(g.title, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Geometric Pattern Selectors
          const Text('Procedural Motion & Shape Patterns:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VisualLibraryService.builtInPatterns.map((p) {
              final isSelected = _selectedPattern == p.id;
              return ChoiceChip(
                label: Text(p.title, style: const TextStyle(fontSize: 11)),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _selectedPattern = p.id);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // App Domain Icons Showcase
          const Text('Built-in Vector Domain Icons:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: VisualLibraryService.builtInIcons.take(6).map((ico) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(ico.iconData, size: 16, color: AppTheme.primaryIndigo),
                  const SizedBox(width: 4),
                  Text(ico.title, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Video Format, Template & Audio Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<String>(
                  value: _selectedTemplate,
                  decoration: const InputDecoration(labelText: 'Template Archetype', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'feature_showcase', child: Text('App Feature Showcase')),
                    DropdownMenuItem(value: 'problem_solution', child: Text('Problem & Solution')),
                    DropdownMenuItem(value: 'quick_tutorial', child: Text('App Tutorial')),
                    DropdownMenuItem(value: 'launch_announcement', child: Text('Launch Announcement')),
                    DropdownMenuItem(value: 'before_after', child: Text('Before & After Demo')),
                    DropdownMenuItem(value: 'installation_guide', child: Text('App Installation Guide')),
                    DropdownMenuItem(value: 'promotional_slideshow', child: Text('Promotional Slideshow')),
                    DropdownMenuItem(value: 'existing_video_enhancement', child: Text('Video Enhancement')),
                    DropdownMenuItem(value: 'text_to_video', child: Text('Text-to-Video Promo')),
                  ],
                  onChanged: (val) => setState(() => _selectedTemplate = val ?? _selectedTemplate),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedAspectRatio,
                  decoration: const InputDecoration(labelText: 'Aspect Ratio', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '9:16', child: Text('Vertical 9:16 (Shorts/Reels/TikTok)')),
                    DropdownMenuItem(value: '16:9', child: Text('Landscape 16:9 (YouTube/Web)')),
                    DropdownMenuItem(value: '1:1', child: Text('Square 1:1 (Social Feed)')),
                  ],
                  onChanged: (val) => setState(() => _selectedAspectRatio = val ?? _selectedAspectRatio),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedResolution,
                  decoration: const InputDecoration(labelText: 'Resolution', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '1080p', child: Text('1080p (Full HD)')),
                    DropdownMenuItem(value: '720p', child: Text('720p (HD)')),
                  ],
                  onChanged: (val) => setState(() => _selectedResolution = val ?? _selectedResolution),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<double>(
                  value: _targetDuration,
                  decoration: const InputDecoration(labelText: 'Duration Target', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 15.0, child: Text('15 Seconds')),
                    DropdownMenuItem(value: 30.0, child: Text('30 Seconds')),
                    DropdownMenuItem(value: 60.0, child: Text('60 Seconds')),
                  ],
                  onChanged: (val) => setState(() => _targetDuration = val ?? _targetDuration),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.music_note, size: 16),
                  label: Text(
                    _backgroundMusicPath != null
                        ? 'BGM: ${p.basename(_backgroundMusicPath!)}'
                        : 'Add Background Music (MP3/WAV)',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _handlePickBgm,
                ),
              ),
              if (_backgroundMusicPath != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _backgroundMusicPath = null),
                ),
              ],
              const SizedBox(width: 20),
              Row(
                children: [
                  Checkbox(
                    value: _enableVoiceNarration,
                    onChanged: (v) => setState(() => _enableVoiceNarration = v ?? false),
                  ),
                  const Text('Enable Voice Narration (when engine configured)', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STAGE 2: INTERACTIVE STORYBOARD EDITOR (Part B)
  // ==========================================
  Widget _buildStoryboardStage() {
    final project = ref.watch(currentVideoProjectProvider);
    if (project == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.view_timeline_outlined, size: 64, color: AppTheme.darkTextSecondary),
            const SizedBox(height: 16),
            const Text('No Active Storyboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Supply your inputs in Stage 1 and click "Generate Storyboard" to create one.', style: TextStyle(color: AppTheme.darkTextSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Go to Stage 1'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Storyboard Draft: Edit text, change visual assets, or reorder scenes. Each text field is stored independently and preserved across tab switches and exports.',
                    style: TextStyle(fontSize: 12, color: Colors.amberAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Project Details Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${project.title} (${project.scenes.length} Scenes, ~${project.totalDurationSeconds.toInt()}s)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Scene'),
                    onPressed: _handleAddScene,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save to Library'),
                    onPressed: () async {
                      await ref.read(videoProjectsListProvider.notifier).saveProject(project);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✓ Video project saved to SQLite library.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.movie_filter_outlined, size: 16),
                    label: const Text('Proceed to Render'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo, foregroundColor: Colors.white),
                    onPressed: () => _tabController.animateTo(2),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scene Cards List with stable Keys
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: project.scenes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final scene = project.scenes[index];
              return _buildSceneCard(scene, index, project);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSceneCard(VideoSceneModel scene, int index, VideoProjectModel project) {
    // Dedicated persistent controllers keyed by scene.id and field
    final titleCtrl = _getSceneFieldController(scene.id, 'title', scene.sceneTitle);
    final onScreenCtrl = _getSceneFieldController(scene.id, 'onScreen', scene.onScreenText);
    final narrationCtrl = _getSceneFieldController(scene.id, 'narration', scene.voiceOverNarration);
    final subtitleCtrl = _getSceneFieldController(scene.id, 'subtitle', scene.subtitleText);

    return Container(
      key: ValueKey(scene.id),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primaryIndigo.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text('Scene ${index + 1} • ${scene.badgeText}', style: const TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Text('Duration: ${scene.durationSeconds}s', style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                ],
              ),
              Row(
                children: [
                  if (index > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      tooltip: 'Move Up',
                      onPressed: () => _moveScene(index, -1),
                    ),
                  if (index < project.scenes.length - 1)
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      tooltip: 'Move Down',
                      onPressed: () => _moveScene(index, 1),
                    ),

                  // Granular Regeneration Menu (Part B.4)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Regeneration Options',
                    onSelected: (val) {
                      switch (val) {
                        case 'visual_only':
                          _regenerateVisualOnly(index);
                          break;
                        case 'narration_only':
                          _regenerateNarrationOnly(index);
                          break;
                        case 'captions_only':
                          _regenerateCaptionsOnly(index);
                          break;
                        case 'full_scene':
                          _regenerateScene(index);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'visual_only',
                        child: Row(
                          children: [
                            Icon(Icons.image_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Regenerate Visual Only (Preserves All Text)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'narration_only',
                        child: Row(
                          children: [
                            Icon(Icons.record_voice_over_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Regenerate Narration Only'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'captions_only',
                        child: Row(
                          children: [
                            Icon(Icons.closed_caption_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Regenerate Captions Only'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'full_scene',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 16),
                            SizedBox(width: 8),
                            Text('Regenerate Full Scene'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    tooltip: 'Delete Scene',
                    onPressed: () => _deleteScene(index),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual Asset Preview
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: scene.imageAssetPath != null && File(scene.imageAssetPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(scene.imageAssetPath!), fit: BoxFit.cover),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(scene.videoClipPath != null ? Icons.movie : Icons.auto_awesome, size: 28, color: AppTheme.primaryIndigo),
                              const SizedBox(height: 4),
                              const Text('Procedural Graphic', style: TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary)),
                              Text(scene.visualDescription, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),

              // Fully Separated Independent Text Fields (Part B.1)
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Scene Title', isDense: true, border: OutlineInputBorder()),
                      onChanged: (val) => _updateSceneField(scene.id, title: val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: onScreenCtrl,
                      decoration: const InputDecoration(labelText: 'On-Screen Headline Overlay', isDense: true, border: OutlineInputBorder()),
                      onChanged: (val) => _updateSceneField(scene.id, onScreenText: val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: narrationCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Voiceover Narration Script', isDense: true, border: OutlineInputBorder()),
                      onChanged: (val) => _updateSceneField(scene.id, narration: val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: subtitleCtrl,
                      decoration: const InputDecoration(labelText: 'Timed Subtitle Text', isDense: true, border: OutlineInputBorder()),
                      onChanged: (val) => _updateSceneField(scene.id, subtitle: val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STAGE 3: RENDER & LOCAL EXPORT (Part A)
  // ==========================================
  Widget _buildExportStage() {
    final project = ref.watch(currentVideoProjectProvider);
    final exportState = ref.watch(videoExportStateProvider);

    if (project == null) {
      return const Center(child: Text('Please generate or select a video project first.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Render & Export Video to Computer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Compile a genuine, playable H.264 / AAC MP4 video file directly to your local computer.', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 20),

          // Render Progress Indicator if active
          if (exportState.isRendering) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(exportState.statusMessage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${(exportState.progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: exportState.progress, minHeight: 8, color: AppTheme.primaryIndigo),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Render Status & Result Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          'Template: ${project.templateType} • ${project.aspectRatio} (${project.resolution}) • ${project.scenes.length} Scenes (~${project.totalDurationSeconds.toInt()}s)',
                          style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_circle_fill, size: 18),
                      label: const Text('Render Video'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo, foregroundColor: Colors.white),
                      onPressed: exportState.isRendering ? null : _handleRenderVideo,
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Granular Output Status Displays (Part A.4)
                if (exportState.result != null) ...[
                  if (exportState.result!.success && exportState.result!.mp4FilePath != null) ...[
                    // Success: Verified Playable MP4
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accentEmerald.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: AppTheme.accentEmerald, size: 20),
                              SizedBox(width: 8),
                              Text('✓ Playable MP4 Video Encoded Successfully!', style: TextStyle(color: AppTheme.accentEmerald, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Resolution: ${exportState.result!.videoWidth ?? 1080}x${exportState.result!.videoHeight ?? 1920} • Duration: ${(exportState.result!.durationSeconds ?? project.totalDurationSeconds).toStringAsFixed(1)}s • Size: ${((exportState.result!.fileSizeBytes ?? 0) / (1024 * 1024)).toStringAsFixed(2)} MB',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            'Location: ${exportState.result!.mp4FilePath}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Deliverable Actions
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt, size: 18),
                          label: const Text('Export Video to Computer...'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentEmerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          onPressed: _handleSaveVideoToComputer,
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Play Video in Default Player'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                          onPressed: () => AppUrlLauncher.openUrl('file://${exportState.result!.mp4FilePath!}'),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Open Export Folder'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                          onPressed: () => NativeFileDialogHelper.openDirectory(exportState.result!.exportDirectoryPath),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_browser, size: 18),
                          label: const Text('Interactive Storyboard Player (HTML5)'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                          onPressed: () => AppUrlLauncher.openUrl(exportState.result!.htmlPreviewPath),
                        ),
                      ],
                    ),
                  ] else if (exportState.result!.renderingPhaseStatus == 'framesGenerated') ...[
                    // Notice: Frames ready but FFmpeg missing
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber, color: AppTheme.accentAmber, size: 20),
                              SizedBox(width: 8),
                              Text('Canvas Frames & Batch Compiler Ready (FFmpeg Missing)', style: TextStyle(color: AppTheme.accentAmber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            exportState.result!.errorMessage ?? 'FFmpeg was not detected. Slide frames were generated, but video could not be encoded.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Open Export Folder (Run render_mp4.bat)'),
                          onPressed: () => NativeFileDialogHelper.openDirectory(exportState.result!.exportDirectoryPath),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_browser, size: 18),
                          label: const Text('Preview in HTML5 Player'),
                          onPressed: () => AppUrlLauncher.openUrl(exportState.result!.htmlPreviewPath),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Failed
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Render Failed: ${exportState.result!.errorMessage ?? "Unknown encoder error"}',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STAGE 4: SAVED PROJECTS LIBRARY
  // ==========================================
  Widget _buildSavedProjectsStage() {
    final listAsync = ref.watch(videoProjectsListProvider);

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading projects: $e')),
      data: (projects) {
        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.video_library_outlined, size: 64, color: AppTheme.darkTextSecondary),
                const SizedBox(height: 16),
                const Text('No Saved Video Projects Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Created projects saved to SQLite will appear here for reopening anytime.', style: TextStyle(color: AppTheme.darkTextSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: projects.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final proj = projects[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: AppTheme.primaryIndigo.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.movie, color: AppTheme.primaryIndigo),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(proj.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          '${proj.scenes.length} Scenes • ${proj.aspectRatio} (${proj.resolution}) • Status: ${proj.renderingPhaseStatus}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(currentVideoProjectProvider.notifier).state = proj;
                      for (final s in proj.scenes) {
                        _syncSceneControllers(s);
                      }
                      _tabController.animateTo(1);
                    },
                    child: const Text('Open Storyboard'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    onPressed: () => ref.read(videoProjectsListProvider.notifier).deleteProject(proj.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ACTION HANDLERS
  // ==========================================
  Future<void> _handleAnalyzeUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _isAnalyzingUrl = true;
      _urlError = null;
      _fetchedAppTitle = null;
    });

    try {
      final planner = ref.read(storyboardPlannerServiceProvider);
      final testInput = StoryboardPlanInput(appUrl: url);
      final dummy = await planner.planStoryboard(testInput);
      setState(() {
        _fetchedAppTitle = dummy.title.split(' - ').firstOrNull ?? 'Valid App Found';
      });
    } catch (e) {
      setState(() {
        _urlError = 'Could not inspect app listing: $e';
      });
    } finally {
      setState(() => _isAnalyzingUrl = false);
    }
  }

  Future<void> _handlePickScreenshots() async {
    final paths = await NativeFileDialogHelper.pickFiles(
      title: 'Select App Screenshots',
      filter: 'Images (*.png;*.jpg;*.jpeg;*.webp)|*.png;*.jpg;*.jpeg;*.webp|All Files (*.*)|*.*',
      allowMultiple: true,
    );
    if (paths.isNotEmpty) {
      setState(() {
        for (final p in paths) {
          if (!_selectedScreenshots.contains(p)) _selectedScreenshots.add(p);
        }
      });
    }
  }

  Future<void> _handlePickClips() async {
    final paths = await NativeFileDialogHelper.pickFiles(
      title: 'Select Video Clips',
      filter: 'Videos (*.mp4;*.mov;*.mkv)|*.mp4;*.mov;*.mkv|All Files (*.*)|*.*',
      allowMultiple: true,
    );
    if (paths.isNotEmpty) {
      setState(() {
        for (final p in paths) {
          if (!_selectedClips.contains(p)) _selectedClips.add(p);
        }
      });
    }
  }

  Future<void> _handlePickBgm() async {
    final paths = await NativeFileDialogHelper.pickFiles(
      title: 'Select Background Music File',
      filter: 'Audio Files (*.mp3;*.wav;*.m4a)|*.mp3;*.wav;*.m4a|All Files (*.*)|*.*',
      allowMultiple: false,
    );
    if (paths.isNotEmpty) {
      setState(() => _backgroundMusicPath = paths.first);
    }
  }

  Future<void> _handleGenerateStoryboard() async {
    final currentProject = ref.read(currentVideoProjectProvider);
    if (currentProject != null && currentProject.scenes.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerate Entire Storyboard?'),
          content: const Text('Warning: Regenerating the whole storyboard will create new scenes and replace existing custom scene edits. Do you wish to proceed?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerate All'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!mounted) return;
    }

    final selectedApp = ref.read(selectedAppProvider);
    final input = StoryboardPlanInput(
      appUrl: _urlController.text.trim().isNotEmpty ? _urlController.text.trim() : null,
      screenshotPaths: _selectedScreenshots,
      videoClipPaths: _selectedClips,
      textPrompt: _textPromptController.text.trim().isNotEmpty ? _textPromptController.text.trim() : null,
      selectedApp: selectedApp,
      templateType: _selectedTemplate,
      aspectRatio: _selectedAspectRatio,
      resolution: _selectedResolution,
      targetDurationSeconds: _targetDuration,
      captionStyle: _captionStyle,
      transitionStyle: _transitionStyle,
      backgroundMusicPath: _backgroundMusicPath,
      backgroundMusicVolume: _bgmVolume,
      enableVoiceNarration: _enableVoiceNarration,
    );

    if (!input.hasAnyInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least one input: App URL, screenshots, video clips, or text prompt.')),
      );
      return;
    }

    final reqId = ++_storyboardRequestId;

    try {
      final planner = ref.read(storyboardPlannerServiceProvider);
      final project = await planner.planStoryboard(input);

      // Protect against stale async response
      if (reqId != _storyboardRequestId || !mounted) return;

      ref.read(currentVideoProjectProvider.notifier).state = project;
      for (final s in project.scenes) {
        _syncSceneControllers(s);
      }

      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Storyboard created with ${project.scenes.length} scenes!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error planning storyboard: $e')),
      );
    }
  }

  void _moveScene(int index, int delta) {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;
    final scenes = List<VideoSceneModel>.from(project.scenes);
    final target = index + delta;
    if (target < 0 || target >= scenes.length) return;
    final item = scenes.removeAt(index);
    scenes.insert(target, item);
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  void _deleteScene(int index) {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null || project.scenes.length <= 1) return;
    final scenes = List<VideoSceneModel>.from(project.scenes)..removeAt(index);
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  void _regenerateScene(int index) {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;
    final planner = ref.read(storyboardPlannerServiceProvider);
    final newScene = planner.regenerateScene(project: project, sceneIndex: index);
    final scenes = List<VideoSceneModel>.from(project.scenes);
    scenes[index] = newScene;
    _syncSceneControllers(newScene);
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  void _regenerateVisualOnly(int index) {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;
    final planner = ref.read(storyboardPlannerServiceProvider);
    final newScene = planner.regenerateVisualOnly(project: project, sceneIndex: index);
    final scenes = List<VideoSceneModel>.from(project.scenes);
    scenes[index] = newScene;
    _syncSceneControllers(newScene);
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  void _regenerateNarrationOnly(int index) {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;
    final planner = ref.read(storyboardPlannerServiceProvider);
    final newScene = planner.regenerateNarrationOnly(project: project, sceneIndex: index);
    final scenes = List<VideoSceneModel>.from(project.scenes);
    scenes[index] = newScene;
    _syncSceneControllers(newScene);
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  void _regenerateCaptionsOnly(int index) {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;
    final planner = ref.read(storyboardPlannerServiceProvider);
    final newScene = planner.regenerateCaptionsOnly(project: project, sceneIndex: index);
    final scenes = List<VideoSceneModel>.from(project.scenes);
    scenes[index] = newScene;
    _syncSceneControllers(newScene);
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  void _updateSceneField(
    String sceneId, {
    String? title,
    String? onScreenText,
    String? narration,
    String? subtitle,
    String? visualDescription,
    String? callToAction,
  }) {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;
    final scenes = List<VideoSceneModel>.from(project.scenes);
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx == -1) return;
    final old = scenes[idx];
    scenes[idx] = old.copyWith(
      sceneTitle: title ?? old.sceneTitle,
      onScreenText: onScreenText ?? old.onScreenText,
      voiceOverNarration: narration ?? old.voiceOverNarration,
      subtitleText: subtitle ?? old.subtitleText,
      visualDescription: visualDescription ?? old.visualDescription,
      callToAction: callToAction ?? old.callToAction,
    );
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  void _handleAddScene() {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;
    final scenes = List<VideoSceneModel>.from(project.scenes);
    final newScene = VideoSceneModel(
      sceneNumber: scenes.length + 1,
      sceneTitle: 'New Feature Highlight',
      onScreenText: 'Intuitive & Fast Controls',
      voiceOverNarration: 'Check out another exciting feature that makes daily tasks effortless.',
      subtitleText: 'Check out another exciting feature that makes daily tasks effortless.',
      visualDescription: 'Clean feature demonstration slide',
      durationSeconds: 4.0,
      badgeText: 'Feature',
    );
    scenes.add(newScene);
    _syncSceneControllers(newScene);
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  Future<void> _handleRenderVideo() async {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;

    ref.read(videoExportStateProvider.notifier).state = const VideoExportState(
      isRendering: true,
      progress: 0.1,
      statusMessage: 'Rendering scene slides via Flutter Canvas...',
    );

    try {
      final exporter = ref.read(videoProjectExporterProvider);
      final selectedApp = ref.read(selectedAppProvider);

      final result = await exporter.exportProject(
        project: project,
        app: selectedApp,
        onProgress: (p) {
          ref.read(videoExportStateProvider.notifier).state = VideoExportState(
            isRendering: p.progressPercent < 1.0,
            progress: p.progressPercent,
            statusMessage: p.currentPhase,
          );
        },
      );

      ref.read(videoExportStateProvider.notifier).state = VideoExportState(
        isRendering: false,
        progress: 1.0,
        statusMessage: result.success ? 'Render Complete' : 'Render Issue: ${result.renderingPhaseStatus}',
        result: result,
      );

      // Save updated project state to SQLite
      final updatedProject = project.copyWith(
        exportStatus: result.success && result.mp4FilePath != null ? 'rendered' : 'draft',
        exportedFilePath: result.mp4FilePath,
        fileSizeBytes: result.fileSizeBytes,
        renderingPhaseStatus: result.renderingPhaseStatus,
      );
      ref.read(currentVideoProjectProvider.notifier).state = updatedProject;
      await ref.read(videoProjectsListProvider.notifier).saveProject(updatedProject);
    } catch (e) {
      ref.read(videoExportStateProvider.notifier).state = VideoExportState(
        isRendering: false,
        progress: 0.0,
        statusMessage: 'Failed: $e',
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _handleSaveVideoToComputer() async {
    final exportState = ref.read(videoExportStateProvider);
    final result = exportState.result;
    final project = ref.read(currentVideoProjectProvider);
    if (result == null || project == null) return;

    if (result.mp4FilePath == null || !File(result.mp4FilePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playable MP4 has been compiled yet. Please click "Render Video" first.')),
      );
      return;
    }

    final defaultFolder = await ref.read(defaultExportFolderProvider.future);
    final sanitizedTitle = project.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final defaultName = '${sanitizedTitle}_${project.aspectRatio.replaceAll(':', 'x')}.mp4';

    final savePath = await NativeFileDialogHelper.saveFile(
      title: 'Export Playable MP4 Video',
      defaultFileName: defaultName,
      filter: 'MP4 Video (*.mp4)|*.mp4|All Files (*.*)|*.*',
      initialDirectory: defaultFolder,
    );

    if (savePath != null && savePath.isNotEmpty) {
      final exporter = ref.read(videoProjectExporterProvider);
      final exportRes = await exporter.exportToLocalDestination(
        project: project,
        destinationFilePath: savePath,
      );

      if (exportRes.success) {
        final updatedProject = project.copyWith(
          exportStatus: 'exported',
          exportedFilePath: savePath,
          fileSizeBytes: exportRes.fileSizeBytes,
          renderingPhaseStatus: 'exported',
        );
        ref.read(currentVideoProjectProvider.notifier).state = updatedProject;
        await ref.read(videoProjectsListProvider.notifier).saveProject(updatedProject);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Verified playable MP4 exported: $savePath'),
              action: SnackBarAction(
                label: 'Open Folder',
                onPressed: () => NativeFileDialogHelper.openDirectory(File(savePath).parent.path),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: ${exportRes.errorMessage}')),
          );
        }
      }
    }
  }

  void _showFfmpegInfoDialog(BuildContext context, FfmpegStatus status) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              status.isAvailable ? Icons.check_circle : Icons.warning_amber,
              color: status.isAvailable ? AppTheme.accentEmerald : AppTheme.accentAmber,
            ),
            const SizedBox(width: 10),
            Text(status.isAvailable ? 'FFmpeg Ready' : 'FFmpeg Setup Guide'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status.isAvailable) ...[
                Text('Detected Binary: ${status.executablePath}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Text('Version: ${status.versionInfo}', style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
              ] else ...[
                SelectableText(status.setupInstructions),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
