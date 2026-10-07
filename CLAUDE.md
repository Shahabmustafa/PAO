# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Talking to the user

- The user writes in Roman Urdu; reply in Roman Urdu, keeping code, commands and file names in English.

## Work history

@.claude/history.md

- After finishing any task that changes files, commits, releases or external setup, append an entry to `.claude/history.md` (newest at the top) and commit it with the related work. Format: `### YYYY-MM-DD — <title>` then 2–5 bullets: what was done, key files, commit hash / tag, anything left pending.
- Keep entries short. When the file passes ~40 entries, fold the oldest into the "Earlier" section as one line each.
- Do not volunteer a history summary at session start. Summarize it only when the user asks (e.g. "pichla kaam batao").

## Local secret files (gitignored, never commit)

- `.env` (loaded as a Flutter asset by `flutter_dotenv`; keys in `.env.example`)
- `android/app/google-services.json`, `android/key.properties`, `android/app/upload-keystore.jks`
- `supabase/` — SQL scripts live only locally; run them by hand in the Supabase SQL editor.
- The user saves screenshots / WhatsApp images into the repo root. Never stage or commit `*.png` / `*.jpeg` from the root; use explicit paths with `git add`, never `git add -A` / `git add .`.

## Code

- Feature-first: `lib/features/<feature>/{data,domain,presentation}`; shared code in `lib/core/`. State management is Provider.
- Every user-facing string goes in both `lib/l10n/app_en.arb` and `lib/l10n/app_ur.arb`. Generated `lib/l10n/app_localizations*.dart` are committed — run `flutter gen-l10n` after editing the ARB files and commit the output.
- Tests run offline against fakes in `test/helpers/fakes.dart` and `test/helpers/test_app.dart`; no Supabase needed. Run `flutter analyze` and `flutter test` before committing.

## Releasing

- Version lives in `pubspec.yaml` as `x.y.z+build`; the build number must increase on every Play upload.
- Pushing tag `vx.y.z` runs `.github/workflows/play-release.yml`, which builds a signed AAB and uploads it to the Play **production** track. The tag must equal pubspec's `x.y.z`. Secrets come from GitHub Actions secrets. Use `/release`.
- The in-app "About → version history" list is `lib/features/settings/domain/app_release.dart` with `c<ver>*` strings in both ARB files.
- Google sign-in on Play builds needs the Play App Signing SHA-1 registered on the Android OAuth client.
