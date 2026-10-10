# Changelog: AppGrowth Studio

All notable changes to this project will be documented in this file.

## [1.0.0] - Milestone 1: Audit and Foundation (Completed)

### Added
* **Project Audit (`PROJECT_AUDIT.md`):** Complete inspection of development environment, Flutter 3.47 SDK, Windows desktop requirements, and architectural roadmap.
* **Database Architecture (`lib/core/database/`):**
  * Multi-fallback SQLite FFI dynamic loader (`sqlite_initializer.dart`) resolving local DLL, system `winsqlite3.dll`, and Python fallbacks without requiring Windows Developer Mode symlinks.
  * Version 1 database schema (`migrations.dart`) defining all 16 tables: `apps`, `app_media`, `social_accounts`, `campaigns`, `campaign_platforms`, `keywords`, `research_sources`, `content_posts`, `post_media`, `post_jobs`, `post_attempts`, `published_posts`, `metric_snapshots`, `automation_rules`, `activity_logs`, and `application_settings`.
  * `AppDatabase` connection singleton with WAL mode and foreign key enforcement.
* **My Apps Module (`lib/features/apps/`):**
  * `AppModel` domain entity supporting Play Store listing fields, JSON lists, and live quality evaluation.
  * `AppRepository` implementing complete CRUD operations, case-insensitive search, category filtering, archive toggling, and duplicate package prevention.
  * `AppFormDialog` with Google Play URL validation, auto-package extraction, feature and USP chip editors, character counters, and real-time Listing Quality scoring.
  * `AppDetailsDialog` providing marketing profile inspection, public URL launcher, and rule-based organic campaign angle generation.
  * `AppsScreen` featuring responsive grid layout, category filtering, search, and quality score badges.
* **Dashboard (`lib/features/dashboard/`):**
  * `DashboardRepository` querying real SQLite counts for registered apps, connected accounts, drafts, queue jobs, and failures.
  * Responsive layout with KPI cards, workflow accelerators, and first-run guidance.
* **Desktop Shell & Theme (`lib/features/shell/`, `lib/core/theme/`):**
  * Material 3 slate dark and crisp light theme system.
  * Collapsible sidebar navigation for all 13 application sections.
  * Top navigation header with active app dropdown selector, theme toggle, and offline indicator.
* **Verification & Automated Tests (`test/`):**
  * `validators_test.dart`: Google Play URL validation, package extraction, and quality scoring tests.
  * `app_repository_test.dart`: In-memory SQLite schema creation, CRUD, duplicate constraints, and filtering integration tests.
  * `widget_test.dart`: Desktop shell smoke test.
  * `sqlite_test.dart`: SQLite FFI execution test.
  * 11 passing tests; 0 issues on `flutter analyze`.

## [1.1.0] - Milestone 2: Campaign Management & Content Studio (Completed)

### Added
* **Campaign Planner (`lib/features/campaigns/`):**
  * `CampaignModel` and `CampaignPlatformModel` with multi-platform association (`youtube`, `facebook`, `instagram`, `tiktok`).
  * `CampaignRepository` for transactional CRUD operations, status management (`draft`, `scheduled`, `active`, `completed`, `paused`), and platform linking in SQLite.
  * `CampaignsScreen` with active app filtering, status tabs, date range visualization, and platform chip indicators.
  * `CampaignFormDialog` with multi-platform selector, target goals, budget inputs, date picker, and validation.
  * `CampaignDetailsDialog` featuring complete metadata inspection, UTM tracking link preview, and direct generation workflow.
* **Content Studio & Template Generator (`lib/features/content_studio/`):**
  * Pluggable domain abstraction `ContentGenerationProvider`, `GenerationRequest`, and `GenerationResult`.
  * 100% offline algorithmic engine `TemplateContentProvider` producing platform-tailored promotional copy:
    * **YouTube:** Keyword-optimized titles, detailed descriptions with timestamps, hashtag clusters, and Google Play install attribution links.
    * **TikTok:** 9:16 vertical video storyboards, problem-solution hooks, trending audio suggestions, and bio link CTAs.
    * **Instagram:** Reels script outlines, multi-slide Carousel storyboards, and categorized hashtag blocks.
    * **Facebook:** Benefit-driven post copy, bullet-point feature breakdowns, and direct install links.
  * `ContentPostModel` and `ContentPostRepository` for SQLite post lifecycle management.
  * `ContentStudioScreen` with search, platform filter, status tabs, and responsive layout.
  * `PostEditorDialog` supporting one-click template generation, live character counts, custom editing, and UTM link injection.
  * `PostPreviewDialog` with authentic multi-platform UI mockups for YouTube, TikTok, Instagram, and Facebook.
