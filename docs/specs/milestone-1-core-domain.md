# Spec: Milestone 1 — Core domain (StepBackCore, TDD)

**Status:** Implemented
**Owner screens:** none (no UI ships in this milestone). Owner files: `StepBackCore/Sources/StepBackCore/` (new `Catalog/`, `Timeline/`, `Stats/` feature folders replacing `StepBackCorePlaceholder.swift`), `StepBackCore/Tests/StepBackCoreTests/` (new test suites), `StepBackCore/Tests/StepBackCoreTests/Fixtures/` (trimmed catalog JSON fixtures), `PLAN.md` (Milestone 1 status line)
**Docs this spec amends:** none. No UI pattern, screen, or user-facing string ships; `DESIGN.md` and `design/ui-spec.html` are untouched. PLAN.md status flips follow the standard workflow, not a docs amendment.

**Branch:** `codex/milestone-1-core-domain`. Implementer flips this spec to Status: Implemented and PLAN.md Milestone 1 to `in progress` in the opening commit / `gate passed YYYY-MM-DD (<short-hash>)` in the closing commit.

---

## 1. Problem

The repo builds and tests green but contains no product logic. Everything after this milestone leans on three pure subsystems that PRD §3 requires to be deterministic and UI-free: the versioned catalog format (PRD §4.1), the routine → timeline compiler and clock-driven runner (PRD §6.2, the heart of the app), and the derived-stats math (PRD §4.5/§7). PLAN.md Milestone 1 mandates TDD inside `StepBackCore` with a gate of `swift test` green and no UI or wall-clock dependency.

## 2. Goals

- G1. **Catalog decoding:** a decoder for the bundled catalog JSON format — `catalogVersion`, category list, workout entries (`id`, `nameKey`, `categoryID`, `focusAreas`, `mediaKey?`, `instructionsKey?`), and starter-routine definitions — exercised against trimmed fixtures.
- G2. **Timeline compiler:** pure function from a routine value snapshot (+ get-ready duration) to a flat, immutable segment timeline, verified against the PRD §5.4 sample routine and the edge-case table below.
- G3. **Timeline runner:** deterministic play/pause/resume/skip/back/complete/abandon over a compiled timeline, driven by an injected clock with a test fake; audio-cue *scheduling* (announcement points, work-start tone, T-3/2/1 beeps) emitted as events through protocols with fakes and asserted in tests.
- G4. **Stats math:** pure functions over session value snapshots — current day streak, this-week active minutes, per-routine aggregates (last done, times completed, total active minutes) — with time-zone-change and week-boundary tests.
- G5. Every duration in every API is **integer seconds** (PRD §6.2); the compiled timeline's total is the single number later surfaced on cards, builder, and player.

## 3. Non-goals

- No SwiftData models, no persistence, no CloudKit — Milestone 2. Core types are plain value types; `StepBackCore` never imports SwiftData, and the compiler/stats functions take *snapshots* so M2's models adapt to core, not vice versa.
- No full catalog content and no starter-routine authoring (≥ 80 workouts is Milestone 2 data work). This milestone ships the *format contract* and trimmed test fixtures only; no production catalog JSON resource is added yet.
- No audio playback, no speech, no `AVFoundation` — Milestone 5. This milestone defines the cue-scheduling *events* and sink protocols with fakes; making sound is out of scope.
- No UI, no view models, no strings in `Localizable.xcstrings` (nothing user-facing ships; spoken announcement *templates* are UI strings owned by the Milestone 5 spec per PRD §3.1/§6.4).
- No settings storage: the get-ready duration is a compiler *input*; where it is stored (`@AppStorage`, Settings screen) is Milestone 5/6 work.
- Checked against PRD §2 non-goals: nothing here adds programs, rep-driven advancement, calories, or network surface — the runner is time-based by construction (PRD §6.1).

## 4. Design decisions

