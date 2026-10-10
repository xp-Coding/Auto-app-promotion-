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

  String _selectedTemplate = 'feature_showcase';
  String _selectedAspectRatio = '9:16';
  String _selectedResolution = '1080p';
  double _targetDuration = 15.0;
  final String _captionStyle = 'modern';
  final String _transitionStyle = 'fade';
  String? _backgroundMusicPath;
  final double _bgmVolume = 0.2;
  bool _enableVoiceNarration = false;

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
    super.dispose();
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
                          : 'Mix any inputs: App URL, local screenshots, video clips, and text descriptions.',
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

          // 4 Multi-Input Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card A: App URL
              Expanded(child: _buildUrlInputCard()),
              const SizedBox(width: 16),
              // Card B: Screenshots & Images
              Expanded(child: _buildScreenshotsCard()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card C: Existing Video Clips
              Expanded(child: _buildVideoClipsCard()),
              const SizedBox(width: 16),
              // Card D: Text Input & Promotion Message
              Expanded(child: _buildTextInputCard()),
            ],
          ),
          const SizedBox(height: 20),

          // Video Template & Styling Settings Card
          _buildConfigurationCard(),
          const SizedBox(height: 24),

          // Primary Action: Generate Storyboard
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text(
                'Generate Storyboard & Plan Video Scenes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
              const Text('Input A: App URL (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Google Play Store URL or package name to extract live app listing data.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'https://play.google.com/store/apps/details?id=...',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: _isAnalyzingUrl
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(
                      icon: const Icon(Icons.download, size: 18),
                      tooltip: 'Analyze URL',
                      onPressed: _handleAnalyzeUrl,
                    ),
            ),
          ),
          if (_urlError != null) ...[
            const SizedBox(height: 6),
            Text(_urlError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
          if (_fetchedAppTitle != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.accentEmerald.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('✓ Loaded: $_fetchedAppTitle', style: const TextStyle(color: AppTheme.accentEmerald, fontSize: 11, fontWeight: FontWeight.bold)),
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
          const Text('Select local PNG, JPG images. Used as genuine visual content without distortion.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 12),
          if (_selectedScreenshots.isEmpty)
            Container(
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Theme.of(context).canvasColor, borderRadius: BorderRadius.circular(8)),
              child: const Text('No images added yet. Click "+ Add Images" to select.', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
            )
          else
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedScreenshots.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = _selectedScreenshots[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(path),
                          width: 60,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(width: 60, color: Colors.grey, child: const Icon(Icons.broken_image)),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedScreenshots.removeAt(index)),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
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
              const Text('Input D: Text & Feature Prompt (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Describe features, audience, and benefits to convert into scripted scenes.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _textPromptController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g., TaskMaster is a fast Pomodoro productivity timer with cloud sync and dark mode...',
              border: OutlineInputBorder(),
            ),
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
          const Text('Video Format, Template & Styling Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              // Template Selector
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

              // Aspect Ratio
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

              // Resolution
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

              // Duration
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

          // Audio & Caption controls
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
  // STAGE 2: INTERACTIVE STORYBOARD EDITOR
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
          // Banner clearly distinguishing storyboard draft from finished video
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
                    'Storyboard Draft: Edit text, change visual assets, and reorder scenes. Click "Render Video" in Stage 3 when ready to compile.',
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

          // Scene Cards List
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
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Regenerate Scene',
                    onPressed: () => _regenerateScene(index),
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
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: scene.imageAssetPath != null && File(scene.imageAssetPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(scene.imageAssetPath!), fit: BoxFit.cover),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(scene.videoClipPath != null ? Icons.movie : Icons.image, size: 28, color: AppTheme.darkTextSecondary),
                            const SizedBox(height: 4),
                            const Text('Canvas Card', style: TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary)),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 16),

              // Editable Scene Fields
              Expanded(
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: scene.title,
                      decoration: const InputDecoration(labelText: 'Scene Title', isDense: true, border: OutlineInputBorder()),
                      onChanged: (val) => _updateSceneField(index, title: val),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: scene.narrationText,
                      decoration: const InputDecoration(labelText: 'Voiceover Narration Script', isDense: true, border: OutlineInputBorder()),
                      onChanged: (val) => _updateSceneField(index, narration: val),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: scene.captionText ?? '',
                      decoration: const InputDecoration(labelText: 'Readable Caption Overlay', isDense: true, border: OutlineInputBorder()),
                      onChanged: (val) => _updateSceneField(index, caption: val),
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
  // STAGE 3: RENDER & LOCAL EXPORT
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
          const Text('Save a real, playable MP4 file to any folder on your PC without needing social media accounts.', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
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

                // Deliverable actions when rendered
                if (exportState.result != null && exportState.result!.success) ...[
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
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.accentEmerald, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              exportState.result!.mp4FilePath != null
                                  ? '✓ Video Rendered Successfully as Playable MP4!'
                                  : '✓ Video Package Rendered! (Canvas frames & batch compiler ready)',
                              style: const TextStyle(color: AppTheme.accentEmerald, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (exportState.result!.fileSizeBytes != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Output Size: ${(exportState.result!.fileSizeBytes! / (1024 * 1024)).toStringAsFixed(2)} MB • Path: ${exportState.result!.mp4FilePath ?? exportState.result!.exportDirectoryPath}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mandatory Export Buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // Save Video to Computer Button
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

                      // Open Export Folder Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Open Export Folder'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                        onPressed: () => NativeFileDialogHelper.openDirectory(exportState.result!.exportDirectoryPath),
                      ),

                      // Interactive HTML5 Preview Player Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: const Text('Open Interactive Preview Player'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                        onPressed: () => AppUrlLauncher.openUrl(exportState.result!.htmlPreviewPath),
                      ),
                    ],
                  ),
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
            final p = projects[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'Template: ${p.templateType} • ${p.aspectRatio} (${p.resolution}) • ${p.scenes.length} Scenes • Status: ${p.exportStatus.toUpperCase()}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Open Project'),
                        onPressed: () {
                          ref.read(currentVideoProjectProvider.notifier).state = p;
                          _tabController.animateTo(1);
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        onPressed: () => ref.read(videoProjectsListProvider.notifier).deleteProject(p.id),
                      ),
                    ],
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
    final text = _urlController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isAnalyzingUrl = true;
      _urlError = null;
    });

    try {
      final scraper = ref.read(storyboardPlannerServiceProvider);
      final input = StoryboardPlanInput(appUrl: text);
      final project = await scraper.planStoryboard(input);
      setState(() {
        _fetchedAppTitle = project.title;
      });
    } catch (e) {
      setState(() => _urlError = 'Could not access URL: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingUrl = false);
    }
  }

  Future<void> _handlePickScreenshots() async {
    final paths = await NativeFileDialogHelper.pickFiles(
      title: 'Select App Screenshots or Images',
      filter: 'Image Files (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg|All Files (*.*)|*.*',
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
      title: 'Select Existing Video Clips',
      filter: 'Video Files (*.mp4;*.mov)|*.mp4;*.mov|All Files (*.*)|*.*',
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

    try {
      final planner = ref.read(storyboardPlannerServiceProvider);
      final project = await planner.planStoryboard(input);
      ref.read(currentVideoProjectProvider.notifier).state = project;
      _tabController.animateTo(1); // Jump to Storyboard stage
      if (!mounted) return;
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
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  void _updateSceneField(int index, {String? title, String? narration, String? caption}) {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;
    final scenes = List<VideoSceneModel>.from(project.scenes);
    final old = scenes[index];
    scenes[index] = old.copyWith(
      title: title ?? old.title,
      narrationText: narration ?? old.narrationText,
      captionText: caption ?? old.captionText,
    );
    ref.read(currentVideoProjectProvider.notifier).state = project.copyWith(scenes: scenes);
  }

  void _handleAddScene() {
    final project = ref.read(currentVideoProjectProvider);
    if (project == null) return;
    final scenes = List<VideoSceneModel>.from(project.scenes);
    scenes.add(VideoSceneModel(
      sceneNumber: scenes.length + 1,
      title: 'New Feature Highlight',
      narrationText: 'Check out another exciting feature that makes daily tasks effortless.',
      visualDescription: 'Feature demonstration slide',
      durationSeconds: 4.0,
      badgeText: 'Feature',
      captionText: 'Effortless daily tasks',
    ));
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
        statusMessage: result.success ? 'Render Complete' : 'Render Failed',
        result: result,
      );

      // Save updated project export status
      if (result.success) {
        final updatedProject = project.copyWith(
          exportStatus: result.mp4FilePath != null ? 'rendered' : 'draft',
          exportedFilePath: result.mp4FilePath,
          fileSizeBytes: result.fileSizeBytes,
        );
        ref.read(currentVideoProjectProvider.notifier).state = updatedProject;
        await ref.read(videoProjectsListProvider.notifier).saveProject(updatedProject);
      }
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

    final defaultFolder = await ref.read(defaultExportFolderProvider.future);
    final sanitizedTitle = project.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final defaultName = '${sanitizedTitle}_${project.aspectRatio.replaceAll(':', 'x')}.mp4';

    final savePath = await NativeFileDialogHelper.saveFile(
      title: 'Export Promotional Video',
      defaultFileName: defaultName,
      filter: 'MP4 Video (*.mp4)|*.mp4|All Files (*.*)|*.*',
      initialDirectory: defaultFolder,
    );

    if (savePath != null && savePath.isNotEmpty) {
      if (result.mp4FilePath != null && File(result.mp4FilePath!).existsSync()) {
        await File(result.mp4FilePath!).copy(savePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Video saved to: $savePath'),
              action: SnackBarAction(
                label: 'Open Folder',
                onPressed: () => NativeFileDialogHelper.openDirectory(File(savePath).parent.path),
              ),
            ),
          );
        }
      } else {
        // Copy directory package or frames
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved project package to: ${result.exportDirectoryPath}')),
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
