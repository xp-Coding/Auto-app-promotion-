# Database Schema Documentation: AppGrowth Studio

**Database Engine:** SQLite 3 (FFI with WAL mode)  
**Location:** `%APPDATA%/AppGrowthStudio/appgrowth_studio.db`  
**Current Migration Version:** 1

---

## Entity Relationship Overview

The schema is normalized to support full offline marketing management, campaign planning, job scheduling with retries, and metrics tracking without external cloud dependencies.

```
+--------------------+        +--------------------+
|       apps         |<-------|     app_media      |
+--------------------+        +--------------------+
          |
          | 1:N
          v
+--------------------+        +--------------------+
|     campaigns      |------->| campaign_platforms |
+--------------------+        +--------------------+
          |
          | 1:N
          v
+--------------------+        +--------------------+
|   content_posts    |<-------|     post_media     |
+--------------------+        +--------------------+
          |
          | 1:N
          v
+--------------------+        +--------------------+
|     post_jobs      |------->|   post_attempts    |
+--------------------+        +--------------------+
          |
          v
+--------------------+
|  published_posts   |
+--------------------+
```

---

## Table Definitions

### 1. `apps`
Stores registered Google Play applications and their marketing profiles.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | Unique UUID identifier |
| `name` | TEXT | NOT NULL | Application title |
| `package_name` | TEXT | NOT NULL UNIQUE | Android package identifier (e.g. `com.studio.app`) |
| `play_store_url` | TEXT | NOT NULL | Canonical Google Play URL |
| `icon_path` | TEXT | NULL | Local icon file path |
| `category` | TEXT | NOT NULL | Play Store category |
| `short_description`| TEXT | NULL | Short marketing summary (max 80 chars) |
| `full_description` | TEXT | NULL | Complete Play Store description |
| `main_features` | TEXT | NULL | JSON array of feature strings |
| `unique_selling_points` | TEXT | NULL | JSON array of USP strings |
| `target_audience` | TEXT | NULL | Target demographic persona |
| `target_countries`| TEXT | NULL | JSON array of country codes (e.g. `["US","GB"]`) |
| `supported_languages` | TEXT | NULL | JSON array of language codes |
| `brand_tone` | TEXT | NULL | Preferred tone (e.g., Informative, Energetic) |
| `preferred_cta` | TEXT | NULL | Call-to-action string |
| `website_url` | TEXT | NULL | Support or marketing website URL |
| `privacy_policy_url`| TEXT | NULL | Public privacy policy URL |
| `is_archived` | INTEGER | NOT NULL DEFAULT 0 | 1 = Archived, 0 = Active |
| `created_at` | TEXT | NOT NULL | ISO-8601 UTC timestamp |
| `updated_at` | TEXT | NOT NULL | ISO-8601 UTC timestamp |

*Indexes:*
* `idx_apps_package` on `apps(package_name)`
* `idx_apps_archived` on `apps(is_archived)`

---

### 2. `app_media`
Local media assets associated with an app.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | Unique UUID |
| `app_id` | TEXT | NOT NULL, FK -> `apps(id)` ON DELETE CASCADE | Target application |
| `file_path` | TEXT | NOT NULL | Local filesystem path |
| `media_type` | TEXT | NOT NULL | `icon`, `screenshot`, `banner`, `video` |
| `title` | TEXT | NULL | Descriptive title |
| `tags` | TEXT | NULL | Comma-separated search tags |
| `created_at` | TEXT | NOT NULL | ISO-8601 UTC timestamp |

---

### 3. `social_accounts`
Stores connected platform profiles (YouTube, Facebook, Instagram, TikTok).

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | Unique UUID |
| `platform` | TEXT | NOT NULL | `youtube`, `facebook`, `instagram`, `tiktok` |
| `account_name` | TEXT | NOT NULL | Channel/Page display name |
| `account_id` | TEXT | NOT NULL | Remote platform identifier |
| `profile_picture_url`| TEXT | NULL | Avatar URL |
| `status` | TEXT | NOT NULL | `connected`, `disconnected`, `expired`, `restricted` |
| `connected_at` | TEXT | NOT NULL | Connection timestamp |
| `last_synced_at`| TEXT | NULL | Last sync timestamp |
| `capabilities` | TEXT | NULL | JSON array of supported operations |
| `metadata_json` | TEXT | NULL | Non-sensitive account metadata |

---

