# Phase 1 — Clarify & Plan

Status: **waiting for approval**. No application code has been written.
Source of truth: [`BRIEF.md`](BRIEF.md) plus the additional requirements below. Later design references and architecture decisions from the owner override this document.

Toolchain found: Flutter 3.35.3 (stable), Dart 3.9.2, Windows dev machine.

---

## 1. Requirements summary

### From the brief
- Android-first Flutter app, iOS-ready later. Local-first, offline, no backend/auth.
- Workflow: add people → add items (price required, description optional) → enter service fee / delivery fee / discount → see each person's share.
- **Proportional allocation** of fees and discount by item subtotal.
- Money in **integer minor units** (never `double`). Currency configurable, default **JOD**.
- Person totals must sum **exactly** to the bill total; remainder distributed deterministically.
- No negative inputs; warn when discount exceeds what can be discounted; no divide-by-zero.
- Results: bill-level totals, per-person breakdown, prominent final amount.
- Copy + native Share of results.
- Calculation logic independent of UI, fully unit-tested **before** UI work.

### Additional requirements (from you)
| # | Requirement | Impact |
|---|---|---|
| A1 | Link phone **contacts** as people; send each person their amount with a **customizable message** (text before/after the amount / their itemized receipt) | Contacts permission, message templates, per-person send |
| A2 | **History** page of saved bills | Persistence is now in the MVP (answers the brief's open question) |
| A3 | **Categories** for bills (Food, Electronics, …) | Category model + management screen |
| A4 | **Monthly report** of spending, from history | Aggregation queries over saved bills |
| A5 | **Selectable theme accent colors**, dark-first, **inspired by Cyberpunk 2077** | Theme system with presets (answers the brief's dark-mode question) |
| A6 | Minimal, responsive UI | Small screens, large fonts, tablets |
| A7 | Design patterns + SOLID | See §4 |
| A8 | "Famous skills like ponytail" | **Not found** — see question Q10 |

Note on A5: colors and a general neon/HUD mood are fine; we will **not** use the game's logo, fonts, names, or artwork. The look is "inspired by", not a copy.

---

## 2. Rounding — worked example and a decision you need to make

Example from the brief: A = 2.45, O = 3.00, J = 1.65, service 0.70, discount 2.13 → total **5.67**.

**Algorithm (largest remainder / Hamilton method):**
1. Compute each person's exact share as a rational number (no floats): `final × personSubtotal / billSubtotal`.
2. Floor each to the minor unit.
3. Remainder = total − sum of floors (always 0 … n−1 units).
4. Give +1 unit to the people with the largest fractional parts; **ties go to the person listed first**.

Result at 2 decimals: exact shares 1.9565 / 2.3958 / 1.3177 → floors 1.95 / 2.39 / 1.31 (sum 5.65) → 2 units go to J (.77) then A (.65):

```
A: 1.96   O: 2.39   J: 1.32   = 5.67 ✔
```

The brief's illustrative output (A 1.96, O 2.40, J 1.31) also sums to 5.67 but does **not** follow largest remainder. That's fine since the brief marks it illustrative; just flagging it so the tests don't surprise you.

**Decision D1: where to apply rounding.**
- **Option A — round the final per person** (shown above). Person totals are as fair as possible. But the displayed breakdown lines (subtotal + service + delivery − discount) may be off by 0.01 from the final for some people.
- **Option B — round each adjustment column separately**, then final = subtotal + shares. Every row and every column adds up exactly on screen, but a person's final can be 1 minor unit away from Option A (in the example A becomes 1.95 and J 1.32).
- *Recommendation: **B**.* The arithmetic on screen always checks out, which matters when you're sending people their receipts. The difference is at most one minor unit per adjustment.

---

## 3. Open questions (essential only)

| # | Question | My default if you don't care |
|---|---|---|
| Q1 | **JOD precision**: 3 decimals (ISO standard, fils, e.g. `1.957`) or 2 decimals (like the brief's example)? | 3 internally (ISO), display setting for 2 or 3 |
| Q2 | **Rounding**: Option A or B above? | B |
| Q3 | **Monthly report: "how much I spent"** means (a) **my own share** only (needs a "Me" person in each bill), (b) the full bill totals, or (c) both? | (c): "My share" by default, toggle to "Total bills" |
| Q4 | **Categories**: one category per bill, several tags per bill, or per item? | One per bill (simplest, clean monthly totals). Default list + custom categories |
| Q5 | **Sending**: which channels? Android won't let an app send SMS silently without a restricted permission, so each send opens WhatsApp / SMS / the share sheet with the text prefilled and you tap Send. | WhatsApp + SMS deep links (contact's number) + generic share sheet |
| Q6 | **Message template**: one global template (editable in Settings) that you can tweak per send? Placeholders like `{name}`, `{amount}`, `{items}`, `{billTotal}`, `{title}`, `{date}`. | Yes: global template + edit before each send |
| Q7 | **Edge cases**: (a) fees with zero item subtotal → split equally among people? (b) discount larger than subtotal + fees → warn and cap final total at 0? | (a) equal split, (b) warn + cap at 0 |
| Q8 | **Currency**: per bill (stored with each bill) or app-wide only? If per bill, reports group totals by currency (never mix). | Per bill, default from Settings |
| Q9 | **Theme**: preset accents only, or presets + custom color picker? Should a light mode exist at all? | 4–5 presets, dark only for MVP |
| Q10 | **"Ponytail" skill**: I couldn't find a skill by that name in your catalog or in Claude Code. Did you mean something else (e.g. a design-system/UI skill, Tailwind, a Figma file)? Tailwind is web-only and doesn't apply to Flutter. | Proceed without it |
| Q11 | **App name + Android package id** (e.g. `com.yourname.billsplitter`)? | Working name "Splitr", `com.example.bill_splitter` until you decide |

Not added on purpose (tell me if you want them): payment status tracking (paid/unpaid), receipt photo/OCR, cloud sync, multiple payers.

---

## 4. Proposed architecture

### 4.1 Layering (feature-first, clean-ish, no over-abstraction)

```
lib/
  core/
    money/            Money, Currency, allocation & rounding (pure Dart, zero Flutter imports)
    theme/            AppTheme, accent presets, typography, spacing tokens
    utils/            formatting, ids, date helpers
    widgets/          shared minimal widgets (NeonCard, AmountField, ...)
  features/
    bill_editor/      domain / application / presentation
    results/          calculation display, copy & share
    contacts/         contacts gateway (adapter over plugin)
    messaging/        templates, renderer, send channels
    history/          list, reopen, duplicate, delete
    categories/       CRUD + defaults
    reports/          monthly aggregation + screen
    settings/         theme, currency, template, precision
  data/
    db/               database, tables, migrations
    repositories/     implementations of domain repository interfaces
  app.dart, router.dart, main.dart
test/
  core/money/         calculation tests (written first, Phase 2)
  features/...        use-case and widget tests
```

Each feature folder:
- **domain**: entities, value objects, repository *interfaces* (pure Dart).
- **application**: use cases / controllers that orchestrate domain + repositories.
- **presentation**: widgets and screen state.

Rule: `domain` and `core/money` never import Flutter or any plugin. That keeps the calculator testable with plain `dart test` and portable to iOS for free.

*Alternative:* put `core/money` in a separate local package (`packages/split_core`). That gives hard isolation enforced by the compiler but adds a little setup. I'd do this only if you want it.

### 4.2 Domain model (draft)

```
Bill        id, title?, categoryId?, currencyCode, createdAt, updatedAt,
            people[], serviceFee, deliveryFee, discount       (all Money)
Person      id, displayName, contactRef? {contactId, phone}, isMe, items[]
BillItem    id, description?, price (Money)
Category    id, name, iconKey, colorKey, isDefault
MessageTemplate  id, body (with placeholders)
BillCalculation  (derived, never stored) subtotal, fees, discount, total,
                 perPerson[{personId, subtotal, service, delivery, discount, final}],
                 warnings[]
MonthlyReport    (derived) month, currency, total, byCategory{}
```

Totals are **derived**, not stored, as the brief asks. For reporting speed we *may* cache `total` and `myShare` per saved bill, recomputed on save. I'll only do that if queries turn out slow, and I'll document it.

### 4.3 Design patterns & SOLID: where they actually earn their place

| Pattern | Where | Why |
|---|---|---|
| **Value Object** | `Money`, `Currency` | Immutable, minor-unit integer, currency-safe arithmetic |
| **Strategy** | `AllocationStrategy` (Proportional now; Equal later if wanted), `RemainderPolicy` (LargestRemainder) | Open/Closed: new split modes without touching the calculator |
| **Repository** | `BillRepository`, `CategoryRepository`, `SettingsRepository` | Dependency Inversion: domain depends on interfaces, DB is swappable |
| **Adapter** | `ContactsGateway` over the contacts plugin; `SendChannel` over WhatsApp/SMS/share | Isolate plugins, fake them in tests |
| **Template / Interpreter (small)** | `MessageTemplateRenderer` replacing `{placeholders}` | One responsibility; easy to test |
| **Factory** | `AppThemeFactory.fromAccent(preset)` | Builds a full `ThemeData` from one accent choice |

SOLID mapping: SRP (calculator ≠ formatter ≠ renderer ≠ repository), OCP (strategies), LSP (fakes interchangeable with real repos), ISP (small interfaces, e.g. `ContactsGateway` only exposes `pick()`/`search()`), DIP (use cases receive interfaces via DI).

What I will **not** do: generic base classes for everything, a use case class for every trivial getter, or event buses. Simple and maintainable over ceremony, per the brief.

---

## 5. State management options

| Option | Pros | Cons |
|---|---|---|
| **Riverpod** *(recommended)* | Built-in DI (fits DIP), great for **derived state** (live calculation = provider computed from bill state), testable without widgets, no `BuildContext` needed | One more concept to learn; avoid code-gen to keep it simple |
| **Bloc / Cubit** | Very explicit, popular in teams, strong conventions | More boilerplate; DI needs a second package (get_it) or `RepositoryProvider` |
| **Provider + ChangeNotifier** | Minimal, familiar | Weaker for derived/async state; easier to create tangled rebuilds as the app grows |
| **Plain `ValueNotifier` / `InheritedWidget`** | Zero dependencies | You end up re-building DI and scoping by hand |

## 6. Local storage options

Needs: relational data (bills → people → items), category filter, **monthly aggregation**, reactive history list.

| Option | Pros | Cons |
|---|---|---|
| **Drift (SQLite)** *(recommended)* | Typed queries, `GROUP BY month, category` in SQL, reactive streams, real migrations, mature, iOS-compatible | Code generation (`build_runner`) |
| **sqflite (raw SQL)** | No code-gen, simple | Manual mapping, stringly-typed queries, more bug surface |
| **Hive CE / key-value** | Very fast, simple | No relational queries; reports aggregated in Dart; migrations ad hoc |
| **Isar** | Fast, nice API | Original project abandoned; community fork risk |

Settings (theme accent, currency, template, precision) → **shared_preferences** behind `SettingsRepository`.

## 7. Routing
- **go_router** *(recommended)*: declarative, deep-link ready, bottom-nav shell via `StatefulShellRoute`.
- Plain `Navigator`: fine for 5 screens, zero deps, but tab state preservation is manual.

## 8. Other packages (versions verified against Flutter 3.35 before adding)
- `flutter_contacts`: read contacts (READ_CONTACTS permission, asked only when you tap "Add from contacts").
- `share_plus`: native share sheet. Clipboard is built into Flutter.
- `url_launcher`: `sms:` and WhatsApp (`https://wa.me/<number>?text=`) deep links.
- `intl`: currency/number/date formatting.
- `uuid`: ids.
- **No chart package**: the monthly report uses simple custom-drawn bars, in line with the brief's "avoid unnecessary charts".
- Fonts **bundled** (offline): e.g. *Rajdhani* or *Chakra Petch* for headings, *JetBrains Mono* for amounts (tabular digits). All OFL-licensed.

---

## 9. UI direction (until your references arrive)

**Navigation**: bottom bar with 4 tabs: **Split** (current bill) · **History** · **Reports** · **Settings**.

**Split screen (speed first)**
- People as compact cards: name/contact chip, running subtotal, items list.
- "Add person" → type a name *or* pick from contacts.
- Price field with numeric keyboard; **Enter adds the item and keeps focus** for the next price. Description optional and collapsed by default.
- Adjustments row (service / delivery / discount) collapsed into one line until tapped.
- **Sticky bottom bar** with the live total → opens Results.

**Results**: big final amount per person; breakdown in an expandable row; actions *Copy*, *Share*, *Send to each* (per-person message using the template); *Save to history* with title + category.

**History**: list grouped by month, filter by category, search by title; tap to reopen/edit, swipe or menu for duplicate/delete.

**Reports**: month selector, total spent, category breakdown with thin bars, month-over-month list.

**Theme (cyberpunk-inspired, minimal)**
- Near-black background `#0A0A0F`, surfaces `#12121A`, hairline borders, beveled (cut) corners on cards and buttons, monospace numbers.
- Accent presets (one is primary, others used sparingly):
  - *Neon Yellow* `#FCEE0A` (default)
  - *Electric Cyan* `#00F0FF`
  - *Hot Red* `#FF003C`
  - *Netrunner Magenta* `#FF2BD6`
  - *Acid Green* `#39FF14`
- Contrast-checked (WCAG AA) text on accent; no glow/glitch animations by default (brief: avoid decoration). Maybe one subtle accent underline.

Responsive: tested at 320dp wide (small Android), standard phones, and tablet (two-pane Split + Results ≥ 840dp). Respects system font scaling.

---

## 10. Phase plan (updated for your additions)

1. **Phase 1 (this document)**: approve or adjust architecture, answer Q1–Q11.
2. **Phase 2: calculation foundation**: `Money`, `Currency`, allocation, rounding, warnings; the brief's 14 test cases + example + property test "sum of shares == total" over random bills; message template renderer tests.
3. **Phase 3a: Android MVP core**: project scaffold, theme + accent presets, Split screen, Results, copy/share.
4. **Phase 3b: persistence & contacts**: Drift DB, History, Categories, contacts linking, per-person send.
5. **Phase 3c: Reports & Settings**: monthly report, template editor, currency/precision.
6. **Phase 4: review**: usability, a11y (TalkBack labels, contrast, font scale), keyboard behavior, validation, iOS readiness check (Info.plist contacts usage string, WhatsApp URL scheme query).

## Answers received (2026-11-27)
- Q3 Monthly report: **my share only** → each bill has exactly one person marked "Me".
- Q4 Categories: **several tags per bill** → many-to-many `bill_tags`. In the report a bill counts once in the month total and once in each of its tags, so the per-tag totals can add up to more than the month total (the report says so on screen).
- D1 / Q2 Rounding: **Option B**: every breakdown row and column adds up exactly.
- Q9 Theme: **preset accents only, dark mode only** for now.
- Q1 JOD: **3 decimals** (fils).
- Q5 Sending: **WhatsApp + SMS** (no generic share sheet for per-person sends; "Share results" from the brief stays).
- Q8 Currency: **per bill**, default from Settings; reports total each currency separately.
- Q10 Skills: installed (see `.claude/skills/SOURCES.md`).
- Future requirement: **local now, later upload/sync to a self-hosted database.** Build sync-ready from day one: UUID ids, `createdAt`/`updatedAt` on every row, soft delete (`deletedAt`), all data access behind repository interfaces. No sync code until requested.
- **Architecture approved:** Riverpod, Drift (sync-ready), go_router, feature-first folders.
- Q6 Templates: **several saved templates, exactly one marked default**. The default is preselected for every send; you can pick another or edit the text before sending.
- Q7 Edge cases: **fees with zero item subtotal split equally; discount larger than subtotal + fees → warning, total capped at 0**, nobody goes negative.
- Q11 App name: **Fixer** (store listing could read "Fixer – Split Bills" to stand out from other apps named Fixer). Dart package name: `fixer`. Android package id: owner gave `com.Amon.Fixer`; proposed lowercase `com.amon.fixer` (awaiting confirmation).

## Decisions needed from you
- [ ] Approve: **Riverpod**, **Drift**, **go_router**, feature-first layering
- [ ] D1 rounding (A or B)
- [ ] Answers to Q1–Q11 (or "use your defaults")
- [ ] Design references, if you have them, before Phase 3
