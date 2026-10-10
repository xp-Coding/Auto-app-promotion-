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

### 3. Multi-Input Video Creator & Local Export Studio (`VideoCreatorStudioView`)
Located under **Content Studio -> Video Template Studio**, this studio allows users to synthesize high-impact promotional videos from any single input or any combination of four inputs:
* **Input A: App Store Listing URL:** Scrapes app metadata, description, icon, and listing screenshots from Google Play Store.
* **Input B: App Screenshots & Images:** Reorderable local images (PNG, JPG, JPEG) fitted seamlessly without distortion or stretching.
* **Input C: Existing Video Footage:** Local clips (MP4, MOV) with customizable start and end trimming points.
* **Input D: Text & Feature Prompt:** Auto-converts custom feature points or value propositions into a structured storyboard.
* **Mix-and-Match Any Inputs:** Works with URL only, screenshots only, clips only, text only, or any combination (e.g. Screenshots + Text, Clips + Text, or all 4 combined).

#### 🎬 9 Supported Video Template Archetypes
1. **App Feature Showcase:** Highlights core tools, benefits, and value propositions.
2. **Problem and Solution:** Hooks the user with daily struggles and introduces the app as the answer.
3. **App Tutorial:** Step-by-step walkthrough of key workflows.
4. **App Launch Announcement:** High-energy celebration of a new version or major update.
5. **Before-and-After Demo:** Contrasts routine frustration with the streamlined app experience.
6. **App Installation Guide:** Direct onboarding instructions for first-time users.
7. **Promotional Slideshow:** Elegant image-driven slideshow with ambient animated backdrop.
8. **Existing-Video Enhancement:** Overlays subtitles, titles, and CTA badges on existing footage.
9. **Text-to-Video Presentation:** Synthesizes a complete promotional video from pure text copy.

#### 📐 Aspect Ratios & Formats
* **Vertical 9:16:** Reels, Shorts, and TikTok (1080x1920 or 720x1280).
* **Landscape 16:9:** YouTube and Web (1920x1080 or 1280x720).
* **Square 1:1:** Social Feeds (1080x1080 or 720x720).
* **Anti-Distortion Guarantee:** Media is letterboxed with ambient dark framing (`contain` mode); never stretched or squished.

#### 💾 Genuine MP4 Video Rendering & Native Windows Export (`FfmpegService`, `VideoProjectExporter`)
* **Real Playable MP4 Video Compilation:** Compiles high-res Canvas slide frames, video clips, voiceover narration audio, background music, and timing into actual H.264/AAC MP4 files.
* **Stream & Duration Verification:** Uses `FfmpegService.probeVideo()` to strictly verify that exported files contain valid video streams, non-zero duration, exact dimensions, and non-empty sizes before marking rendering as successful.
* **Precise Rendering Statuses:** Distinct tracking states (`storyboardReady`, `visualAssetsReady`, `framesGenerated`, `encodingInProgress`, `videoEncodedSuccessfully`, `exported`, `failed`).
* **Native Windows Save File Dialog:** Direct "Export Video to Computer" button opens a native Windows `SaveFileDialog` for user-selected destination paths and filenames (`.mp4`).
* **Instant Media Actions:** Verified output card provides direct "Play Video in Default Player" and "Open Export Folder" actions.
* **FFmpeg Auto-Detection:** Automatically discovers FFmpeg from the bundled path, system PATH, custom settings, WinGet, or Chocolatey.
* **100% Offline & Account-Independent:** Export functions entirely on your computer without requiring external accounts or internet access.

#### 📝 Storyboard & Voice-Over Text Preservation (Part B)
* **Independent Text Fields:** Each scene stores completely independent values for Scene Title, On-screen Text, Voice-Over Narration, Subtitle Text, Visual Description, and Call-to-Action.
* **Immutable User Input:** Original text prompts are preserved in `originalInputText` and never silently rewritten, summarized, or truncated.
* **Stable Scene Identity & State:** Scene items have unique IDs (`id`). Flutter TextEditingControllers are persistent and keyed by `${scene.id}_$field` with `ValueKey(scene.id)` so that reordering scenes or switching tabs never causes text jumping or data loss.
* **Granular Regeneration Menu:** Per-scene popup menu provides discrete actions:
  * *Regenerate Visual Only* (leaves all text intact)
  * *Regenerate Narration Only* (leaves on-screen text and visuals intact)
  * *Regenerate Captions Only* (leaves narration and visuals intact)
  * *Regenerate Scene* (regenerates only the selected scene)
  * *Regenerate Storyboard* (requires explicit confirmation to protect user edits)
* **Asynchronous Version Guards:** Stale AI generation responses are ignored if the user has edited scenes in the interim.

