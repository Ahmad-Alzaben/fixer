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
