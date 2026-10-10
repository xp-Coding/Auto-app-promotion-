import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Database schema definitions and migrations for AppGrowth Studio.
class DatabaseMigrations {
  static const int currentVersion = 4;

  static Future<void> onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. apps
    batch.execute('''
      CREATE TABLE apps (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        package_name TEXT NOT NULL UNIQUE,
        play_store_url TEXT NOT NULL,
        icon_path TEXT,
        category TEXT NOT NULL,
        short_description TEXT,
        full_description TEXT,
        main_features TEXT, -- JSON array of strings
        unique_selling_points TEXT, -- JSON array of strings
        target_audience TEXT,
        target_countries TEXT, -- JSON array of country codes
        supported_languages TEXT, -- JSON array of language codes
        brand_tone TEXT,
        preferred_cta TEXT,
        website_url TEXT,
        privacy_policy_url TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    batch.execute('CREATE INDEX idx_apps_package ON apps(package_name);');
    batch.execute('CREATE INDEX idx_apps_archived ON apps(is_archived);');

    // 2. app_media
    batch.execute('''
      CREATE TABLE app_media (
        id TEXT PRIMARY KEY,
        app_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        media_type TEXT NOT NULL, -- icon, screenshot, banner, video
        title TEXT,
        tags TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_app_media_app_id ON app_media(app_id);');

    // 3. social_accounts
    batch.execute('''
      CREATE TABLE social_accounts (
        id TEXT PRIMARY KEY,
        platform TEXT NOT NULL, -- youtube, facebook, instagram, tiktok
        account_name TEXT NOT NULL,
        account_id TEXT NOT NULL,
        profile_picture_url TEXT,
        status TEXT NOT NULL, -- connected, disconnected, expired, restricted
        connected_at TEXT NOT NULL,
        last_synced_at TEXT,
        capabilities TEXT, -- JSON array
        metadata_json TEXT
      );
    ''');
    batch.execute('CREATE INDEX idx_social_platform ON social_accounts(platform);');

    // 4. campaigns
    batch.execute('''
      CREATE TABLE campaigns (
        id TEXT PRIMARY KEY,
        app_id TEXT NOT NULL,
        name TEXT NOT NULL,
        objective TEXT NOT NULL,
        target_audience TEXT,
        target_country TEXT,
        language TEXT,
        start_date TEXT,
        end_date TEXT,
        status TEXT NOT NULL DEFAULT 'draft', -- draft, active, paused, completed
        posting_frequency TEXT,
        content_themes TEXT, -- JSON array
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_campaigns_app_id ON campaigns(app_id);');

    // 5. campaign_platforms
    batch.execute('''
      CREATE TABLE campaign_platforms (
        id TEXT PRIMARY KEY,
        campaign_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_camp_platforms_campaign ON campaign_platforms(campaign_id);');

    // 6. keywords
    batch.execute('''
      CREATE TABLE keywords (
        id TEXT PRIMARY KEY,
        app_id TEXT NOT NULL,
        keyword TEXT NOT NULL,
        topic_cluster TEXT,
        intent TEXT, -- informational, commercial, navigational, transactional
        relevance_score REAL NOT NULL DEFAULT 0.0,
        source TEXT NOT NULL, -- manual, youtube_public, google_trends, generator
        retrieval_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_keywords_app_id ON keywords(app_id);');
    batch.execute('CREATE INDEX idx_keywords_word ON keywords(keyword);');

    // 7. research_sources
    batch.execute('''
      CREATE TABLE research_sources (
        id TEXT PRIMARY KEY,
        source_type TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT,
        metadata_json TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    // 8. content_posts
    batch.execute('''
      CREATE TABLE content_posts (
        id TEXT PRIMARY KEY,
        app_id TEXT NOT NULL,
        campaign_id TEXT,
        target_platform TEXT NOT NULL,
        title TEXT,
        body_text TEXT NOT NULL,
        hashtags TEXT,
        script_hook TEXT,
        cta_link TEXT,
        format TEXT NOT NULL, -- caption, video_script, story, reel, carousel
        status TEXT NOT NULL DEFAULT 'draft', -- draft, ready, scheduled, published
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE,
        FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE SET NULL
      );
    ''');
    batch.execute('CREATE INDEX idx_posts_app_id ON content_posts(app_id);');
    batch.execute('CREATE INDEX idx_posts_campaign_id ON content_posts(campaign_id);');

    // 9. post_media
    batch.execute('''
      CREATE TABLE post_media (
        id TEXT PRIMARY KEY,
        post_id TEXT NOT NULL,
        media_path TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (post_id) REFERENCES content_posts(id) ON DELETE CASCADE
      );
    ''');

    // 10. post_jobs
    batch.execute('''
      CREATE TABLE post_jobs (
        id TEXT PRIMARY KEY,
        campaign_id TEXT,
        content_id TEXT NOT NULL,
        target_platform TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending', -- pending, running, succeeded, failed, manual_required, cancelled
        retry_count INTEGER NOT NULL DEFAULT 0,
        max_retries INTEGER NOT NULL DEFAULT 3,
        next_retry_at TEXT,
        last_attempt_at TEXT,
        last_error_code TEXT,
        last_error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (content_id) REFERENCES content_posts(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_jobs_status ON post_jobs(status);');
    batch.execute('CREATE INDEX idx_jobs_scheduled ON post_jobs(scheduled_at);');

    // 11. post_attempts
    batch.execute('''
      CREATE TABLE post_attempts (
        id TEXT PRIMARY KEY,
        job_id TEXT NOT NULL,
        attempt_number INTEGER NOT NULL,
        attempted_at TEXT NOT NULL,
        status TEXT NOT NULL,
        error_code TEXT,
        error_message TEXT,
        remote_id TEXT,
        FOREIGN KEY (job_id) REFERENCES post_jobs(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_attempts_job ON post_attempts(job_id);');

    // 12. published_posts
    batch.execute('''
      CREATE TABLE published_posts (
        id TEXT PRIMARY KEY,
        post_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        remote_id TEXT,
        remote_url TEXT,
        published_at TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (post_id) REFERENCES content_posts(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_published_post ON published_posts(post_id);');

    // 13. metric_snapshots
    batch.execute('''
      CREATE TABLE metric_snapshots (
        id TEXT PRIMARY KEY,
        app_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        metric_name TEXT NOT NULL,
        metric_value REAL NOT NULL,
        metric_type TEXT NOT NULL, -- views, likes, comments, shares, clicks, installs
        measured_at TEXT NOT NULL,
        period TEXT,
        source_record_id TEXT,
        is_estimated INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_metrics_app ON metric_snapshots(app_id);');
    batch.execute('CREATE INDEX idx_metrics_name ON metric_snapshots(metric_name);');

    // 14. automation_rules
    batch.execute('''
      CREATE TABLE automation_rules (
        id TEXT PRIMARY KEY,
        rule_name TEXT NOT NULL,
        rule_type TEXT NOT NULL,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        config_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 15. activity_logs
    batch.execute('''
      CREATE TABLE activity_logs (
        id TEXT PRIMARY KEY,
        level TEXT NOT NULL, -- info, warn, error, success
        category TEXT NOT NULL,
        message TEXT NOT NULL,
        details_json TEXT,
        timestamp TEXT NOT NULL
      );
    ''');
    batch.execute('CREATE INDEX idx_logs_timestamp ON activity_logs(timestamp);');

    // 16. application_settings
    batch.execute('''
      CREATE TABLE application_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // 17. autopilot_runs (v2)
    batch.execute('''
      CREATE TABLE autopilot_runs (
        id TEXT PRIMARY KEY,
        app_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'running', -- running, paused, completed, failed
        current_step TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0.0,
        total_posts_created INTEGER NOT NULL DEFAULT 0,
        total_jobs_queued INTEGER NOT NULL DEFAULT 0,
        total_assets_created INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
      );
    ''');
    batch.execute('CREATE INDEX idx_autopilot_app ON autopilot_runs(app_id);');

    // 18. autopilot_settings (v2/v3)
    batch.execute('''
      CREATE TABLE autopilot_settings (
        id TEXT PRIMARY KEY,
        is_autopilot_enabled INTEGER NOT NULL DEFAULT 1,
        require_approval_before_publish INTEGER NOT NULL DEFAULT 0,
        daily_post_limit INTEGER NOT NULL DEFAULT 2,
        weekly_post_limit INTEGER NOT NULL DEFAULT 14,
        posting_time_utc TEXT NOT NULL DEFAULT '18:00',
        target_platforms TEXT NOT NULL DEFAULT '["youtube","tiktok","instagram"]',
        content_languages TEXT NOT NULL DEFAULT '["en"]',
        ai_provider TEXT NOT NULL DEFAULT 'template', -- template, gemini, openai, local
        ai_api_key TEXT,
        ai_model_name TEXT,
        video_format TEXT NOT NULL DEFAULT 'both', -- 9:16, 16:9, both
        time_zone TEXT NOT NULL DEFAULT 'UTC',
        max_retry_attempts INTEGER NOT NULL DEFAULT 3,
        retry_delay_seconds INTEGER NOT NULL DEFAULT 60,
        content_themes TEXT NOT NULL DEFAULT '["Feature Showcase","Problem & Solution","Quick Tutorials","App Updates","Tips & Tricks"]',
        target_audience TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 19. video_projects (v4)
    batch.execute('''
      CREATE TABLE video_projects (
        id TEXT PRIMARY KEY,
        app_id TEXT,
        template_type TEXT NOT NULL DEFAULT 'feature_showcase',
        source_type TEXT NOT NULL DEFAULT 'mixed',
        title TEXT NOT NULL,
        aspect_ratio TEXT NOT NULL DEFAULT '9:16',
        resolution TEXT NOT NULL DEFAULT '1080p',
        total_duration_seconds REAL NOT NULL DEFAULT 15.0,
        scenes TEXT NOT NULL DEFAULT '[]',
        audio_narration_script TEXT NOT NULL DEFAULT '',
        input_app_url TEXT,
        input_text_prompt TEXT,
        input_media_paths TEXT NOT NULL DEFAULT '[]',
        caption_style TEXT NOT NULL DEFAULT 'modern',
        transition_style TEXT NOT NULL DEFAULT 'fade',
        background_music_path TEXT,
        background_music_volume REAL NOT NULL DEFAULT 0.2,
        enable_voice_narration INTEGER NOT NULL DEFAULT 0,
        export_status TEXT NOT NULL DEFAULT 'draft',
        exported_file_path TEXT,
        file_size_bytes INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE SET NULL
      );
    ''');
    batch.execute('CREATE INDEX idx_video_projects_app ON video_projects(app_id);');
    batch.execute('CREATE INDEX idx_video_projects_status ON video_projects(export_status);');

    await batch.commit(noResult: true);
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS autopilot_runs (
          id TEXT PRIMARY KEY,
          app_id TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'running',
          current_step TEXT NOT NULL,
          progress REAL NOT NULL DEFAULT 0.0,
          total_posts_created INTEGER NOT NULL DEFAULT 0,
          total_jobs_queued INTEGER NOT NULL DEFAULT 0,
          total_assets_created INTEGER NOT NULL DEFAULT 0,
          error_message TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_autopilot_app ON autopilot_runs(app_id);');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS autopilot_settings (
          id TEXT PRIMARY KEY,
          is_autopilot_enabled INTEGER NOT NULL DEFAULT 1,
          require_approval_before_publish INTEGER NOT NULL DEFAULT 0,
          daily_post_limit INTEGER NOT NULL DEFAULT 2,
          weekly_post_limit INTEGER NOT NULL DEFAULT 14,
          posting_time_utc TEXT NOT NULL DEFAULT '18:00',
          target_platforms TEXT NOT NULL DEFAULT '["youtube","tiktok","instagram"]',
          content_languages TEXT NOT NULL DEFAULT '["en"]',
          ai_provider TEXT NOT NULL DEFAULT 'template',
          ai_api_key TEXT,
          ai_model_name TEXT,
          video_format TEXT NOT NULL DEFAULT 'both',
          time_zone TEXT NOT NULL DEFAULT 'UTC',
          max_retry_attempts INTEGER NOT NULL DEFAULT 3,
          retry_delay_seconds INTEGER NOT NULL DEFAULT 60,
          content_themes TEXT NOT NULL DEFAULT '["Feature Showcase","Problem & Solution","Quick Tutorials","App Updates","Tips & Tricks"]',
          target_audience TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
    }

    if (oldVersion < 3) {
      // Safe column additions for existing v2 databases
      final cols = [
        "ALTER TABLE autopilot_settings ADD COLUMN time_zone TEXT NOT NULL DEFAULT 'UTC';",
        "ALTER TABLE autopilot_settings ADD COLUMN max_retry_attempts INTEGER NOT NULL DEFAULT 3;",
        "ALTER TABLE autopilot_settings ADD COLUMN retry_delay_seconds INTEGER NOT NULL DEFAULT 60;",
        "ALTER TABLE autopilot_settings ADD COLUMN content_themes TEXT NOT NULL DEFAULT '[\"Feature Showcase\",\"Problem & Solution\",\"Quick Tutorials\",\"App Updates\",\"Tips & Tricks\"]';",
        "ALTER TABLE autopilot_settings ADD COLUMN target_audience TEXT;",
      ];
      for (final sql in cols) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS video_projects (
          id TEXT PRIMARY KEY,
          app_id TEXT,
          template_type TEXT NOT NULL DEFAULT 'feature_showcase',
          source_type TEXT NOT NULL DEFAULT 'mixed',
          title TEXT NOT NULL,
          aspect_ratio TEXT NOT NULL DEFAULT '9:16',
          resolution TEXT NOT NULL DEFAULT '1080p',
          total_duration_seconds REAL NOT NULL DEFAULT 15.0,
          scenes TEXT NOT NULL DEFAULT '[]',
          audio_narration_script TEXT NOT NULL DEFAULT '',
          input_app_url TEXT,
          input_text_prompt TEXT,
          input_media_paths TEXT NOT NULL DEFAULT '[]',
          caption_style TEXT NOT NULL DEFAULT 'modern',
          transition_style TEXT NOT NULL DEFAULT 'fade',
          background_music_path TEXT,
          background_music_volume REAL NOT NULL DEFAULT 0.2,
          enable_voice_narration INTEGER NOT NULL DEFAULT 0,
          export_status TEXT NOT NULL DEFAULT 'draft',
          exported_file_path TEXT,
          file_size_bytes INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (app_id) REFERENCES apps(id) ON DELETE SET NULL
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_video_projects_app ON video_projects(app_id);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_video_projects_status ON video_projects(export_status);');
    }
  }
}
