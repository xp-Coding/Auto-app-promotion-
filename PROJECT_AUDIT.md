# Project Audit & Technical Analysis: AppGrowth Studio

**Date:** October 9, 2026  
**Target Platform:** Windows Desktop (x64)  
**Framework:** Flutter 3.47.5 (Channel stable) / Dart 3.13.4  
**Application Title:** AppGrowth Studio (Free AI-Powered Google Play Promotion & Marketing Studio)

---

## 1. Existing Architecture & Project State

* **Root Directory:** `d:\Ai promo`
* **Initial State:** Empty directory initialized cleanly with `flutter create --org com.appgrowth --project-name appgrowth_studio --platforms windows .`.
* **Flutter Environment:**
  * Flutter SDK: 3.47.5 (stable channel)
  * Dart SDK: 3.13.4
  * Operating System: Microsoft Windows 10 Pro 64-bit (22H2)
  * Connected Device: Windows desktop (`windows-x64`)
  * Windows Developer Mode status: Disabled by default (non-elevated user).
  * Visual Studio C++ workload: Missing native C++ build tools for `flutter build windows` compiling C++ runners, but Dart FFI, `flutter test`, `flutter analyze`, and Dart runtimes execute flawlessly.
* **Archived Prototype Insight:** `d:\automated system\promo_desktop` contains a previous Python-based automation prototype, highlighting core workflows: listing parsing, video scripting, and social queueing.

---

## 2. Working Features (Baseline)

* Flutter Windows scaffold initialized with Material 3 base.
* Dart toolchain and analyzer functional (`flutter analyze` reports 0 issues).
* Test framework functional (`flutter test` passes 100%).
* Local SQLite FFI execution tested and verified (`sqflite_common_ffi` + `sqlite3` via dynamic FFI loading) without external dependencies or cloud databases.

---

## 3. Missing Features (To Implement)

1. **Local SQLite Architecture & Schema:**
   * Versioned migrations for `apps`, `app_media`, `social_accounts`, `campaigns`, `campaign_platforms`, `keywords`, `research_sources`, `content_posts`, `post_media`, `post_jobs`, `post_attempts`, `published_posts`, `metric_snapshots`, `automation_rules`, `activity_logs`, `application_settings`.
2. **Desktop UI Shell:**
   * Responsive collapsible sidebar navigation for all 13 required sections:
     1. Dashboard
     2. My Apps
     3. Market Research
     4. Keyword Explorer
     5. Content Studio
     6. Media Library
     7. Campaign Planner
     8. Publishing Queue
     9. Social Accounts
     10. Analytics
     11. Automation Rules
     12. Activity Logs
     13. Settings
   * Modern Material 3 dark and light theme system with persistent preferences.
3. **My Apps Module:**
   * Google Play URL validation, package name auto-extraction and regex validation.
   * Listing quality checklist (icon, short description limits, long description depth, USPs, privacy policy).
   * Full CRUD operations with SQLite persistence, search, filter, and archive support.
   * Quick link opening in default browser.
4. **Subsequent Milestones:**
   * Content Studio (template-based zero-cost generation + optional Ollama local AI).
   * Market Research & Keyword Explorer (local relevance scoring, YouTube public search via official API, CSV export).
   * Campaign Planner & Persistent Automation Engine (SQLite-backed job queue with retry, exponential backoff, pause/resume).
   * Official Social Platform Adapters (YouTube, Facebook, Instagram, TikTok manual packaging).
   * Analytics, Attribution (UTM parameters), Database Backup & Restore.

---

## 4. Build and Dependency Strategy

* **Native Plugin Symlink Constraint on Windows:**  
  Standard Flutter plugins with native C++ platform channels (`path_provider_windows`, `sqlite3_flutter_libs`) attempt to create symlinks in `.dart_tool`, requiring Windows Developer Mode (elevated privilege).
* **Architecture Solution:**  
  Use pure Dart libraries and direct Dart FFI:
  * `sqflite_common_ffi` + `sqlite3` loaded via FFI (using local `sqlite3.dll` or Windows `winsqlite3.dll`).
  * Pure Dart `Platform.environment['APPDATA']` for secure local desktop directory resolution (`%APPDATA%/AppGrowthStudio`).
  * `flutter_riverpod` for clean, decoupled desktop state management.
  * `intl` for datetime formatting and localization.
  * `uuid` for deterministic, offline GUID generation.
  * `http` for compliant, timeout-guarded REST calls.
  * Native `Process.run('explorer.exe', ...)` for launching browser URLs safely without external plugins.

---

## 5. Recommended Changes for Milestone 1

1. **Database Layer (`lib/core/database/`):**
   * `sqlite_initializer.dart`: Multi-stage DLL resolver (local project directory, system32 `winsqlite3.dll`, Python DLL fallback).
   * `app_database.dart`: Database singleton managing versioned migrations, parameterized transactions, and error handling.
   * `migrations.dart`: Version 1 schema creating all 16 tables, primary keys, foreign keys, and indexes.
2. **Domain & Data Layer (`lib/features/apps/`):**
   * `models/app_model.dart`: Complete data model matching Play Store fields and listing metadata.
   * `repositories/app_repository.dart`: Concrete SQLite repository with CRUD, search, filter, archive, and deduplication.
   * `providers/app_providers.dart`: Riverpod state notifiers for reactive UI updates.
3. **Desktop Shell & Theme (`lib/core/theme/`, `lib/core/widgets/`):**
   * Modern Slate/Indigo Material 3 design with vibrant accents, responsive cards, and clean typography.
   * Left navigation rail/sidebar with all 13 modules, active indicator, and smooth collapse.
4. **My Apps Screens (`lib/features/apps/presentation/`):**
   * App list with search, category filtering, listing quality score badges, and archive toggle.
   * Comprehensive App Form modal/sheet with live validation, Play Store URL parser, feature tag chips, and quality checklist.
   * App details view with marketing summary and direct Play Store link launcher.

---

## 6. Files Created/Modified in Milestone 1

* `pubspec.yaml` (configured pure Dart dependencies)
* `lib/main.dart` (Riverpod entry point, desktop window configuration, theme toggle)
* `lib/core/database/sqlite_initializer.dart`
* `lib/core/database/app_database.dart`
* `lib/core/database/migrations.dart`
* `lib/core/theme/app_theme.dart`
* `lib/core/utils/url_launcher.dart`
* `lib/core/utils/validators.dart`
* `lib/features/shell/desktop_shell.dart`
* `lib/features/apps/models/app_model.dart`
* `lib/features/apps/repositories/app_repository.dart`
* `lib/features/apps/providers/app_providers.dart`
* `lib/features/apps/presentation/apps_screen.dart`
* `lib/features/apps/presentation/app_form_dialog.dart`
* `lib/features/apps/presentation/app_details_dialog.dart`
* `lib/features/dashboard/presentation/dashboard_screen.dart`
* `test/app_repository_test.dart`
* `test/validators_test.dart`
* `PROJECT_AUDIT.md`

---

## 7. Risks and Mitigation

| Risk | Mitigation |
| :--- | :--- |
| Windows Developer Mode disabled blocks native plugins | Pure Dart FFI & `dart:io` directory management. Zero symlinks required. |
| Corrupt or locked SQLite file | Parameterized statements, WAL mode, transaction wrapping, automated recovery logic. |
| Incomplete Play Store metadata entry | Flexible schema allowing manual entry + listing quality validator. |
| Memory leaks on desktop | Proper disposal of form controllers, streaming queries, and reactive listeners. |
