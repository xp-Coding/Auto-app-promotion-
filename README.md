# AppGrowth Studio

> **Free, Local-First AI-Powered Google Play App Promotion & Social Media Marketing Studio for Windows Desktop**

AppGrowth Studio is a production-oriented Flutter Windows desktop application built specifically for Android developers and independent software publishers to promote their own applications published on the Google Play Store.

---

## Key Pillars

1. **100% Free Core Architecture:** Zero subscriptions, zero mandatory cloud databases, and zero required paid API keys.
2. **Local-First SQLite Persistence:** All registered apps, campaign plans, keyword research, media assets, and queued jobs are stored locally in an ACID-compliant SQLite database.
3. **Organic Growth Focus:** Built for genuine app discovery, legitimate installs, and authentic audience engagement across YouTube, Facebook, Instagram, and TikTok.
4. **Resilient Desktop Engineering:** Built using pure Dart libraries and direct FFI to avoid Windows symlink privilege requirements.

---

## Implemented Architecture & Milestone 1 Deliverables

* **Desktop Navigation Shell:** 13-section responsive sidebar navigation with collapse/expand, active app switcher, and dark/light themes.
* **SQLite Core Engine:** Versioned schema (`DatabaseMigrations`) defining all 16 tables with foreign keys and lookup indexes.
* **My Apps Module:**
  * Register, edit, archive, and delete Google Play applications.
  * Automatic package name extraction from Play Store URLs.
  * Reverse-DNS package name validation.
  * Real-time **Listing Quality Score** evaluator (0–100%) against Google Play guidelines.
  * Interactive feature & USP tag editors.
  * Browser launch integration for public Play Store listings.
* **Real-Data Dashboard:** Direct SQLite aggregation for app counts, connected accounts, drafts, queue jobs, and first-run guidance.
* **Automated Verification:** 11 comprehensive unit, repository, and widget tests passing with 0 lint warnings.

---

## Project Structure

```
d:/Ai promo/
├── lib/
│   ├── main.dart                               # Application entry point & theme provider
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart               # SQLite connection provider & WAL config
│   │   │   ├── migrations.dart                 # Version 1 schema (16 tables & indexes)
│   │   │   └── sqlite_initializer.dart         # Multi-fallback Windows FFI DLL loader
│   │   ├── theme/
│   │   │   └── app_theme.dart                  # Material 3 slate dark and crisp light themes
│   │   └── utils/
│   │       ├── url_launcher.dart               # Desktop browser URL launcher
│   │       └── validators.dart                 # Play Store URL & Listing Quality evaluators
│   └── features/
│       ├── apps/
│       │   ├── models/app_model.dart           # App domain model with JSON mapping
│       │   ├── repositories/app_repository.dart# SQLite CRUD & search repository
│       │   ├── providers/app_providers.dart    # Riverpod state notifiers & filter state
│       │   └── presentation/
│       │       ├── apps_screen.dart            # Apps grid, search, filter & card widgets
│       │       ├── app_form_dialog.dart        # App registration modal with live scoring
│       │       └── app_details_dialog.dart     # Metadata view & campaign angle suggestions
│       ├── dashboard/
│       │   ├── data/dashboard_repository.dart  # Real SQLite metrics queries
│       │   └── presentation/dashboard_screen.dart # KPI cards & workflow cards
│       └── shell/
│           └── desktop_shell.dart              # Responsive sidebar & top navigation shell
├── test/
│   ├── app_repository_test.dart                # SQLite database and CRUD integration tests
│   ├── sqlite_test.dart                        # Windows FFI loader verification
│   ├── validators_test.dart                    # Play Store URL and quality scoring tests
│   └── widget_test.dart                        # Desktop shell smoke tests
├── PROJECT_AUDIT.md                            # Comprehensive project audit report
├── ARCHITECTURE.md                             # Architectural blueprint & module specifications
├── DATABASE_SCHEMA.md                          # Full SQLite schema documentation
└── CHANGELOG.md                                # Release history and milestone progress
```

---

## Running the Application

### Prerequisites
* Flutter 3.47+ (Dart 3.13+)
* Windows 10/11 64-bit

### Commands
```bash
# Get dependencies
flutter pub get

# Run static code analysis
flutter analyze

# Run all automated tests
flutter test

# Run the Windows desktop application
flutter run -d windows
```