#### 🎨 Visual Sources & Built-in Procedural Library (Part C)
* **Visual Sources Configuration Panel:** Direct access in Video Template Studio to toggle and mix App URLs, Screenshots, Clips, Text, and the Built-in Visual Library.
* **Curated Procedural Palettes:** 8 modern gradient palettes (Midnight Indigo, Cyber Neon, Sunset Coral, Emerald Luxe, Royal Purple, Titanium Dark, Deep Ocean, Solar Amber).
* **Geometric Patterns & Motion Backdrops:** Procedural Dot Grid, Cyber Grid, Wave Flow, and Isometric Blueprint backdrops rendered directly on Canvas.
* **App Domain Vector Iconography:** 9 specialized vector icons (Productivity, Gaming, Finance, Health, Social, Education, Entertainment, Tools, Shopping).
* **Contextual Suggestion Engine:** Suggests optimal palettes, patterns, and icons based on app category and script semantics without fabricating fake app screenshots.

### 4. 🎬 ViMax Agentic AI Video Generation Engine Integration
Integrated directly with the open-source **[HKUDS/ViMax](https://github.com/HKUDS/ViMax)** agentic video-generation framework, providing automated transformation from website URLs, product descriptions, screenshots, images, and scripts into promotional videos:
* **Hybrid Agentic Architecture:** Flutter desktop frontend talks to a lightweight local Python REST API (`backend/app.py` on `127.0.0.1:8765`), orchestrating ViMax script/narrative planning, scene generation, speech synthesis, and FFmpeg encoding.
* **Support for All Input Types:**
  * *Public Website URLs:* Extracts website title, description, brand identity, key value propositions, logo, OpenGraph imagery, and page screenshots.
  * *Uploaded Screenshots & Images:* 1:1, 9:16, and 16:9 aspect ratios preserved; never stretched or distorted.
  * *Text Prompts & Descriptions:* Autonomously structured into high-converting storyboards.
  * *Existing Scripts:* Preserved with 100% meaning and facts; optional agentic polishing without silent overrides.
* **7 Supported Promotional Video Archetypes:**
  1. `saas_product_ad`: SaaS Product Advertisement
  2. `mobile_app_promo`: Mobile App Showcase
  3. `website_promo`: Website & Web App Promo
  4. `ecommerce_ad`: E-Commerce Product Advertisement
  5. `startup_pitch`: Startup & Pitch Promotional Video
  6. `feature_explainer`: Deep Feature Walkthrough & Explainer
  7. `cinematic_ad`: Cinematic Brand Advertisement
* **Asynchronous Background Job Manager (`ViMaxJobState`):**
  * Real statuses: `queued` → `preparing_inputs` → `generating_video_clips` → `assembling_video` → `processing_audio` → `validating_output` → `completed` (or `failed` / `cancelled`).
  * Live elapsed time, progress percentage, stage descriptions, and real-time streaming engine logs.
* **Real MP4 Rendering & Stream Verification:**
  * Genuine H.264 video and AAC audio encoding using Gyan.dev FFmpeg 7.1.
  * Automatic FFprobe inspection validates stream presence, exact dimensions, codec, duration, and non-zero byte size before reporting success.
* **Local Audio & Speech Synthesis:**
  * Windows Native SAPI Speech Synthesizer + Microsoft Edge-TTS fallback.
  * Procedural harmonic ambient chord audio synthesizer (pure Python `wave`/`struct` without external service limits).
* **Quota-Safe Personal Production (5 Videos/Day):**
  * Built for continuous personal promotional production at zero mandatory API cost.
  * Local procedural graphics and hardware-accelerated motion compositing ensure 100% offline functionality.
  * Optional external LLM/Image/Video providers (OpenAI, DeepSeek, Stability, Pika, Kling) can be configured in `backend/.env`.

### 5. AI & Cost Requirements: Zero Mandatory Subscriptions
* **100% Free Local Template & Procedural Engine (Default):** Runs completely offline without API keys or recurring costs.
* **Optional BYO AI Providers:**
  * **Google Gemini API (`gemini-2.0-flash`):** Uses your own Google AI Studio API key.
  * **Local LLM via Ollama (`http://127.0.0.1:11434`):** Runs private models (e.g. `llama3`) on local hardware.
  * **OpenAI (`gpt-4o`):** Optional BYO API key support.
* **Transparent Attribution:** Every generated post and campaign is tagged with its origin (`providerName`) in metadata.

### 6. Official Publishing Integrations & Safety
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
# 1. Fetch Flutter dependencies
flutter pub get

# 2. Start local ViMax AI Video Engine (Background Python REST API)
# Either double-click backend/start_backend.bat or run:
py backend/app.py

# 3. Run static analysis (verifies 0 errors & 0 warnings)
flutter analyze

# 4. Run automated test suite (75 passing tests including ViMax suite)
flutter test

# 5. Launch desktop application
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
