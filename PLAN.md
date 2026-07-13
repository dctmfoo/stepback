# StepBack — Implementation Plan

**Status:** Ready to start after doc review
**Method:** TDD on the pure core; every milestone ends green (tests pass, app builds) and committed per CLAUDE.md commit discipline. Verify Apple APIs with `apple-platform-think` before locking choices at each milestone.

Each milestone below is a checkpoint: do not start the next one with the previous one red or uncommitted. Milestones that add UI must be verified against `design/ui-spec.html` before the checkpoint counts.

Each milestone carries a **Status** line — the live progress marker for this plan. Update it as part of the work it describes: set `in progress` in the commit that starts the milestone, and set `gate passed YYYY-MM-DD (<short-hash>)` in the milestone's closing commit, citing the commit that made the gate green. This file is the single at-a-glance answer to "where is the build?"; session journals point here (THIN mode) instead of restating progress.

## Milestone 0 — Project bootstrap

**Status:** gate passed 2026-07-10 (fe25e30)

- `project.yml` + `xcodegen` project generation mirroring the intelli-expense shape: one multiplatform app target (iPadOS/iOS/macOS 26+, Swift 6 strict concurrency), unit + UI test targets, `Makefile` for common commands.
- Local Swift package **StepBackCore** for pure logic (no UI imports): timeline compiler, stats math, catalog decoding. Own test target; `swift test` runs standalone.
- Asset catalog with the DESIGN.md token pairs (PulseAzure, PulseAzureSoft, RecoverMint, RecoverMintSoft, stage set, eight category hues) and `AccentColor` aliasing PulseAzure. `Localizable.xcstrings` created empty.
- Update CLAUDE.md §Commands with the real build/test/install commands.
- **Gate:** simulator build succeeds on iPad + iPhone destinations and macOS; empty test suites pass.

## Milestone 1 — Core domain (StepBackCore, TDD)

**Status:** gate passed 2026-07-10 (2218069)

- Built-in catalog format: decode the bundled JSON (categories, workouts, starter routines), `catalogVersion`, missing-id resilience (PRD §4.1). Fixtures with a trimmed catalog.
- Timeline compiler (PRD §6.2): routine → flat segment list. Test against the PRD §5.4 sample routine and edge cases (single step, sets=1, zero rests, no trailing rest).
- Timeline runner driven by a protocol clock with a fake: play/pause/resume/skip/back/complete/abandon; audio-cue scheduling points (announce at segment start, beeps at T-3/2/1) asserted in tests.
- Stats math (PRD §4.5/§7): streak from local calendar days, weekly minutes, per-routine aggregates; time-zone and week-boundary tests.
- **Gate:** `swift test` green; compiler and runner require no UI or wall clock.

## Milestone 2 — Persistence & catalog content

**Status:** gate passed 2026-07-10 (2b10df1)

- SwiftData models (`Routine`, `RoutineStep`, `CustomWorkout`, `RoutineSession`) per PRD §4, CloudKit-safe (optional relationships + inverses, defaults everywhere, no `.unique`), CloudKit mirroring configured.
- Full built-in catalog authored (≥ 80 workouts across the eight categories) + three starter routines as data; idempotent seeding (seed only into an empty store, PRD §5.1).
- **Gate:** app launches to a seeded store; catalog decodes; sync smoke-tested on two simulators/devices when feasible.

## Milestone 3 — Browsing UI (Routines home, Gallery, detail screens)

**Status:** gate passed 2026-07-10 (890b8db)

- Tab scaffold (TabView / Mac split view), Routines home with motivation strip + routine cards, routine detail, gallery with category grid + search + workout detail, custom-workout create/edit. `WorkoutVisual` monogram component (media-ready contract). Empty states.
- All strings into `Localizable.xcstrings`; accessibility identifiers per screen.
- **Gate:** ui-spec.html §Routines/§Gallery conformance check; VoiceOver pass on both tabs; pseudolocalization render check.

## Milestone 4 — Routine builder

**Status:** gate passed 2026-07-10 (8b91690)

- Builder flow: name, step rows + mint rest rows, inline step editor (steppers/wheels, 5 s increments), drag reorder, gallery picker with multi-select tray + smart defaults, floating glass Add/total bar, live computed total from the shared compiler.
- UI tests: build the PRD §5.4 sample routine; reorder; edit; totals match compiler output.
- **Gate:** PRD acceptance #2 demonstrably met; ui-spec.html §Builder conformance.

## Milestone 5 — The stage (player)

**Status:** in progress

- Full-screen stage: pre-roll, work/rest segment layouts (iPad landscape primary, portrait + iPhone adaptations), stage tokens, stage numerals, progress bar, control bar, completion + partial-completion views, idle-timer management, lifecycle pause/resume (PRD §6.3), Mac keyboard controls + window scene.
- Audio: speech + tone services behind the Milestone-1 protocols; audio-session coexistence with user music verified on device.
- **Gate:** PRD acceptance #3/#4/#5 met, including the DESIGN.md across-the-room verification (3 m, lit + dim, both segment types) and Reduce Motion pass.

## Milestone 6 — Sessions, stats & onboarding

**Status:** in progress

- Session recording (complete/partial/abandoned-on-relaunch), per-routine stats lines, motivation strip live, completion summary numbers, welcome screen + seeding polish.
- **Gate:** PRD acceptance #1/#6/#7 met; streak double-count and time-zone tests green.

## Milestone 7 — Hardening & full acceptance

**Status:** in progress

- Cross-device sync verification (PRD acceptance #10), Mac end-to-end (#12), VoiceOver end-to-end (#11), pseudolocalization + string-catalog audit (#13), performance targets (PRD §8), timer-drift measurement.
- Walk every PRD §9 acceptance criterion and record results.
- **Gate:** all 13 acceptance criteria pass; repo tagged v1-candidate.
