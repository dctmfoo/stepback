# StepBack — Product Requirements Document

**Version:** 1.0
**Date:** 2026-07-10
**Status:** Approved for implementation
**Audience:** The implementation agent building this app. Read this document fully before writing any code.

---

## 0. Required reading & ground rules for the implementation agent

1. **Read [DESIGN.md](DESIGN.md) and [design/ui-spec.html](design/ui-spec.html) after this document.** This PRD defines *what* to build; DESIGN.md defines *how it looks and feels*; ui-spec.html is the canonical screen-by-screen layout reference. On layout, ui-spec.html wins; on tokens/rules, DESIGN.md wins.
2. **Survey current Apple documentation before locking API choices** (SwiftUI, SwiftData, CloudKit, AVFoundation/AVSpeechSynthesizer, Swift Concurrency clocks). Use the `apple-platform-think` skill for API grounding and `swiftui-design-principles` for UI work; use `web-search-plus` when current-web verification is needed.
3. **Product philosophy — "simple always works":** the entire reason this app exists is that setting up a workout must never feel like a chore that makes the user skip the workout. Every screen, every flow, every decision is judged by one question: *does this reduce the friction between "I should work out" and "I am working out"?* When in doubt, cut scope, not quality. Simple does **not** mean plain or boring — the bar is award-winning design and UX built from very few concepts.
4. **The core promise is hands-free:** the user starts a routine, leans the iPad against the wall, steps back, and just follows. Nothing in the player may ever require walking to the device mid-routine. This promise drives the exercise model (§6.1), the audio design (§6.4), and the across-the-room legibility rules in DESIGN.md.

---

## 1. Problem statement

Workout apps fail in two opposite ways: hardcoded programs that don't fit ("Day 3: Full Body Power Boost"), or interval timers so abstract that setting one up is itself a chore. The user knows which movements they want; they need a place to compose them into a routine **once**, and then a player that runs the whole thing hands-free while the iPad leans against the wall.

**One-line product definition:** A private routine builder and hands-free workout player — compose routines from a workout gallery once, then press play and step back.

---

## 2. Goals and non-goals

### Goals (must ship)

- G1. A **workout gallery**: a generous built-in catalog of individual workouts (movements) organized by category, searchable, browsable, with a lightweight detail view per workout.
- G2. **Custom workouts**: the user can add their own workout with a name, category, and optional notes, and it appears in the gallery alongside built-ins.
- G3. A **routine builder**: pick workouts from the gallery into an ordered routine; per step configure work time, number of sets, rest between sets, an optional rep-guidance label, and rest after the step; reorder freely; see the live computed total duration while editing; name and save.
- G4. A **saved-routines home**: every routine with its glanceable motivating stats — total duration, workout count, when it was last done, how many times it has been completed — and a play affordance directly on the list.
- G5. A **hands-free live player**: press play, put the device down, follow along. Huge across-the-room timer, current workout name, set progress, what's next, overall progress; automatic advancement through every segment; pause/skip/back for the rare intervention; screen stays awake; a completion summary at the end.
- G6. **Audio cues**: spoken announcements (workout names, "Rest", halfway/last-set style cues) plus countdown beeps and transition tones, so the user doesn't need to stare at the screen. Voice and tones independently toggleable in Settings.
- G7. **Session history & motivating stats**: every play-through is recorded; the app surfaces last-done, completion counts, weekly active minutes, and a day streak — glanceable, never a dashboard.
- G8. **iPad-first, everywhere-equal**: designed for iPad (especially landscape, propped against a wall) but fully first-class on iPhone and as a native Mac app.
- G9. **CloudKit private-database sync**: routines, plans, custom workouts, and history sync across the user's devices via their private iCloud. No accounts, no server, zero network calls except CloudKit.
- G10. **Simple, relevant onboarding**: one welcome screen and pre-seeded starter routines so the first session can start within seconds of first launch.
- G11. **Media-ready architecture**: v1 shows workout *names* only, but the data model, catalog format, gallery cards, workout detail, and player layout all reserve first-class slots for photos/video loops per workout, so adding media later is a content task plus one rendering component — never a redesign. See §4.7 and DESIGN.md.
- G12. **Localization-ready from day 1**: English-only UI at launch, but every user-facing string lives in the String Catalog and all durations/dates/numbers use Foundation formatters, so adding a language later is a pure translation task.
- G13. **Mac-hosted agent authoring bridge**: coding agents can read a fresh manifest and, only after conversational approval, create or edit custom workouts, routines, and seven-day weekly plans through app-validated file drops, including selecting a plan as My Week. External processes never touch the SwiftData store; deletion is not part of the protocol.

