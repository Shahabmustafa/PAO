---
name: release
description: Release a new app version to Google Play — bump pubspec version, test, commit, push a vX.Y.Z tag and watch the GitHub Actions upload. Usage: /release 1.5.8
disable-model-invocation: true
---

Release version `$ARGUMENTS` (if empty, bump the patch number of the current pubspec version).

1. Read `version:` in `pubspec.yaml`. New version = `<x.y.z>+<current build + 1>`. Confirm the tag `v<x.y.z>` does not already exist (`git tag -l`, `git ls-remote --tags origin`).
2. Run `flutter analyze` (stop on any error/warning) and `flutter test` (stop on any failure). Report failures to the user instead of releasing.
3. Show the user `git status --short` and ask which uncommitted changes belong in this release. Never stage root-level `*.png` / `*.jpeg` screenshots; stage explicit paths only.
4. Update `pubspec.yaml`. If the user wants the in-app changelog updated, add an `AppRelease` to the top of `lib/features/settings/domain/app_release.dart` with matching `c<ver>*` strings in `app_en.arb` and `app_ur.arb`, then `flutter gen-l10n`.
5. Commit with a message describing the user-visible changes, suffixed with `(<x.y.z>+<build>)`. Push `main`, then `git tag v<x.y.z>` and `git push origin v<x.y.z>`.
6. Watch the run: `curl -s "https://api.github.com/repos/Shahabmustafa/PAO/actions/runs?per_page=1"` (run in background, poll until `status` is `completed`). On failure, fetch the job steps (`.../runs/<id>/jobs`) and tell the user which step failed.
7. Add an entry to `.claude/history.md` and commit it.
