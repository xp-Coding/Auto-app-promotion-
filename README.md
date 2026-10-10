# AppGrowth Studio: Autonomous App Promotion Autopilot

> **Local-First, Autonomous Google Play Promotion & Multi-Channel Marketing Engine for Windows Desktop**

AppGrowth Studio is a production-grade Flutter Windows desktop application designed specifically for Android developers and independent software publishers. It transforms app promotion into an **Autopilot Experience**: provide a single Google Play Store listing URL or Android package name, and the software automatically inspects the listing, extracts key features and value propositions, performs keyword discovery, synthesizes a 30-day cross-platform marketing calendar, renders high-resolution promotional graphics and video projects, and schedules content to the publishing queue with zero mandatory subscription fees.

---

## 🚀 Key Autopilot Capabilities

### 1. One-Input Onboarding (`AutopilotStudioScreen`)
* **Single Input:** Provide only your Google Play Store URL (e.g., `https://play.google.com/store/apps/details?id=com.spotify.music`) or Android package name (`com.spotify.music`).
* **Listing Extraction:** Automatically scrapes publicly accessible title, developer name, category, short & full descriptions, app icon, and store screenshots.
* **Editable App Profile:** Synthesizes app features, unique selling points (USPs), target audience, and positioning summary into an editable local profile before launch.
* **Source Transparency & Estimation Labels:** Clearly distinguishes genuine listing data from heuristic models. Estimated demographic data is transparently flagged.
* **Integrity Validation Checklist:** Real-time visual checklist verifies presence of essential promotional assets (title, package name, icon, screenshots, privacy policy) and alerts the user to missing fields.

### 2. Autonomous Promotion Engine (`AutopilotOrchestrator`)
Once launched, the engine autonomously executes a complete 10-step promotional pipeline in background jobs with live progress reporting:
1. **App Profile Verification:** Checks listing data and saves the app profile to SQLite.
2. **Category & Demographic Analysis:** Infers user intents without inventing download numbers, reviews, or competitor stats.
3. **Keyword Discovery & Intent Clustering:** Discovers high-intent category tags and scores keyword relevance.
4. **Positioning & Strategy Synthesis:** Formulates a tailored multi-channel promotional strategy.
5. **30-Day Content Calendar Generation:** Generates 30 scheduled posts across YouTube, TikTok, Instagram, Twitter/X, and LinkedIn.
6. **Platform-Specific Copywriting:** Produces platform-tailored hooks, captions, descriptions, relevant hashtags, and calls-to-action.
7. **Local Graphic Rendering:** Renders high-res 1080x1920 (9:16 vertical) and 1920x1080 (16:9 landscape) promotion cards onto disk using Flutter Canvas and real app assets.
8. **Video Project Export (`VideoProjectExporter`):** Builds editable video packages across 7 reusable archetypes (Feature Showcase, Problem-Solution, Quick Tutorial, Launch Announcement, Before-and-After, Installation Guide, Highlight Reel).
9. **Publishing Queue Dispatch:** Directly queues eligible posts into `post_jobs` according to configured daily limits and scheduling windows.
10. **Run State Persistence:** Commits full metrics, asset links, and status into SQLite.

### 3. Video & Graphic Production Suite
* **Canvas Slide Renderer:** Generates crisp 1080x1920 vertical and 1920x1080 landscape slide frames in `video_exports/<id>/frames/scene_XX.png` featuring genuine icons, screenshots, and typography.
* **Timed SRT Subtitles:** Generates standard RFC-compliant subtitle tracks (`subtitles.srt`) mapped to scene durations.
* **Voiceover Scripts:** Formulates complete scene-by-scene narration scripts (`narration_script.txt`).
* **Interactive HTML5 Player:** Generates a standalone `interactive_preview.html` file that plays the video slides in real time in any modern browser without third-party dependencies.
* **FFmpeg Batch Renderer:** Generates `render_mp4.bat` to compile scene frames into high-definition MP4. If FFmpeg is installed in PATH, compilation runs automatically.

### 4. AI & Cost Requirements: Zero Mandatory Subscriptions
* **100% Free Local Template Engine (Default):** Runs completely offline without API keys or recurring costs.
* **Optional BYO AI Providers:**
  * **Google Gemini API (`gemini-2.0-flash`):** Uses your own Google AI Studio API key.
  * **Local LLM via Ollama (`http://127.0.0.1:11434`):** Runs private models (e.g. `llama3`) on local hardware.
  * **OpenAI (`gpt-4o`):** Optional BYO API key support.
* **Transparent Attribution:** Every generated post and campaign is tagged with its origin (`providerName`) in metadata.

