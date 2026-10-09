# System Architecture: AppGrowth Studio

## 1. Architectural Principles

1. **Local-First & Zero Operating Cost:**
   * SQLite is the single source of truth for all data.
   * No mandatory subscriptions, cloud databases, or paid APIs.
   * Core promotional generation works through customizable algorithmic templates even with zero internet or AI installed.
2. **Desktop Symlink Resilience on Windows:**
   * Does not depend on platform channels that require Windows Developer Mode or elevated privileges.
   * Uses pure Dart packages and direct Dart FFI for SQLite loading.
   * Resolves storage directories via standard `Platform.environment['APPDATA']`.
3. **Decoupled Layered Structure:**
   * **Core Layer:** Database connections, migrations, theme tokens, validators, desktop URL launching.
   * **Domain & Data Layer:** Immutable data models, parameterized repositories, and Riverpod state notifiers.
   * **Presentation Layer:** Material 3 responsive UI components, dialogs, form validation, and reactive streams.
   * **Integration Layer (Upcoming Milestones):** Independent social platform adapters conforming to `SocialPlatformAdapter`.

---

## 2. Navigation & Module Layout

The application employs a 13-section responsive sidebar shell:

```
[ Desktop Shell ]
  ├── 1. Dashboard             (Real SQLite metric cards & quick actions)
  ├── 2. My Apps               (Google Play app profiles & listing quality)
  ├── 3. Market Research       (Competitor metadata & topic clustering)
  ├── 4. Keyword Explorer      (Long-tail keyword discovery & intent mapping)
  ├── 5. Content Studio        (Platform-specific copy & scripts generation)
  ├── 6. Media Library         (Screenshots, banners, icons & local assets)
  ├── 7. Campaign Planner      (Multi-channel calendar & goal planning)
  ├── 8. Publishing Queue      (Persistent SQLite job queue & retries)
  ├── 9. Social Accounts       (YouTube, Meta, TikTok adapters)
  ├── 10. Analytics            (Attribution metrics & snapshots)
  ├── 11. Automation Rules     (Local recurring triggers)
  ├── 12. Activity Logs        (Local audit trail without secret leaks)
  └── 13. Settings             (Local AI endpoint, database backup/restore)
```

---

## 3. SQLite Database Design & Isolation

* **Journal Mode:** Write-Ahead Logging (`WAL`) enabled for concurrent reads without UI locking.
* **Foreign Key Constraints:** `PRAGMA foreign_keys = ON;` strictly enforced with cascading deletions for clean relation cleanup.
* **Security & Privacy:** API credentials and OAuth refresh tokens are isolated from ordinary plain-text fields and handled with Windows DPAPI/secure storage abstractions.
