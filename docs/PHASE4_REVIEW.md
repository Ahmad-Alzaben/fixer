# Phase 4 review

Date: 2026-11-28 · 171 automated tests, analyzer clean · checked on a Pixel 9 emulator (Android 16).

## What was checked and how

| Area | How | Result |
|---|---|---|
| Touch targets ≥ 48dp, labelled buttons, text contrast | Flutter's `androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` on all 6 main screens (`test/widgets/accessibility_test.dart`) | Item rows were 40dp, **fixed** to 48dp. Everything else passes |
| 200% system font on a 320dp phone | Same screens with text scale 2.0 | Overflows on Split, Results, History, Reports, **fixed**. Also checked on the emulator at 200% |
| Very large amounts | Unit tests (`test/core/money/limits_test.dart`) | No upper limit existed; a pasted 23-digit number would overflow. **Fixed**: max 999,999,999 in parser and input field |
| Rounding, totals add up, never negative | Unit, property (5,000 random bills) and exhaustive tests from Phase 2 | Pass |
| Keyboard flow | Widget tests + emulator | Enter adds the next price/person and keeps focus; fee fields move to the next field |
| Async safety (screen closed mid-operation) | Code review against the flutter-dart-code-review checklist | 3 places used `setState`/`ref` after `await` without a `mounted` check, **fixed** |
| Database upgrade | Unit test + installing over the old version on the emulator | Saved bills kept; templates added |
| iOS readiness | See below | Ready to build on a Mac |

## Changes made
- `FitAmount` widget: amounts beside labels shrink instead of overflowing (person card, item rows, results breakdown, history, reports).
- Item rows 48dp tall.
- Amount limit of 999,999,999 (and a stricter input pattern; the first version let `1234567890` through, caught by the new test).
- `mounted` checks in tag creation, country-code field, contact number picker.
- iPad: the share sheet is anchored to the Share button (required on iPad, otherwise it crashes).

## iOS readiness
- `ios/` platform added; bundle id `com.amon.fixer`, display name "Fixer".
- `Info.plist`: contacts permission text (`NSContactsUsageDescription`) and `sms`/`whatsapp` link schemes.
- All packages used support iOS (drift + sqlite3_flutter_libs, flutter_contacts, share_plus, url_launcher, shared_preferences).
- **Not verified**: building and running on iOS needs a Mac with Xcode. Nothing in the code is Android-only.

## Known limitations (not bugs; decide if they matter)
1. **App icon / launch logo** is still Flutter's default; needs your icon.
2. **Custom tags** can't be renamed or deleted yet.
3. **Clearing all items** from a bill that was already saved leaves the last saved version in History (auto-save only saves bills with items). Delete it from History if needed.
4. **Only English** text; Arabic and right-to-left layout aren't set up.
5. **No screen-reader walkthrough** on a device (TalkBack). The automated label/target/contrast checks pass, but a manual TalkBack pass is still worth doing.
6. **Fonts** are the system font; a bundled "techy" font needs your OK (download).
