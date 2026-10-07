# Claude work history

Newest first. One entry per finished task (see CLAUDE.md → Work history).

### 2026-10-07 — Keep privacy policy & terms in sync with features
- Added a CLAUDE.md rule: after every feature, check whether it affects the privacy policy/terms and update all copies (`docs/privacy_policy.html`, `PAO_Privacy_Policy.txt`, in-app `privacy*`/`terms*` ARB strings, `docs/terms.html`, `docs/delete-account.html`) plus the "Last updated" date, and flag Play Console Data safety changes.

### 2026-10-07 — CLAUDE.md, work history and /release skill
- Added `CLAUDE.md`, this history file (imported into every session) and the `/release` skill (`.claude/skills/release/SKILL.md`).

### 2026-10-07 — Release 1.5.7+15 (first automated Play release)
- Committed the pending home redesign: category sections (`home_sections_provider.dart`), new `category_products_screen.dart`, l10n strings, updated `home_widgets_test.dart`. Commit `267b3e7`.
- Bumped `pubspec.yaml` to `1.5.7+15`, pushed tag `v1.5.7` → GitHub Actions run 37622056178 succeeded; AAB uploaded to Play production (pending Google review).
- Before release: `flutter analyze` (info-only), `flutter test` all 511 passed.
- Pending: `app_release.dart` version history not updated since 1.5.3.

### 2026-10-07 — Auto-publish to Google Play on tag
- Added `.github/workflows/play-release.yml` (commit `36b0f5b`): on `v*` tag, checks tag = pubspec version, builds signed AAB, uploads to Play production via `r0adkll/upload-google-play`. Manual run allows choosing the track.
- Created Google Cloud service account `github-play-publisher@pao-app-293f0.iam.gserviceaccount.com`, invited it in Play Console with release permissions.
- Added 7 GitHub Actions secrets: `ENV_FILE`, `GOOGLE_SERVICES_JSON`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`, `PLAY_SERVICE_ACCOUNT_JSON`.

## Earlier (from git log, before this history existed)
- 2026-10-06 — 1.5.6+14: keep saved profile name/photo on Google sign-in, fit nav labels.
- 2026-09-27 — 1.5.5+13: Google sign-in/sign-up, notification reply and chat crash fixes, faster start-up; restored single-token push registration.
- 2026-09-26 — About screen with version history, onboarding, chat safety, offline chat media, privacy policy update, GitHub Pages home page.
- 2026-09-22…24 — Realtime chat/requests/posts, pagination, push notifications, chat redesign, photo/video/voice messages, donors tab, Hive caching.
- 2026-09-19 — English/Urdu localization, password-reset screen, unit/widget/integration tests.