### Non-goals (explicitly out of scope — do not build)

- Progressive overload, adaptive prescription, or generated programming. Routines and plans are user-composed; the app never prescribes.
- Calorie estimates or any body metrics. Without HealthKit and body data any kcal number would be fabricated — show honest time-based stats instead.
- HealthKit integration, Apple Watch app, Home Screen widgets, and Live Activities / Dynamic Island — all deferred (§11); the architecture must not preclude them.
- Rep-counting via camera/ML, form feedback, or AI coaching of any kind.
- Exercise instruction videos/photos as shipped *content* in v1 (the *architecture* for them is G11; producing media is deferred).
- Social features, sharing, leaderboards, or challenges.
- Accounts, sign-in, subscriptions, or any third-party service. **Zero network calls except CloudKit sync.**
- Music playback or music-service integration (the player must coexist politely with whatever the user is already playing — §6.4).
- Android, web, watchOS.
- Awards/badge systems and charts. The streak and counts are the motivation surface; no trophy cabinets, no graphs.
- Calendar-date scheduling, missed/catch-up states, and plan reminders. Weekday buckets are authored schedule structure, not date anchoring.
- Shipping translated UI languages beyond English in v1 (readiness per G12; translations deferred).

---

## 3. Platform & technical foundation

| Decision | Value | Rationale |
|---|---|---|
| Platforms | iPadOS + iOS + native macOS, 26.0+ | iPad-first per the product concept; iPhone and Mac equal-quality peers; Mac is native SwiftUI, never Catalyst |
| Language | Swift 6, strict concurrency | House standard |
| UI | SwiftUI, `@Observable` main-actor view models | House standard |
| Persistence | SwiftData with CloudKit mirroring (private database) | Routines, custom workouts, session history sync across devices |
| Built-in workout catalog | Versioned bundled data table (JSON resource), **not** SwiftData | Adding/editing catalog workouts is a data change, never a schema migration; see §4.1 |
| Player timing | A pure, deterministic timeline compiler + a clock behind a protocol | The player engine is the heart of the app and must be fully unit-testable without wall-clock time; see §6.2 |
| Audio | System speech synthesis (AVSpeechSynthesizer or current equivalent) + short generated/system tones, behind a protocol | No bundled voice assets; testable with a fake; see §6.4 |
| Screen wake | Idle timer disabled while the player runs | The wall-propped iPad must never sleep mid-routine |
| Localization | String Catalog (`Localizable.xcstrings`), Foundation `FormatStyle` / `Duration` formatting | Day-1 readiness per G12 |

**CloudKit constraints the data model must respect** (verify against current SwiftData/CloudKit docs): all relationships effectively optional with inverses, no `.unique` constraints, every attribute optional or defaulted. Design the schema for these from day one — retrofitting is painful.

**Multiplatform layout strategy:** one SwiftUI codebase; size-class-driven layout, never device-type branches. iPad and Mac get multi-column browsing (split view) and the landscape player stage; iPhone gets the same screens in compact form. The player is designed landscape-first for iPad (§5.6) and adapts to portrait and compact rather than the reverse.

### 3.1 Internationalization readiness (day-1 architecture requirement)

