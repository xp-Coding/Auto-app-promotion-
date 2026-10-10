import 'package:flutter/material.dart';

enum VisualCategory {
  background,
  gradient,
  pattern,
  icon,
  card,
  stockMedia,
}

class VisualAssetItem {
  final String id;
  final String title;
  final VisualCategory category;
  final List<Color> gradientColors;
  final IconData? iconData;
  final String? patternType; // 'dots', 'grid', 'waves', 'circuit', 'isometric'
  final String licenseType;
  final String? attribution;
  final String description;

  const VisualAssetItem({
    required this.id,
    required this.title,
    required this.category,
    this.gradientColors = const [],
    this.iconData,
    this.patternType,
    this.licenseType = 'Built-in (Offline Royalty-Free)',
    this.attribution,
    this.description = '',
  });
}

class VisualLibraryService {
  /// Built-in offline gradients with curated modern palettes
  static const List<VisualAssetItem> builtInGradients = [
    VisualAssetItem(
      id: 'grad_midnight_indigo',
      title: 'Midnight Indigo',
      category: VisualCategory.gradient,
      gradientColors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
      description: 'Deep navy and electric indigo for sleek modern SaaS and productivity.',
    ),
    VisualAssetItem(
      id: 'grad_cyber_neon',
      title: 'Cyber Neon',
      category: VisualCategory.gradient,
      gradientColors: [Color(0xFF0A0A1E), Color(0xFF101935), Color(0xFF0D9488)],
      description: 'Futuristic dark teal and cyber ambient tones.',
    ),
    VisualAssetItem(
      id: 'grad_sunset_coral',
      title: 'Sunset Coral',
      category: VisualCategory.gradient,
      gradientColors: [Color(0xFF1A0B2E), Color(0xFF701A75), Color(0xFFF43F5E)],
      description: 'Vibrant sunset aura for social, entertainment, and lifestyle apps.',
    ),
    VisualAssetItem(
      id: 'grad_emerald_forest',
      title: 'Emerald Luxe',
      category: VisualCategory.gradient,
      gradientColors: [Color(0xFF062016), Color(0xFF064E3B), Color(0xFF10B981)],
      description: 'Rich emerald green for finance, crypto, wealth, and wellness.',
    ),
    VisualAssetItem(
      id: 'grad_royal_purple',
      title: 'Royal Purple',
      category: VisualCategory.gradient,
      gradientColors: [Color(0xFF190933), Color(0xFF4C1D95), Color(0xFF8B5CF6)],
      description: 'Premium violet and lavender for AI, luxury, and creative tools.',
    ),
    VisualAssetItem(
      id: 'grad_titanium_dark',
      title: 'Titanium Dark',
      category: VisualCategory.gradient,
      gradientColors: [Color(0xFF18181B), Color(0xFF27272A), Color(0xFF3F3F46)],
      description: 'Monochrome minimalist dark titanium for developer tools and utilities.',
    ),
    VisualAssetItem(
      id: 'grad_deep_ocean',
      title: 'Deep Ocean',
      category: VisualCategory.gradient,
      gradientColors: [Color(0xFF031926), Color(0xFF0D3B66), Color(0xFF0284C7)],
      description: 'Deep marine blues for cloud sync, security, and messaging.',
    ),
    VisualAssetItem(
      id: 'grad_solar_amber',
      title: 'Solar Amber',
      category: VisualCategory.gradient,
      gradientColors: [Color(0xFF2E1005), Color(0xFF7C2D12), Color(0xFFF59E0B)],
      description: 'Energetic warm amber for fitness, fast delivery, and sports.',
    ),
  ];

  /// Built-in abstract procedural patterns
  static const List<VisualAssetItem> builtInPatterns = [
    VisualAssetItem(
      id: 'pat_dot_grid',
      title: 'Dot Matrix Grid',
      category: VisualCategory.pattern,
      patternType: 'dots',
      description: 'Subtle technical dot matrix overlay for precision layouts.',
    ),
    VisualAssetItem(
      id: 'pat_cyber_grid',
      title: 'Cyber Perspective Grid',
      category: VisualCategory.pattern,
      patternType: 'grid',
      description: 'High-tech wireframe terrain and ambient lighting.',
    ),
    VisualAssetItem(
      id: 'pat_wave_flow',
      title: 'Fluid Wave Lines',
      category: VisualCategory.pattern,
      patternType: 'waves',
      description: 'Smooth organic contour lines for audio, creativity, and flow.',
    ),
    VisualAssetItem(
      id: 'pat_isometric',
      title: 'Isometric Blueprint',
      category: VisualCategory.pattern,
      patternType: 'isometric',
      description: 'Architectural isometric geometry for productivity and engineering.',
    ),
  ];

