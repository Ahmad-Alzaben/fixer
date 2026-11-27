# CLAUDE.md: Shared Bill Splitter

Flutter app, Android first, iOS later. Source of truth: `docs/BRIEF.md`, `docs/PHASE1_PLAN.md`, and the owner's later design references and decisions (those override both docs).

## Project rules (override any skill or generic guideline)

- **Money is never `double`.** Integer minor units only. (Some examples in `dart-flutter-patterns` use `double` for prices. Don't copy that.)
- Calculation code in `lib/core/money/` and every `domain/` folder is pure Dart: no Flutter or plugin imports.
- Totals are derived from bill data, not stored (unless a documented cache is approved).
- Split mode per bill: **equal** (default for new bills) or **proportional** (bills saved before v1.0.3 load as proportional). Equal discount never exceeds what a person owes.
- Rounding: largest remainder applied **per adjustment column** (service, delivery, discount). Ties go to the person listed first. Every row and column must add up exactly in minor units. Discount is weighted by subtotal + fee shares so nobody goes negative. Full rule: `docs/ROUNDING.md`.
- Monthly report counts only the share of the person marked "Me". Bills can have several category tags.
- Theme: dark only, preset accent colors only, cyberpunk-*inspired* (no game logos, fonts, names or art).
- Local-first: no backend, auth, analytics, Crashlytics/Sentry, or network calls unless the owner asks. Ignore those parts of `flutter-dart-code-review` and `dart-flutter-patterns` (Dio, auth guards, crash reporting).
- Don't add packages without checking compatibility with Flutter 3.35 / Dart 3.9 and saying why. Freezed is not approved.
- Work in the phases in the brief. End each phase with: what changed, what's complete, what remains, decisions needed.

## Skills in `.claude/skills/`
- `test-driven-development`: required for `core/money` and all domain logic (the brief asks for calculation tests before UI).
- `systematic-debugging`: for any failing test or bug.
- `verification-before-completion`: run `flutter test` / `flutter analyze` and read the output before claiming anything passes.
- `dart-flutter-patterns`, `flutter-dart-code-review`: Flutter idioms and review checklist, subject to the rules above.

## Current state (handoff)
- **Released:** v1.0.3 (all phases of the brief done, plus icon, CI/CD, release signing). Repo: `github.com/Ahmad-Alzaben/fixer` (public). Owner tests on a OnePlus Nord CE 3 Lite (arm64) and a Samsung.
- **Owner decisions so far:** JOD 3 decimals; new bills split fees/discount **equally**, per-bill switch to **by order**; several tags per bill; reports = owner's "Me" share only; several message templates, exactly one default; dark only, preset accents.
- **Open items / known limitations:** `docs/PHASE4_REVIEW.md` (tag rename/delete, Arabic/RTL, TalkBack pass, bundled font, iOS needs a Mac + Apple account for signed builds).

## How to work on this repo
- **Verify:** `flutter analyze` and `flutter test` (189+ tests). Database tests use Windows' built-in `winsqlite3.dll` via `test/support/test_database.dart`; CI installs `libsqlite3-dev`.
- **Bugs:** reproduce first with a failing test in `test/widgets/regressions_test.dart` (or a unit test), then fix. Widget tests use `test/support/app_harness.dart` (`pumpApp`, fakes for storage, contacts, sharing, launcher). IDs in tests are `id0` (bill), `id1`… in creation order.
- **Database (Drift 2.28, pinned by Flutter 3.35's analyzer):** after changing tables run `dart run build_runner build --delete-conflicting-outputs`, bump `schemaVersion` (now 3), add an `onUpgrade` step, and add an upgrade test that starts from a realistic old database (see `test/data/*`). Rows are sync-ready: UUID ids, `updatedAt`, soft delete via `deletedAt`.
- **Commits:** only when the owner asks ("commit and push"). Never stage `android/key.properties`, `*.jks`, `*.apk`, `*.ipa`, `release/`.

## Releasing
- Bump `version:` in `pubspec.yaml` (the name, e.g. `1.0.4+5`; CI sets the build number to 100 + run number so every APK updates the previous one).
- Push to `main` → `.github/workflows/release.yml` runs tests, builds signed Android APKs (arm64 + universal) and an **unsigned** iOS `.ipa`, and publishes GitHub Release `v<version>-build.<n>`. Watch with `gh run watch` (`C:\Program Files\GitHub CLI\gh.exe`; logged in as Ahmad-Alzaben).
- Signing: upload key at `C:\Users\Asus\.android-keys\fixer-upload.jks`; CI reads it from repo secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`. Local release builds use the owner's git-ignored `android/key.properties`: **never open or print it**.
- Checking a signature: `apksigner verify --print-certs` (needs `JAVA_HOME` = `C:\Program Files\Android\Android Studio\jbr`; the system `JAVA_HOME` on this PC points to a missing `jre` folder). Expected signer: `CN=Fixer, O=Fixer`.

## Emulator testing
- AVD `Pixel_9` (`flutter emulators --launch Pixel_9`); adb at `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.
- The installed Fixer is release-signed: install **release** builds over it (`flutter build apk --release`); a debug build needs an uninstall first.
- 3-button navigation (like the owner's Samsung) is enabled via the `navbar.threebutton` overlay. Some Samsung inset bugs don't reproduce on the emulator; regression tests simulate them (`tester.view.viewInsets`).
- Icon source: `docs/icon/fixer-icon.svg` (original design); regenerate all sizes with `docs/icon/make_icons.ps1`.

## Behavioral guidelines
*(From the andrej-karpathy-skills `CLAUDE.md`, lightly trimmed.)*

These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think before coding
Don't assume. Don't hide confusion. Surface tradeoffs.
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them; don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity first
Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical changes
Touch only what you must. Clean up only your own mess.
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it; don't delete it.
- Remove imports/variables/functions that YOUR changes made unused. Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-driven execution
Define success criteria. Loop until verified.
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```