### 4. `campaigns`
Marketing campaigns defined per application.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | Unique UUID |
| `app_id` | TEXT | NOT NULL, FK -> `apps(id)` ON DELETE CASCADE | Associated app |
| `name` | TEXT | NOT NULL | Campaign name |
| `objective` | TEXT | NOT NULL | Marketing goal (e.g. app launch, feature update) |
| `target_audience` | TEXT | NULL | Campaign persona override |
| `target_country` | TEXT | NULL | Primary country focus |
| `language` | TEXT | NULL | Content language |
| `start_date` | TEXT | NULL | ISO-8601 date |
| `end_date` | TEXT | NULL | ISO-8601 date |
| `status` | TEXT | NOT NULL DEFAULT 'draft' | `draft`, `active`, `paused`, `completed` |
| `posting_frequency`| TEXT | NULL | Frequency string |
| `content_themes`| TEXT | NULL | JSON array of theme strings |
| `notes` | TEXT | NULL | User notes |
| `created_at` | TEXT | NOT NULL | ISO-8601 UTC |
| `updated_at` | TEXT | NOT NULL | ISO-8601 UTC |

---

### 5. `campaign_platforms`
Platform targets for each campaign.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | Unique UUID |
| `campaign_id` | TEXT | NOT NULL, FK -> `campaigns(id)` ON DELETE CASCADE | Parent campaign |
| `platform` | TEXT | NOT NULL | Target platform |

---

### 6. `keywords`
Discovered and saved keywords and topic ideas.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | Unique UUID |
| `app_id` | TEXT | NOT NULL, FK -> `apps(id)` ON DELETE CASCADE | Associated app |
| `keyword` | TEXT | NOT NULL | Keyword or phrase |
| `topic_cluster` | TEXT | NULL | Topic group |
| `intent` | TEXT | NULL | `informational`, `commercial`, `navigational`, `transactional` |
| `relevance_score`| REAL | NOT NULL DEFAULT 0.0 | Qualitative score (0.0 to 100.0) |
| `source` | TEXT | NOT NULL | `manual`, `youtube_public`, `generator` |
| `retrieval_date`| TEXT | NOT NULL | Retrieval timestamp |
| `notes` | TEXT | NULL | Notes |
| `created_at` | TEXT | NOT NULL | ISO-8601 UTC |

---

### 7. `research_sources`
Tracks public competitor or reference research material.

---

### 8. `content_posts`
Generated or drafted promotional copy and scripts.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | Unique UUID |
| `app_id` | TEXT | NOT NULL, FK -> `apps(id)` ON DELETE CASCADE | Target application |
| `campaign_id` | TEXT | NULL, FK -> `campaigns(id)` ON DELETE SET NULL | Associated campaign |
| `target_platform`| TEXT | NOT NULL | Target network |
| `title` | TEXT | NULL | Post or video title |
| `body_text` | TEXT | NOT NULL | Caption, post copy, or script |
| `hashtags` | TEXT | NULL | Space-separated hashtags |
| `script_hook` | TEXT | NULL | Video opening hook |
| `cta_link` | TEXT | NULL | App URL or UTM tracking link |
| `format` | TEXT | NOT NULL | `caption`, `video_script`, `story`, `reel`, `carousel` |
| `status` | TEXT | NOT NULL DEFAULT 'draft' | `draft`, `ready`, `scheduled`, `published` |
| `created_at` | TEXT | NOT NULL | ISO-8601 UTC |
| `updated_at` | TEXT | NOT NULL | ISO-8601 UTC |

---

### 9. `post_media`
Media files attached to specific content posts.

---

### 10. `post_jobs`
Persistent SQLite job queue for reliable publication and task execution.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | Unique UUID |
| `campaign_id` | TEXT | NULL | Associated campaign |
| `content_id` | TEXT | NOT NULL, FK -> `content_posts(id)` ON DELETE CASCADE | Content to publish |
| `target_platform`| TEXT | NOT NULL | Target platform |
| `scheduled_at` | TEXT | NOT NULL | Scheduled execution timestamp (UTC) |
| `status` | TEXT | NOT NULL DEFAULT 'pending' | `pending`, `running`, `succeeded`, `failed`, `manual_required`, `cancelled` |
| `retry_count` | INTEGER | NOT NULL DEFAULT 0 | Number of attempts made |
| `max_retries` | INTEGER | NOT NULL DEFAULT 3 | Upper retry bound |
| `next_retry_at` | TEXT | NULL | Timestamp for next retry with backoff |
| `last_attempt_at`| TEXT | NULL | Last execution attempt |
| `last_error_code`| TEXT | NULL | Error category code |
| `last_error_message`| TEXT | NULL | Human-readable sanitized message |
| `created_at` | TEXT | NOT NULL | Creation timestamp |
| `updated_at` | TEXT | NOT NULL | Update timestamp |

---

### 11. `post_attempts`
Execution audit trail for every job attempt.

---

### 12. `published_posts`
Records successfully published posts with remote IDs and permalinks.

---

### 13. `metric_snapshots`
Time-series metric recordings (views, likes, clicks, shares) with data source attribution.

---

### 14. `automation_rules`
Configurable rules for recurring scans and automated scheduling.

---

### 15. `activity_logs`
Bounded local audit logging without credential leaks.

---

### 16. `application_settings`
Key-value storage for desktop preferences (theme, timeouts, local AI endpoint).