### 5. Official Publishing Integrations & Safety
* **YouTube Data API v3:** Official OAuth 2.0 integration with automatic token refreshing, remote publication verification, and strict quota guardrails (10,000 units/day).
* **Manual Export Packages:** Generates ready-to-publish packages (media, copy, tags) for networks requiring manual distribution without unofficial scraper bots.
* **Idempotency Protection:** Prevents duplicate scheduling and accidental re-publishing using unique post hashes.
* **Automatic Restart Recovery:** Resumes interrupted tasks cleanly on app launch without freezing the UI.

---

## 📁 Architecture Overview

```
Auto-app-promotion/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart             # Local SQLite connection (WAL mode)
│   │   │   └── migrations.dart               # Schema v3: autopilot_runs, autopilot_settings
│   │   ├── services/
│   │   │   └── safe_background_worker.dart   # Windows background task runner & queue processor
│   │   └── theme/
│   │       └── app_theme.dart                # Material 3 slate dark and crisp light themes
│   └── features/
│       ├── apps/                             # My Apps management & listing quality scoring
│       ├── autopilot/                        # ⚡ AUTONOMOUS PROMOTION ENGINE
│       │   ├── domain/
│       │   │   ├── autopilot_orchestrator.dart     # 10-step autonomous workflow orchestrator
│       │   │   ├── creative_asset_generator.dart   # Local Canvas graphics & video asset builder
│       │   │   ├── video_project_exporter.dart     # Canvas frames, SRT, script, and HTML preview exporter
│       │   │   └── play_store_scraper.dart         # Google Play Store listing parser & asset downloader
│       │   ├── models/
│       │   │   ├── autopilot_run_model.dart        # Run progress, step, and status tracking
│       │   │   ├── autopilot_settings_model.dart   # Rate limits, retry policies, themes, audience
│       │   │   └── video_project_model.dart        # 7 video archetype scene definitions
│       │   ├── presentation/
│       │   │   └── autopilot_studio_screen.dart    # 3-tab UI: Onboarding, Activity, Configuration
│       │   ├── providers/
│       │   │   └── autopilot_providers.dart        # Riverpod state notifiers & execution runners
│       │   └── repositories/
│       │       └── autopilot_repository.dart       # SQLite persistence for runs and settings
│       ├── content_studio/                   # Smart content router (Templates / Gemini / Ollama)
│       ├── campaigns/                        # Campaign calendar models & repositories
│       ├── publishing/                       # Publishing queue & official YouTube API adapter
│       └── shell/
│           └── desktop_shell.dart            # Sidebar navigation with Autopilot Studio
```

---

## 🛠️ Getting Started on Windows Desktop

### System Requirements
* Windows 10 or Windows 11 (64-bit)
* Flutter 3.47+ (Dart 3.13+)
* Git for Windows

### Build & Verification Commands
```powershell
# 1. Fetch dependencies
flutter pub get

# 2. Run static analysis (verifies 0 errors & 0 warnings)
flutter analyze

# 3. Run automated test suite (49 passing tests)
flutter test

# 4. Launch desktop application
flutter run -d windows
```

---

## ⚙️ Autopilot Configuration

Navigate to **Autopilot Studio** -> **Autopilot Configuration**:
* **Autopilot Enabled:** Master toggle for background orchestration.
* **Require Approval Before Publishing:** Holds generated posts as drafts instead of scheduling directly to the live queue.
* **Rate Limits:** Daily publishing limit (1–10 posts/day) and weekly publishing limit (7–35 posts/week).
* **Scheduling:** Preferred UTC posting time (e.g., 09:00, 12:00, 18:00 UTC) and timezone preference (UTC, Local, EST, PST, GMT, CET, IST).
* **Retry & Failure Handling:** Maximum retry attempts (1–8) and retry delay (30–600 seconds).
* **Target Platforms:** Select active channels (YouTube Shorts/Videos, TikTok, Instagram, Twitter/X, LinkedIn, Facebook).
* **Audience & Themes:** Custom target audience profile override and comma-separated content themes.
* **Engine Provider:** Select between Local Templates (100% Free & Offline), Google Gemini API (BYO Key), Local LLM (Ollama), or OpenAI.
* **Media Formats:** Select between Vertical 9:16 (Shorts/Reels/TikTok), Landscape 16:9 (YouTube), or Both.

---

## 🔒 Compliance & Quality Safeguards

* **No Fictional Claims:** Never fabricates fake reviews, ratings, download numbers, or competitor statistics.
* **Genuine App Assets:** Renders graphics and video slide frames exclusively from genuine store screenshots, icons, and metadata.
* **Official APIs Only:** Uses official OAuth 2.0 and official REST endpoints. No headless browser automation or credential scraping.
* **Strict Idempotency:** SQLite unique checks prevent duplicate scheduling across restarts.
* **Quota Safety:** YouTube adapter checks daily quota limits (10,000 units/day) before initiating API requests.