* **Media Library (`lib/features/media_library/`):**
  * `MediaItemModel` and `MediaRepository` tracking local file paths, file types, aspect ratios, file size formatting, and filesystem existence verification.
  * `MediaLibraryScreen` with thumbnail previews, broken path detection, file type filtering, and search.
  * `AddMediaDialog` for cataloging local creative assets with tagging.
* **Attribution URL Generator (`lib/core/utils/utm_builder.dart`):**
  * RFC-compliant Google Play Store UTM attribution generator using the official `referrer` parameter format.

## [1.2.0] - Milestone 3 (Offline): Keyword Research & Market Intelligence (Completed)

### Added
* **Keyword Research & Quality Scoring (`lib/features/keywords/`):**
  * `KeywordModel` with app relationship, intent classification (`informational`, `commercial`, `navigational`, `transactional`), topic clusters, and qualitative relevance scoring.
  * `KeywordRelevanceScorer`: 100% transparent qualitative scoring engine based on token overlap with app title, short description, and feature lists. Does **not** invent or display fabricated search volume numbers.
  * `ScoreExplanation` breaking down score contributions (title matching, description matching, intent alignment, source credibility).
  * `KeywordRepository` with full SQLite CRUD, app filtering, and bulk operations.
  * `KeywordExplorerScreen` with instant search, intent filter chips, qualitative score indicators, and factor explanation dialogs.
  * `KeywordFormDialog` providing real-time relevance score previews as users type.
* **Market Research Hub (`lib/features/keywords/presentation/market_research_screen.dart`):**
  * Rule-based organic angle generation derived from registered app USPs and features.
  * Video hook concept generator transforming high-scoring keywords into actionable social hooks.
  * Keyword gap recommendations and cluster distribution analysis.
* **CSV Import & Export Engine (`lib/core/utils/csv_helper.dart`, `keyword_import_export_dialog.dart`):**
  * RFC 4180 compliant CSV parser and encoder supporting quotes, commas, and newlines.
  * Bulk import and export dialog for keywords and topic clusters with error reporting.
* **Verification & Automated Tests (`test/`):**
  * `campaign_repository_test.dart`: SQLite transaction tests for campaigns and linked platforms.
  * `content_generator_test.dart`: Algorithmic template generation for all 4 platforms and post CRUD tests.
  * `keyword_repository_test.dart`: Qualitative scoring accuracy, CSV export/import, and keyword CRUD tests.
  * `utm_builder_test.dart`: Google Play URL and `referrer` encoding validation.
  * `csv_helper_test.dart`: RFC 4180 edge cases and formatting tests.
  * Total test count expanded to 23 tests; 100% passing; 0 issues on `flutter analyze`.

## [1.3.0] - Milestone 4 & 5 (Phase 1): Publishing Queue & Official YouTube Platform Adapter (Completed)

### Added
* **Persistent Publishing Queue Engine (`lib/features/publishing/`):**
  * `PostJobModel`, `PostAttemptModel`, and `PublishedPostModel` entities mapping to `post_jobs`, `post_attempts`, and `published_posts` SQLite tables.
  * `PublishingQueueRepository` for transactional lifecycle management (`pending`, `running`, `succeeded`, `failed`, `manual_required`, `cancelled`).
  * `PublishingEngine` coordinating unattended execution, retry bounding, and attempt logging.
  * **Strict Idempotency Protection:** Checks prior publication records (`published_posts`) and remote states to prevent duplicate video uploads or re-postings when jobs are re-triggered.
  * **Bounded Exponential Backoff:** Automatically reschedules transient failures (`NETWORK_TIMEOUT`, `RATE_LIMIT`, `SERVER_ERROR`) with exponential delays (`30s * 2^retryCount`), transitioning to `failed` or `manual_required` upon reaching `max_retries`.
* **Pluggable Platform Adapter Contract (`lib/features/publishing/domain/platform_adapter.dart`):**
  * Standardized `PublishingPlatformAdapter` interface with `publish()`, `verifyPublication()`, `checkQuota()`, and `revokeAuth()`.
  * `PublishResult`, `VerificationResult`, `QuotaStatus`, and structured `PublishError` models.
  * Modular design keeping all future adapters (TikTok, Facebook, Instagram) 100% decoupled and independent.