  /// Built-in royalty-free icons by app domain
  static const List<VisualAssetItem> builtInIcons = [
    VisualAssetItem(
      id: 'ico_rocket',
      title: 'Rocket Launch',
      category: VisualCategory.icon,
      iconData: Icons.rocket_launch,
      description: 'App launch, instant speed, growth, milestones.',
    ),
    VisualAssetItem(
      id: 'ico_shield',
      title: 'Security Shield',
      category: VisualCategory.icon,
      iconData: Icons.verified_user,
      description: 'Privacy, end-to-end encryption, trust, safety.',
    ),
    VisualAssetItem(
      id: 'ico_speed',
      title: 'Lightning Speed',
      category: VisualCategory.icon,
      iconData: Icons.bolt,
      description: 'Rapid performance, instant synchronization, quick actions.',
    ),
    VisualAssetItem(
      id: 'ico_analytics',
      title: 'Growth Chart',
      category: VisualCategory.icon,
      iconData: Icons.trending_up,
      description: 'Analytics, finance, stats, habit streaks, progress tracking.',
    ),
    VisualAssetItem(
      id: 'ico_timer',
      title: 'Focus Timer',
      category: VisualCategory.icon,
      iconData: Icons.timer,
      description: 'Pomodoro timer, focus sessions, time tracking, reminders.',
    ),
    VisualAssetItem(
      id: 'ico_cloud',
      title: 'Cloud Sync',
      category: VisualCategory.icon,
      iconData: Icons.cloud_done,
      description: 'Automatic backup, multi-device cloud synchronization.',
    ),
    VisualAssetItem(
      id: 'ico_sparkles',
      title: 'Smart Automation',
      category: VisualCategory.icon,
      iconData: Icons.auto_awesome,
      description: 'AI features, intelligent assistance, instant enhancement.',
    ),
    VisualAssetItem(
      id: 'ico_play',
      title: 'Media Playback',
      category: VisualCategory.icon,
      iconData: Icons.play_circle_filled,
      description: 'Video player, audio streaming, live recording.',
    ),
    VisualAssetItem(
      id: 'ico_download',
      title: 'Store Download',
      category: VisualCategory.icon,
      iconData: Icons.download_for_offline,
      description: 'Google Play store download call-to-action button.',
    ),
  ];

  /// Analyzes scene meaning and suggests the optimal visual composition
  VisualAssetItem suggestVisual({
    required String sceneTitle,
    required String onScreenText,
    required String badgeText,
    required String category,
  }) {
    final text = '$sceneTitle $onScreenText $badgeText $category'.toLowerCase();

    if (text.contains('security') || text.contains('privacy') || text.contains('protect') || text.contains('encrypt')) {
      return builtInIcons.firstWhere((i) => i.id == 'ico_shield');
    }
    if (text.contains('speed') || text.contains('fast') || text.contains('quick') || text.contains('instant')) {
      return builtInIcons.firstWhere((i) => i.id == 'ico_speed');
    }
    if (text.contains('launch') || text.contains('start') || text.contains('explore') || text.contains('discover')) {
      return builtInIcons.firstWhere((i) => i.id == 'ico_rocket');
    }
    if (text.contains('chart') || text.contains('track') || text.contains('growth') || text.contains('streak') || text.contains('stat')) {
      return builtInIcons.firstWhere((i) => i.id == 'ico_analytics');
    }
    if (text.contains('time') || text.contains('focus') || text.contains('pomodoro') || text.contains('schedule')) {
      return builtInIcons.firstWhere((i) => i.id == 'ico_timer');
    }
    if (text.contains('cloud') || text.contains('sync') || text.contains('backup') || text.contains('save')) {
      return builtInIcons.firstWhere((i) => i.id == 'ico_cloud');
    }
    if (text.contains('download') || text.contains('get') || text.contains('install') || text.contains('store')) {
      return builtInIcons.firstWhere((i) => i.id == 'ico_download');
    }

    return builtInIcons.firstWhere((i) => i.id == 'ico_sparkles');
  }

  /// Suggests a complementary gradient for an app category
  VisualAssetItem suggestGradientForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('finance') || cat.contains('money') || cat.contains('crypto') || cat.contains('health')) {
      return builtInGradients.firstWhere((g) => g.id == 'grad_emerald_forest');
    }
    if (cat.contains('social') || cat.contains('entertainment') || cat.contains('music')) {
      return builtInGradients.firstWhere((g) => g.id == 'grad_sunset_coral');
    }
    if (cat.contains('game') || cat.contains('gaming')) {
      return builtInGradients.firstWhere((g) => g.id == 'grad_cyber_neon');
    }
    if (cat.contains('developer') || cat.contains('tool') || cat.contains('utility')) {
      return builtInGradients.firstWhere((g) => g.id == 'grad_titanium_dark');
    }
    if (cat.contains('education') || cat.contains('ai') || cat.contains('photo')) {
      return builtInGradients.firstWhere((g) => g.id == 'grad_royal_purple');
    }
    return builtInGradients.firstWhere((g) => g.id == 'grad_midnight_indigo');
  }
}