1. Every user-facing string lives in `Localizable.xcstrings` from the first commit — including VoiceOver labels, empty states, spoken audio-cue templates (§6.4), and plural variants for counts ("3 sets", "12 workouts"). No user-facing string literals in view code.
2. Built-in workout and category names are **catalog data with localization keys** (§4.1), so translating the catalog is also a pure translation task.
3. Durations, dates, and numbers always use Foundation formatters (`Duration.UnitsFormatStyle`, relative date formatting for "2 days ago") — never hand-assembled strings.
4. Never concatenate sentence fragments; use format strings with placeholders. Layout is RTL-safe by construction: leading/trailing only, SF Symbols, standard stacks, Dynamic Type.

---

## 4. Data model

Six persisted entities plus one bundled catalog. Keep it this small.

### 4.1 Built-in workout catalog (bundled data, not SwiftData)

A versioned JSON resource in the app bundle. One entry per built-in workout:

| Field | Type | Notes |
|---|---|---|
| `id` | String | Stable ASCII identifier, e.g. `squat`, `mountain-climber`. Never renamed. |
| `nameKey` | String | String-catalog key for the localized display name |
| `categoryID` | String | One of the category IDs below |
| `focusAreas` | [String] | Zero or more focus-area IDs (e.g. `core`, `glutes`) for detail-view chips and future filtering |
| `mediaKey` | String? | Reserved slot for future photo/video association (G11). Nil for all v1 entries. |
| `instructionsKey` | String? | Reserved for future how-to text. Nil in v1. |

**Categories** are a fixed, ordered set with stable IDs, localized name keys, an SF Symbol, and a hue token (see DESIGN.md): `full-body`, `core`, `arms-shoulders`, `chest-back`, `legs-glutes`, `cardio`, `mobility-stretch`, `balance`. Categories are product metadata like Intelli-Expense's category catalog — adding one is a data + design-token change, not new code paths.

**Catalog size:** ship with a genuinely useful catalog (target ≥ 80 workouts across the eight categories) so the gallery feels like "a ton of workouts" on day one. Catalog content is a data-authoring task; the format above is the contract.

The catalog carries a `catalogVersion`; routines reference workouts by `id` string, so catalog updates in app updates are safe. A referenced `id` missing from a future catalog must still render via the step's name snapshot (§4.3) — never crash, never show a blank.

### 4.2 `CustomWorkout` (SwiftData)

User-created gallery entries (G2).

| Field | Type | Notes |
|---|---|---|
| `id` | String | Stable UUID string synced across devices; never mutated |
| `name` | String | Required in UX (validated in UI; optional-with-default in schema for CloudKit) |
| `categoryID` | String | One of the fixed category IDs; default `full-body` |
| `notes` | String? | Optional |
| `createdAt` | Date | |

Custom workouts appear in the gallery inside their category, marked subtly as the user's own. Deleting one that routines still reference is allowed; affected steps keep working via their name snapshot (§4.3).

### 4.3 `Routine` and `RoutineStep` (SwiftData)

| `Routine` field | Type | Notes |
|---|---|---|
| `id` | String | Stable UUID string synced across devices; never mutated |
| `name` | String | e.g. "Morning Core" |
| `createdAt` / `updatedAt` | Date | |
| `seedIdentifier` | String? | Starter-routine key for deterministic cross-device duplicate cleanup; nil for user-created routines |
| `steps` | [RoutineStep] | To-many, inverse `RoutineStep.routine`, ordered by `sortIndex` |

Derived (computed, never stored): total duration, workout count, category mix.

