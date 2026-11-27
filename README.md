# Fixer

Split a shared bill fairly. Each person enters their items; service fee, delivery fee and discount are shared in proportion to what each person ordered, and the per-person amounts always add up exactly to the bill total.

Flutter app, Android first (iOS-ready structure). Dark, cyberpunk-inspired theme with selectable accent colors. Works offline.

<p>
  <img src="docs/screenshots/split-entry.png" width="240" alt="Bill entry">
  <img src="docs/screenshots/results.png" width="240" alt="Results">
  <img src="docs/screenshots/settings-accent.png" width="240" alt="Accent colors">
</p>

## Status
- ✅ Calculation engine: integer minor units, largest-remainder rounding, fully tested ([rounding rule](docs/ROUNDING.md))
- ✅ Bill entry, live totals, results, copy & share, accent colors
- ⏳ History, categories/tags, contacts, per-person WhatsApp/SMS messages, monthly reports

## Run
```sh
flutter pub get
flutter test
flutter run
```

## Structure
```
lib/
  core/       money (Money, Currency, allocation), theme, shared widgets
  features/   bill, results, messaging, settings: each split into domain / application / data / presentation
test/         unit tests for money + domain, widget tests for the main flow
docs/         brief, plan, rounding rule, screenshots
```