* **Official YouTube Platform Adapter (`lib/features/publishing/adapters/youtube/`):**
  * Built exclusively on official, documented Google APIs:
    * Google OAuth 2.0 with automatic token refresh (`https://oauth2.googleapis.com/token`).
    * YouTube Data API v3 (`videos.insert`, `videos.list`, `channels.list`).
  * **Secure Credential Storage (`youtube_token_storage.dart`):** Local obfuscated credential storage in `application_settings` protecting OAuth client IDs, secrets, and refresh tokens from plaintext database dumps.
  * **Daily Quota Enforcement (`youtube_quota_tracker.dart`):** Enforces YouTube's 10,000 units/day project quota boundary (1,600 units for video uploads, 1 unit for status queries), automatically tracking Pacific Time midnight resets and halting requests before quota breaches occur.
  * **Remote Publication Verification:** Verifies video status (`uploaded`, `processed`, `privacyStatus`) directly against YouTube servers via `videos.list`.
  * **Structured Error Mapping:** Distinguishes between retryable transient errors (429 rate limit, 503 server outage) and permanent non-retryable issues (401 auth revoked, 403 quota exceeded, media missing).
* **UI & Desktop Shell Integration:**
  * `PublishingQueueScreen`: Complete queue console with real-time metrics, YouTube daily quota gauge, status and platform filters, manual retry triggers, and "Process Due Jobs Now" executor.
  * `JobAttemptsDialog`: Detailed execution history log per job displaying attempt timestamps, status badges, remote video IDs, and error diagnostics.
  * `SocialAccountsScreen`: Account manager displaying active YouTube channel info (subscribers, video count, sync status), quota meter, OAuth configuration modal, and modular placeholders for future adapters.
  * `YouTubeCredentialsDialog`: Desktop configuration dialog for user Google Cloud OAuth credentials with built-in connection verification.
  * `PostEditorDialog` & `ContentStudioScreen`: Added direct "Schedule to Queue" triggers.
  * Wired Tab 7 (Publishing Queue) and Tab 8 (Social Accounts) in `DesktopShell`.
* **Verification & Automated Tests (`test/publishing/`):**
  * `youtube_adapter_test.dart`: Mocked OAuth token refresh, video upload with quota consumption, missing media rejection, quota limit protection, remote publication verification, and channel metadata retrieval.
  * `publishing_engine_test.dart`: End-to-end execution, idempotency duplicate prevention, bounded exponential retries, and unauthenticated adapter transitions.
  * Expanded test suite from 23 to **32 passing tests**; **0 issues** on `flutter analyze`.

## [1.4.0] - Milestone 8 & Release Preparation: Analytics, Background Heartbeat, Backup/Restore & Structured Logs (Completed)

### Added
* **Analytics & Campaign Reports (`lib/features/analytics/`):**
  * `MetricSnapshotModel` in SQLite `metric_snapshots` table with distinct flags differentiating **measured metrics** (from official APIs and link attribution) from **statistical estimates** (`is_estimated = 1`).
  * `CampaignReportModel` aggregating total measured video views, likes, comments, and attributed clicks, with modeled Play Store visits and installs based on explicit Google Play benchmarks (8.0% CVR).
  * `AnalyticsRepository` featuring:
    * Scheduled metric retrieval from YouTube Data API v3 (`videos.list?part=statistics`) recording real view/like/comment counts.
    * Platform comparison matrix (YouTube, TikTok, Facebook, Instagram).
    * RFC 4180 CSV export generating comprehensive campaign performance files.
  * `AnalyticsScreen` (Tab 9): Responsive UI with visual badges (`MEASURED (OFFICIAL)` vs `STATISTICAL ESTIMATE`), time range filters (`7d`, `30d`, `all`), and top performing post leaderboards.
* **Safe Windows Background Execution & Restart Recovery (`lib/core/services/`):**
  * `SafeBackgroundWorker`: Resilient in-process periodic ticker (`Timer.periodic`) running within the Flutter desktop event loop without requiring fragile Windows services or elevated privileges.
  * **Startup Restart Recovery:** Detects jobs interrupted in the `running` state by sudden system reboots or app termination:
    * Verifies remote platform state before retrying.
    * Safely resets unverified jobs back to `pending` and logs an `interrupted_recovered` attempt in `post_attempts`.