| `RoutineStep` field | Type | Notes |
|---|---|---|
| `sortIndex` | Int | Explicit ordering; reindex on reorder |
| `workoutID` | String | Built-in catalog `id` or the custom workout's identifier |
| `workoutNameSnapshot` | String | Denormalized display name captured at add time — resilience against catalog changes and deleted custom workouts |
| `workSeconds` | Int | Duration of one set. Whole seconds, **never** floating point |
| `sets` | Int | ≥ 1, default 1. ("Bridge — 3 repetitions" in the user's vocabulary = 3 sets) |
| `setRestSeconds` | Int | Rest between sets of this step, default 0 (e.g. "10 seconds reset in between") |
| `restAfterSeconds` | Int | Rest after the step, before the next one, default 0 |
| `repGuidance` | Int? | Optional target-rep label (e.g. "~20 reps") shown in builder and player. Guidance only — never drives timing (§6.1) |
| `routine` | Routine? | Inverse |

### 4.4 `RoutineSession` (SwiftData)

One row per play-through; the raw material for every stat in the app.

| Field | Type | Notes |
|---|---|---|
| `routine` | Routine? | Optional relationship; sessions of a deleted routine keep the name snapshot |
| `routineNameSnapshot` | String | |
| `startedAt` | Date | |
| `endedAt` | Date? | Set on finish or abandon |
| `wasCompleted` | Bool | True only if the final segment finished |
| `completedStepCount` / `totalStepCount` | Int | Partial-session honesty |
| `activeSeconds` | Int | Work + set-rest + between-step rest actually elapsed (excludes paused time) |
| `planIDSnapshot` / `planNameSnapshot` | String? | Optional immutable context when launched from a plan; no relationship required |
| `planWeekIndex` / `planSlotIndex` | Int? | Legacy CloudKit-compatible fields retained inert; weekly plans do not write cursor positions |

### 4.5 `Plan` and `PlanSlot` (SwiftData)

Plans are user-authored repeating weeks: seven absolute weekday buckets, each with an ordered list of zero or more routines. An empty bucket is a rest day. Display order follows the user's locale first weekday; there are no calendar dates, prescriptions, or missed-workout states.

| `Plan` field | Type | Notes |
|---|---|---|
| `id` / `name` | String | Stable identifier and user-visible name |
| `createdAt` / `updatedAt` | Date | |
| `isActive` | Bool | Stored My Week selection marker; at most one plan is selected |
| `weeklyScheduleVersion` | Int | Idempotent authored-data migration version; defaults to the current weekly shape |
| `isRepeating` / `weekCount` | Bool / Int | Legacy fields retained for CloudKit compatibility; new writes use `false` / `1` |
| cursor fields / `completedSlotCount` / `isComplete` | mixed | Legacy fields retained inert; weekly progress is never stored |
| `slots` | [PlanSlot] | Optional CloudKit-safe relationship with cascade delete |

| `PlanSlot` field | Type | Notes |
|---|---|---|
| `weekIndex` / `sortIndex` | Int | `weekIndex` is legacy and written as zero; `sortIndex` orders routines within a weekday |
| `routine` | Routine? | Nullifies if the routine is deleted |
| `routineID` / `routineNameSnapshot` | String | Preserves authored intent and display after routine deletion |
| `weekdayLabelIndex` | Int? | Absolute Calendar weekday (`1...7`); the authored bucket assignment |

Today's plan state is derived at read time from completed `RoutineSession` rows by local calendar day and routine ID. Duplicate same-routine slots require duplicate completed sessions. Abandoned sessions never count; no cursor, skip, or completion lifecycle is persisted.

### 4.6 Derived stats (computed, never stored)

- **Per routine:** last done (relative date), times completed, total active minutes.
- **Global:** current day streak (consecutive calendar days with ≥ 1 completed session, computed in the user's current calendar/time zone) and this week's active minutes.
- Streak and weekly minutes live on the Routines home as one compact strip (§5.2); no other aggregation ships in v1.

### 4.7 Media-readiness contract (G11)

The commitment that makes "photos/videos later" cheap:

1. `mediaKey` exists in the catalog format (§4.1) from day 1.
2. Every place a workout is visually represented — gallery card, workout detail, builder row, player stage — renders through **one shared `WorkoutVisual` component** that today resolves to the monogram placeholder tile defined in DESIGN.md, and later resolves `mediaKey` → image/video. Feature code never asks "is there media?"; it asks the component to render the workout.
3. Layouts reserve the media region now (aspect ratios per ui-spec.html) so screens don't reflow when media arrives.

---

## 5. Navigation & screens

**Three tabs, one modal flow (builder), one full-screen stage (player).**

```
TabView (iPhone/iPad) · NavigationSplitView-appropriate equivalent (Mac)
├── Tab 1: Routines  (home — My Week Today card, motivation strip, saved routines, week management row)
├── Tab 2: Gallery   (the workout library, categories + search)
└── Tab 3: Settings
+ Routine Builder  — sheet/flow from either tab
+ Plan Editor       — sheet from the Routines home or plan detail
+ Live Player      — full-screen cover, owns the device
```

### 5.1 First-run onboarding (one screen + seeded content)

Onboarding does exactly two things: say what the app is, and get the user inside fast. One welcome screen — app icon, one line ("Build your routine once. Then press play, step back, and follow."), three short illustrated bullets (Compose → Play → Follow), a privacy footnote ("No accounts. Your routines sync only to your private iCloud."). Single button: **Get Started**.

On first launch the app seeds **three starter routines** (short/medium/long, built only from catalog workouts, defined as data alongside the catalog) so the Routines home is never an empty dead end and the first play-through can happen within seconds. Starter routines are ordinary user routines after seeding: editable, deletable, no special casing. Onboarding-seen state is local (`@AppStorage`), never in CloudKit; seed at most once per install, and only when the store has no routines at all, so CloudKit-synced content wins over re-seeding. Cross-device duplicates from sync races are removed by a deterministic pristine-copy dedupe sweep keyed by the starter identifier; edited or played copies are never deleted.

### 5.2 Tab 1 — Routines (home)

- When a My Week plan exists, a prominent **Today** card leads the home with today's first unfinished routine, compiled duration, a seven-day schedule strip, and one Play action. Completed sessions derive done state at read time; rest days show the next planned day, and removed routines offer Fix in Editor. There is no Skip, Restart, or plan-completion state.
- A quiet row beneath the routine list is the single plan-management entry: **My Week · name**, **Choose Your Week**, or **Plan Your Week**. The overview shows seven locale-ordered day rows; the picker handles multiple plans; the editor is a fixed seven-day form with visible Rest buckets. The first saved plan becomes My Week automatically, and other plans offer **Set as My Week**.
- Routine cards, most recently played first: name, total duration, workout count, small category-mix glyphs, **last done** ("2 days ago"), **times completed**, and a prominent inline **Play** affordance — play must be one tap from app launch. Before a routine has any session, its stats line reads **"Not played yet"** rather than inventing or implying activity.
- A compact **motivation strip** above the list appears once the first session has been recorded: current day streak and this week's active minutes. One line, two numbers, no charts (§4.6). It stays hidden before that first session so day-one users never see a shame-shaped row of zeroes.
- Tap card → **Routine detail:** the step list exactly as it will play (workout name, per-set time × sets, set-rest, rest-after rows in sequence), total duration as the hero number, per-routine stats line, **Play** as the primary action, Edit and Duplicate and Delete as secondary actions. Duplicate exists because copying-then-tweaking a routine is the natural way to iterate.
- Delete confirms; sessions of a deleted routine survive in history (§4.4).
- Empty state (only possible if the user deletes the starters): invitation to build or **restore any missing starter routines as fresh copies**. Restore inserts only starters whose seed identifier is absent, so the action is idempotent and never overwrites an existing starter.

### 5.3 Tab 2 — Gallery

- The full workout library: category sections (or category grid entry points on compact), search across all workouts, custom workouts inline within their categories with an "Add your own" affordance.
- **Workout detail** (lightweight, one screen): media slot (placeholder tile in v1 — §4.7), name, category, focus-area chips, notes for custom workouts, and **Add to routine** (choose an existing routine or start a new one). Custom workouts are editable/deletable here.
- The gallery is a *library*, not a queue: browsing never mutates a routine until the user explicitly adds.

### 5.4 Routine builder

The make-or-break screen for the "never a chore" promise (§0.3). Reached from Routines ("New Routine", Edit) and from Gallery ("Add to routine → New routine").

- **Structure:** name field; ordered step list; each step row shows the workout name, its timing summary ("30s × 3 · 10s between sets"), optional rep guidance, and the rest-after value rendered *between* rows as its own quiet row — the on-screen list reads exactly like the user's mental script (see the sample routine below).
- **Adding:** an always-visible **Add Workouts** affordance opens a gallery picker (category chips + search + multi-select) so several workouts can be added in one pass; new steps land with smart defaults (30s work, 1 set, no set-rest, 15s rest-after — the previous step's values become the defaults for the next add within a session, because routines are rhythmic).
- **Per-step editing:** tapping a step opens inline/expanded controls for work seconds, sets, set-rest seconds, rep guidance, rest-after seconds. Duration controls are steppers/wheels with sensible increments (5s), never free-text keyboards.
- **Reorder:** standard drag handles; rest-after values travel with their step.
- **Live total:** the computed routine duration is always visible and updates with every change — the user calibrates a "40-minute routine" while composing.
- Save validates one thing only: at least one step and a non-empty name (suggest a default name). Everything else has defaults; there is no way to build an "invalid" routine.

The canonical sample routine (from the product owner) that the builder and player must express naturally:

> Bridge — 30 seconds, 3 sets with 10 seconds rest between sets · then 15s rest ·
> Squats — 30 seconds, 2 sets · then 15s rest ·
> Russian twist — 30 seconds · then 20s rest ·
> Bicycle crunch — 30 seconds (~20 reps guidance) · then 20s rest ·
> Mountain climbers — 30 seconds.

### 5.5 Live player (the product's signature — invest UX here)

Full-screen cover; the device becomes a wall-side coach. Designed landscape-iPad-first; portrait and compact adapt.

- **Pre-roll:** a "Get ready" segment (default 5s, configurable in Settings) with the first workout announced by voice, so the user has time to step back.
- **Work segment:** giant countdown (the screen's single hero element — legible from 3–4 meters, see DESIGN.md across-the-room rules), workout name, set indicator ("Set 2 of 3"), optional rep guidance line, media region (placeholder tile in v1), a thin overall-progress bar with elapsed/remaining, and **next up** ("Next: Squats") in the final seconds.
- **Rest segments** (set-rest and between-step rest): visually distinct calm state (rest hue per DESIGN.md), countdown, and what's coming next as the primary text — rest is when the user looks at the screen.
- **Controls:** pause/resume, skip forward, back (restart current segment; twice = previous segment), and end-routine (confirms). Oversized tap targets — controls are used from arm's length in motion, occasionally mid-sweat. On Mac: space = pause, arrows = skip/back.
- **Completion:** a celebratory but calm summary — routine name, active minutes, workouts completed, updated streak/times-completed — with **Done** and **Go again**. A partial session that ends early records honestly (§4.4) and shows a smaller acknowledgment, never a guilt trip.
- Screen never sleeps while the player is active (§3). Rotation is free on iPad; the layout adapts rather than locks.

### 5.6 Tab 3 — Settings

Minimal: voice announcements toggle, countdown/transition tones toggle, get-ready duration, iCloud sync status line, privacy statement ("No accounts. Everything stays in your private iCloud."), app version. No account, no sign-in, no premium.

### 5.7 UX quality bar (applies everywhere)

- Native-feeling SwiftUI: standard navigation, Dynamic Type, dark mode, VoiceOver labels on every control, haptics on save/complete (iPhone/iPad), sensible input affordances (steppers/wheels for durations, never free-text seconds).
- Empty states for every list with a helpful next action; every failure state designed (sync unavailable, catalog-id missing); no dead spinners, no raw errors.
- Follow the `swiftui-design-principles` skill; verify against ui-spec.html before calling UI work done.

---

## 6. The player engine (functional requirements)

### 6.1 Exercise model — everything is time-based (industry-standard decision)

Research across Seven, Freeletics, Nike Training Club, and interval-timer design guidance (July 2026) established: hands-free circuit players are **time-driven**; apps with rep-*driven* items require a manual tap to advance, which breaks the step-back promise. StepBack therefore adopts the Seven model, confirmed by the product owner:

- Every step is time-based: `workSeconds × sets` with `setRestSeconds` between sets.
- Rep counts exist only as **guidance labels** (`repGuidance`, "~20 reps"): shown in the builder and player, spoken once at segment start if voice is on, never driving advancement or timing.
- The player never waits for input. Pause/skip exist for intervention; advancement is always automatic.

### 6.2 Timeline compilation (deterministic core)

The routine compiles to a flat, immutable **timeline** of segments before play begins: `getReady → [work(set 1) → setRest → work(set 2) → …] → restAfter → …` with zero-duration segments omitted. Each segment carries its type (work / setRest / rest / getReady), duration, owning step, set index, and next-workout attribution for "next up" display and announcements.

- Compilation is a pure function: routine in, timeline out — unit-tested against the sample routine in §5.4 and edge cases (single step, sets=1, all rests zero, trailing rest omitted: a routine never ends on a rest).
- The runner advances through the timeline on a clock injected behind a protocol; tests drive a fake clock deterministically through pause, resume, skip, back, abandonment, and completion.
- Elapsed/remaining math is integer seconds end-to-end. The displayed total on routine cards, in the builder, and in the player is the same compiled number — one source of truth.

### 6.3 Interruptions & lifecycle

- App resigns active mid-routine → the session auto-pauses and preserves position; returning resumes at the paused segment (with a fresh 3-2-1 tone). No progress is ever lost to backgrounding, an incoming call, or a crash-free relaunch mid-pause.
- Audio interruptions (call, Siri) pause the session.
- Abandonment (user ends early, or the app is killed while paused) records an honest partial `RoutineSession` (§4.4).

### 6.4 Audio design

- **Voice announcements** (system speech synthesis): workout name at each work-segment start (with set position when sets > 1), "Rest" with next-workout name at rest starts, and completion. Templates are string-catalog entries (§3.1).
- **Tones:** 3-2-1 countdown beeps at the end of every segment and a distinct work-start tone. Short, generated or system-provided — no bundled audio assets.
- Voice and tones are independent Settings toggles; both on by default.
- **Coexistence with music:** the user is likely playing their own music. Cues must duck/mix politely (audio-session category chosen accordingly and verified against current AVFoundation guidance) — the app never stops the user's music, and silence-switch behavior follows fitness-timer convention (cues audible during an active session).
- Every audio call sits behind a protocol with a deterministic fake; cue *scheduling* is part of the tested timeline runner, so "beep at T-3s" is a unit test, not a manual QA hope.

---

## 7. Stats & motivation requirements

- Stats exist to answer exactly three glanceable questions: *When did I last do this? How consistent am I? How much have I moved this week?* — via the per-routine lines (§4.6), the motivation strip, and the completion summary.
- The streak counts **days with ≥ 1 completed session** in the user's current calendar; it must handle time-zone changes gracefully (compute from local calendar days at read time, never store a counter).
- Honest by construction: only `wasCompleted` sessions count toward times-completed and streak; partial sessions still contribute active minutes to the weekly total.
- No goals, no targets, no shame states. A broken streak simply shows the new number.

## 8. Non-functional requirements

- **Privacy:** all data on-device + the user's private iCloud; zero third-party calls, zero analytics. State it in Settings and onboarding.
- **Timer integrity:** segment transitions accurate within perceptual tolerance (≤ 150 ms drift per segment, no cumulative drift across a session — recompute from the timeline and a monotonic reference, never chain `Timer` callbacks).
- **Performance:** app cold-launch to Routines home < 1s on target devices; play tap → pre-roll < 300 ms; gallery scrolls smoothly with the full catalog + custom workouts.
- **Reliability:** a mid-routine crash or force-quit never corrupts data; the in-flight session is recorded as abandoned on next launch.
- **Testing:** unit tests for timeline compilation (§6.2), the runner via fake clock (pause/skip/back/complete), streak and weekly-minute math (including time-zone and week-boundary cases), catalog decoding + missing-id resilience, and seeding idempotency. UI tests for build-routine → play → complete happy path and the builder's reorder/edit flows. Audio and clock behind protocols with fakes (§3).
- **Code shape:** feature-folder structure; pure logic (timeline compiler, stats math, catalog) in a local Swift package with its own test target; services behind protocols; `@Observable` view models; no singletons for testable logic.

## 9. Acceptance criteria (definition of done)

1. First launch: welcome screen → Get Started → Routines home shows three starter routines; tapping Play on one reaches the pre-roll in under two taps total from the home.
2. Build the §5.4 sample routine in the builder in under two minutes: multi-select Bridge, Squats, Russian Twist, Bicycle Crunch, Mountain Climbers from the picker; configure sets/rests per the sample; reorder one step; the live total matches the hand-computed sum; save.
3. Play the sample routine end-to-end hands-free: every segment advances automatically, voice announces each workout and rest, 3-2-1 beeps precede every transition, next-up appears during rests and final work seconds, and the screen never sleeps.
4. From 3 meters away, the current countdown, workout name, and work-vs-rest state are unmistakable on an iPad in landscape (verified per DESIGN.md across-the-room rules) in both light and dark rooms.
5. Pause from the player, background the app, return: the session resumes exactly where it paused. Take a phone call mid-routine on iPhone: the session is paused when the call ends.
6. Complete the routine: the summary shows correct active minutes and counts; the routine card now shows "Today" and an incremented times-completed; the streak strip updates. Completing another session the same day does not double the streak.
7. End a routine halfway: history records an honest partial session; times-completed does not increment; weekly minutes include the partial active time.
8. Add a custom workout ("Wall Sit", Legs & Glutes); it appears in the gallery and the builder picker; build and play a routine containing it; delete the custom workout; the routine still displays and plays via the name snapshot.
9. Edit a saved routine (change a work time, remove a step, reorder); the card total updates; play reflects the edit.
10. Create a first weekly plan and assign a routine to today: saving immediately shows the Today card with Play and the week strip. Completing that routine from any entry point marks today done; a rest day needs no acknowledgement; a second plan switches only through Set as My Week.
11. Second device on the same iCloud account: routines, weekly plans, My Week selection, custom workouts, and history appear; starter seeding does not duplicate.
12. VoiceOver completes build → play → complete; the app is fully usable in dark mode and at large Dynamic Type sizes (player hero timer follows its documented scaling exception in DESIGN.md).
13. Mac: browse, build, and play with keyboard controls (space pause, arrows skip/back); the player is a proper resizable stage, not a stretched phone screen.
14. The codebase contains no user-facing strings outside the String Catalog and renders correctly under pseudolocalization; all durations/dates formatted via Foundation formatters.

## 10. Shipped extension and open items intentionally deferred

The Mac app ships an app-owned Agent Bridge for Claude Code and Codex authoring. It is a local file-drop surface under Application Support: the app publishes a read-only manifest, validates create/update commands plus My Week selection, persists through its own SwiftData/CloudKit container, and writes machine-readable outcomes. Plan payloads contain seven absolute weekday buckets; `activatePlan` means Set as My Week, and the retired `deactivatePlan` verb is rejected explicitly. It exposes no delete verb, server, socket, model execution, session creation, or iOS/iPadOS host. Packaged skills require an explicit conversational go-ahead before writing to the inbox.

The following remain deferred and must not be built without asking:

- Workout media (photos/video loops) — architecture ships in v1 (§4.7); content production and the media-rendering component are a follow-up spec.
- HealthKit workout logging; Apple Watch remote/companion; Home Screen widgets; Live Activities / Dynamic Island.
- Workout instructions/how-to text in the detail view (`instructionsKey` reserved).
- Routine sharing/export, Shortcuts/App Intents ("Start Morning Core"), and Siri phrases.
- Calendar-date scheduling, adaptive programming, and reminders/notifications for plans. Weekday assignment inside a repeating week is shipped authoring, not date scheduling.
- Translated UI languages beyond English (must cost only: translate the String Catalog including catalog keys, then localized QA — if it costs more, G12 was violated; fix the architecture, not the estimate).