- **D1. Clock abstraction: the runner is generic over the Swift standard-library `Clock` protocol — no bespoke clock protocol.** Verified in the offline docset: `protocol Clock<Duration> : Sendable` (`/documentation/swift/clock`, iOS 16.0+/macOS 13.0+) provides `now`, `sleep(until:tolerance:)`, and the `.continuous`/`.suspending` instances — exactly the "clock behind a protocol" PLAN.md requires, already `Sendable` for Swift 6 strict concurrency. Tests use a manually-advanced test clock conforming to `Clock` inside the test target. Production (Milestone 5) passes `ContinuousClock`, satisfying PRD §8's "monotonic reference" rule; app-suspension handling is the lifecycle layer's job (PRD §6.3 auto-pauses on resign-active), so continuous-vs-suspending semantics never silently skip workout time. Rejected alternative: a custom `ClockProviding` protocol — it would duplicate a stdlib abstraction, need its own `Sendable` story, and make the fake harder to reuse.
- **D2. Two-layer runner: a pure synchronous state core plus a thin clock-driving loop.** The state core is a deterministic function of (timeline, ordered command/tick history) → (current segment, remaining seconds, elapsed/active accounting, emitted cue events); it never touches a clock. The driver owns the injected `Clock`, sleeps until the next boundary computed **from absolute offsets in the compiled timeline** (never chained per-tick timers — PRD §8's no-cumulative-drift rule), and forwards boundary crossings to the state core. Tests exercise the state core directly for exhaustive semantics and the driver via the fake clock for scheduling. Rejected alternative: a single async actor mixing sleeping and state — harder to test exhaustively and couples semantics to task scheduling.
- **D3. Cue scheduling is timeline data, not runner improvisation.** Compilation attaches to each segment its cue schedule: an announcement event at offset 0 (work: workout name + set position when sets > 1 + rep guidance presence; rest/set-rest: rest with next-workout attribution; getReady: first workout; completion event at timeline end), a work-start tone at each work segment's offset 0, and countdown beeps at T-3/2/1. The runner *emits* these events at their offsets through two protocols (announcement sink, tone sink) implemented by fakes in tests and by real speech/tone services in Milestone 5. Events carry semantic payloads (workout name snapshot, set index/count, next-up name) — never display or spoken strings, which are localized at the UI layer (PRD §3.1). This makes "beep at T-3s" a unit test (PRD §6.4) and keeps every user-facing string out of core.
- **D4. Countdown-beep clipping rule: a beep is scheduled only at whole-second offsets strictly greater than 0 from segment start.** A 3-second segment gets beeps at T-2/1 only (offset 0 belongs to the segment's announcement/tone); a 1-second segment gets none; a 2-second rest gets T-1 only. Deterministic, testable, and prevents a beep colliding with the start announcement. Rejected alternative: suppressing all beeps on short segments — loses the transition warning the hands-free promise depends on (PRD §0.4).
- **D5. Timeline shape (PRD §6.2 verbatim):** `getReady → [work(set 1) → setRest → work(set 2) → …] → restAfter → …` with zero-duration segments omitted and the final step's `restAfterSeconds` always omitted — a routine never ends on a rest. Each segment carries: type (`getReady`/`work`/`setRest`/`rest`), duration (Int seconds), absolute start offset (Int seconds), owning step identity (step index, `workoutID`, `workoutNameSnapshot`), set index/count, and next-workout attribution (the name snapshot of the next work segment's workout, nil on the last). Absolute offsets make elapsed/remaining pure subtraction and give the driver its sleep deadlines (D2).
- **D6. Compiler and stats inputs are core-defined value snapshots** (routine: name + ordered steps with the PRD §4.3 step fields; session: `startedAt`, `endedAt`, `wasCompleted`, `completedStepCount`, `totalStepCount`, `activeSeconds` per PRD §4.4). Milestone 2's SwiftData models will map to these snapshots at the persistence boundary. Rationale: keeps `StepBackCore` free of persistence imports and makes every test a struct literal. Rejected alternative: protocols the models conform to — heavier, and CloudKit-forced optionality would leak into core.
- **D7. Empty or degenerate routines never crash: an empty step list compiles to an empty timeline (total 0), and the runner treats an empty timeline as immediately completed.** The "at least one step" rule is builder validation (PRD §5.4), not a core precondition — core stays total-function pure so a future data bug degrades gracefully (mirrors the §4.1 never-crash posture).
- **D8. Catalog decoding is strict; runtime resilience lives at the routine layer.** The bundled catalog is first-party data shipped with matching code, so malformed JSON, an unknown `categoryID`, or a duplicate workout `id` fails decoding loudly — a test/authoring error caught before ship, never silently repaired. The PRD §4.1 missing-id resilience contract is honored where it actually bites: routines reference workouts by `id` string and every step carries `workoutNameSnapshot`, so a catalog lookup returning nil still renders and plays. The decoder exposes lookup by `id` returning an optional; compilation depends only on the step snapshot, and a test proves a routine referencing a nonexistent `id` compiles and runs fully. Unknown JSON *keys* are ignored (forward compatibility for future format additions).
- **D9. Categories decode from the catalog JSON as an ordered array with stable IDs** (`full-body`, `core`, `arms-shoulders`, `chest-back`, `legs-glutes`, `cardio`, `mobility-stretch`, `balance` — PRD §4.1), each entry carrying `id`, `nameKey`, and `symbolName`. Hue tokens stay app-side: DESIGN.md binds hue to category via the asset-catalog sets already shipped in Milestone 0 (`Category*` colorsets), and core must not know about colors. Decoding validates exactly this eight-ID set in this order — the set is fixed product metadata, so a fixture or future catalog with a missing/extra/reordered category is a strict-decode failure per D8.
- **D10. Starter routines are catalog data** (PLAN.md M1 scope): the JSON carries starter-routine definitions — name key, ordered steps referencing catalog `id`s with the PRD §4.3 timing fields — decoded into value definitions. Seeding them into SwiftData is Milestone 2; here they only decode and, in tests, compile into valid timelines (proving the format expresses real routines).
- **D11. Runner control semantics** (core primitives; gesture interpretation like "back twice = previous segment" is a Milestone 5 UI decision — PRD §5.5 describes the *control*, the runner exposes the *operations*):
  - `pause`/`resume`: paused time is excluded from `activeSeconds`; resume continues the current segment at its remaining value (the fresh 3-2-1 re-entry tone of PRD §6.3 is a resume-scheduled cue event).
  - `skipForward`: jump to the next segment's start; skipping the final segment completes the session.
  - `restartSegment` and `previousSegment`: restart current from full duration / jump to the previous segment's start (getReady is the floor — `previousSegment` on the first segment restarts it).
  - `abandon`: ends the session, producing an honest partial summary.
  - Completion happens exactly when the final segment's remaining reaches 0 (`wasCompleted = true` only then — PRD §4.4).
- **D12. Session accounting (feeds PRD §4.4 fields):** `activeSeconds` counts unpaused seconds actually spent inside segments (skipped remainder is not counted; time never runs while paused). A step counts toward `completedStepCount` when its last work segment finishes *or is skipped past* (the user moved on; honesty lives in `wasCompleted`, which skipping to the end still earns only by reaching the final segment's natural or skipped end — matching "the final segment finished"). `totalStepCount` is the compiled step count. The runner's summary output is exactly the M2 `RoutineSession` value shape (D6).
- **D13. Stats rules (PRD §4.5/§7), all computed at read time in a caller-supplied `Calendar` + reference date** (tests pin calendar, time zone, and "now"; production passes `Calendar.current`):
  - **Session day attribution:** a session belongs to the local calendar day of its `endedAt` (a routine crossing midnight counts for the day it finished). Grounded APIs: `Calendar.startOfDay(for:)` and `dateInterval(of:for:)` (offline docset, `/documentation/foundation/calendar/…`).
  - **Streak:** consecutive calendar days with ≥ 1 `wasCompleted` session, counting back from today if today qualifies, else from yesterday (a streak survives until a full day passes without a completed session); otherwise 0. Never stored; multiple completions in one day count once (PRD acceptance #6).
  - **Weekly minutes:** sum of `activeSeconds` (completed *and* partial — PRD §7) for sessions whose `endedAt` falls in `calendar.dateInterval(of: .weekOfYear, for: now)`, honoring the user's `firstWeekday`; reported as whole minutes via integer math.
  - **Per-routine:** last done = most recent `endedAt` (any session); times completed = count of `wasCompleted`; total active minutes = sum of `activeSeconds`. Formatting ("2 days ago") is UI-layer Foundation formatting, not core.
- **D14. Tests use Swift Testing with parameterized cases** for the compiler edge-case table and stats calendar matrix (`@Test(arguments:)`, offline docset `/documentation/testing/parameterizedtesting`) — continuing the Milestone 0 D6 framework decision. Fixtures load from the already-wired `Fixtures` resource directory (`resources: .process` in `Package.swift`, repo truth) via the package resource bundle.

## 5. Edge cases

Compiler (each is a named test case; sample-routine expectations hand-computed in the test):
- **PRD §5.4 sample routine** compiles to the exact expected segment sequence and total; with getReady 5s the total is 5 + (30×3 + 10×2) + 15 + (30×2) + 15 + 30 + 20 + 30 + 20 + 30 = **335 s**; the timeline ends on Mountain Climbers' work segment (its trailing rest, had it one, would be dropped).
- **Squats in the sample (sets=2, setRest=0):** consecutive work segments of the same workout with no rest between — both get their own set announcement and T-3/2/1 beeps at each segment's own tail.
- Single step, sets=1, all rests zero → timeline is getReady + one work segment.
- getReady = 0 → getReady segment omitted (zero-duration rule applies to it too).
- Trailing `restAfterSeconds` on the last step → omitted from the timeline *and* from the total (the builder's live total must equal play time).
- Empty routine → empty timeline, total 0 (D7).
- `repGuidance` present → carried on the work segments' announcement payloads; absent → absent. Never affects durations (PRD §6.1).
- Missing catalog `id` in a step → compiles normally from the snapshot (D8).

Runner (fake-clock driven):
- Beep clipping on 1 s / 2 s / 3 s segments per D4.
- Pause mid-segment, advance the fake clock arbitrarily, resume → remaining unchanged across the pause; `activeSeconds` excludes the gap; resume re-entry cue emitted.
- Skip on the final segment → completion summary, `wasCompleted` true.
- `previousSegment` on the first segment → restarts it (no underflow).
- Abandon mid-routine → summary with `wasCompleted` false, honest `completedStepCount`/`activeSeconds`.
- Pause exactly on a segment boundary and at T-0 → no double-fired or dropped cue events (boundary events fire exactly once).
- No cumulative drift: after driving the full sample routine on the fake clock, total elapsed equals the compiled total exactly (integer seconds, offsets from the timeline — D2).

Stats:
- Two completed sessions the same day → streak counts the day once (PRD acceptance #6).
- Completed yesterday, none today → streak intact; none yesterday or today → 0.
- Session crossing midnight → attributed to `endedAt`'s day (D13).
- Time-zone change between sessions → streak computed in the *current* calendar's zone at read time; a test pins two zones and asserts the recompute differs accordingly (PRD §7 "handle time-zone changes gracefully").
- Week boundary: sessions on Sunday/Monday around the boundary land in the correct week for both `firstWeekday = 1` and `= 2` calendars; DST-transition week still sums correctly.
- Partial sessions add to weekly minutes but never to streak or times-completed.

Catalog decoding:
- Valid trimmed fixture (a few workouts per category + one starter routine) decodes with correct `catalogVersion`, category order (D9), and lookup by `id`.
- Duplicate workout `id`, unknown `categoryID`, missing/extra/reordered category, malformed JSON → strict decode failure (D8).
- Unknown extra JSON keys → ignored, decode succeeds (forward compatibility).
- Fixture starter routine decodes and compiles into a valid timeline (D10).

## 6. Accessibility & localization

No UI, no VoiceOver surface, no accessibility identifiers, and **no new string-catalog keys** — `Localizable.xcstrings` is untouched. Guardrails this milestone must respect so later milestones stay localizable: cue events carry semantic payloads, never assembled strings (D3 — spoken templates become catalog keys in Milestone 5 per PRD §3.1/§6.4); catalog fixtures use `nameKey` identifiers, not display names, keeping built-in workout names translation-ready (PRD §3.1.2); all stats math returns numbers and dates for UI-layer Foundation formatting (D13), never formatted strings.

## 7. Test impact

- All new, all in `StepBackCoreTests` (Swift Testing, D14): catalog-decoding suite (fixtures in `Fixtures/`), timeline-compiler suite (sample routine + parameterized edge table), runner state-core suite (command semantics, accounting), runner driver suite (fake `Clock`, cue-event timing, drift), stats suite (parameterized calendar/time-zone matrix).
- The Milestone 0 placeholder test and `StepBackCorePlaceholder.swift` are removed/replaced by real code and tests.
- App-target test bundles are untouched. Verification lanes: `make test-core` is the milestone gate; `make build-sim` + `make build-mac` must stay green (the app imports the package).

## 8. Acceptance criteria

1. `make test-core` passes with the suites of §7 present and non-vacuous; no test touches the wall clock, `Date()`-now defaults, or `Calendar.current` implicitly (clock, calendar, and reference date are always injected).
2. The PRD §5.4 sample routine compiles to the documented segment sequence with total 335 s at getReady 5 s, and driving it end-to-end on the fake clock emits every announcement, work-start tone, and T-3/2/1 beep at its exact offset.
3. Every compiler edge case and runner control path in §5 has a passing named test; every duration in the public API is `Int` seconds.
4. Streak, weekly-minutes, and per-routine aggregate tests cover the §5 stats matrix, including both `firstWeekday` values and a time-zone change.
5. The trimmed catalog fixture decodes; every strict-failure case in §5 fails decoding; a routine referencing a missing workout `id` still compiles and plays in tests.
6. `StepBackCore` has no UI, SwiftData, CloudKit, or AVFoundation imports; both app targets still build (`make build-sim`, `make build-mac`).
7. All work lands as one coherent commit on `codex/milestone-1-core-domain` (plus the PLAN.md/spec status flips per the workflow rules); the tree is clean afterward.