* **Database Backup & Restore System (`lib/core/backup/`):**
  * `BackupService`: Flushes SQLite WAL pages via `PRAGMA wal_checkpoint(FULL);` and produces timestamped backup files (`.sqlite`) with accompanying JSON metadata manifests.
  * **Integrity Verification:** Validates SQLite magic file headers and tests database health with `PRAGMA integrity_check` before applying restore operations.
  * Automatic pre-restore emergency copy generation to protect user data from corruption.
* **Structured Audit Logging (`lib/core/logging/`):**
  * `ActivityLogModel` & `ActivityLogRepository` logging events to `activity_logs` in SQLite.
  * `AppLogger`: Static utility providing token-sanitized logging across `publishing`, `auth`, `analytics`, `database`, and `system`. Automatically strips OAuth tokens and secrets before writing to disk.
  * `ActivityLogsScreen` (Tab 11): Filterable audit log console with level chips (`All`, `Info`, `Success`, `Warn`, `Error`), category dropdown, and log pruning.
* **Settings & System Diagnostics (`lib/features/settings/`):**
  * `SettingsScreen` (Tab 12): System diagnostics displaying database location, size, WAL journal mode status, foreign key enforcement, backup manager, background worker controls, and 30-day log pruning.
* **Windows Release Preparation:**
  * Updated `windows/CMakeLists.txt` to install bundled `sqlite3.dll` into the release distribution directory alongside the executable.
  * Configured window title in `windows/runner/main.cpp` to `AppGrowth Studio - Marketing & Social Media Automation`.
* **Automated Test Suite Expansion (`test/`):**
  * Added `test/analytics/analytics_test.dart`: Metric distinction tests, YouTube stats sync, and report CSV row generation.
  * Added `test/services/restart_recovery_test.dart`: Interrupted running job detection and safe recovery transitions.
  * Added `test/backup/backup_test.dart`: SQLite header validation and backup manifest serialization.
  * Total automated test count expanded from 32 to **38 passing tests**; **0 issues** on `flutter analyze`.

## [2.0.0] - Autonomous App Promotion Autopilot (Completed)

### Added
* **One-Input Onboarding (`AutopilotStudioScreen`):**
  * Extract public metadata, icons, and screenshots from any Google Play Store URL or package name.
  * Editable profile synthesis and real-time Listing Integrity checklist.
* **10-Step Autonomous Promotion Pipeline (`AutopilotOrchestrator`):**
  * 30-day cross-platform marketing calendar generation with platform-tailored copywriting.
  * High-resolution promotional card and video project generation.
  * Direct enqueueing of eligible posts to publishing queue.
* **Zero Mandatory Subscriptions:**
  * 100% offline local template engine as default.
  * Optional BYO AI provider support for Google Gemini, Ollama, and OpenAI.

## [2.1.0] - Multi-Input Video Creator & Local Export Engine (Completed)

### Added
* **Multi-Input Video Creator (`VideoCreatorStudioView`):**
  * Synthesize promotional videos from any single source or any mix of 4 inputs: App URL, screenshots/images, video clips with trim boundaries, and text prompt.
  * Integrated directly into Content Studio under the Video Template Studio tab.
* **9 Video Template Archetypes:**
  * App Feature Showcase, Problem & Solution, App Tutorial, Launch Announcement, Before-and-After Demo, App Installation Guide, Promotional Slideshow, Video Enhancement, and Text-to-Video Promo.
* **Aspect Ratios & Resolutions:**
  * 9:16 Vertical, 16:9 Landscape, 1:1 Square in 1080p and 720p.
  * Anti-distortion contain scaling with ambient dark framing.
* **Mandatory Local Export & Dialogs (`NativeFileDialogHelper`):**
  * Native Windows `SaveFileDialog` and `FolderBrowserDialog` without third-party plugins or Developer Mode symlinks.
  * Direct "Export Video to Computer" and "Open in Explorer" actions.
  * Configurable default export folder in Settings.
* **Local Processing & FFmpeg Engine (`FfmpegService`):**
  * Automatic FFmpeg detection from PATH, WinGet, Chocolatey, or custom settings.
  * Zero-dependency fallback producing full HTML5 preview player, Canvas frames, SRT subtitles, and `.bat` compiler script.
* **Database Migration & Persistence (`VideoProjectRepository`):**
  * SQLite schema version 4 with `video_projects` table.
  * Reopen, modify, and re-export past video projects from Saved Projects library.
* **Automated Test Suite Expansion (`test/video_creator_workflow_test.dart`):**
  * 9 scenario tests covering all input modes, export, persistence, error handling, and dimension verification.
  * All 58 tests passing; 0 issues on `flutter analyze`.


