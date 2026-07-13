# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

**StepBack** — a private, iPad-first workout app for iPadOS/iOS/macOS 26+. The user composes routines once from a workout gallery (per-step work time, sets, rest between sets, rest between steps, optional rep guidance), saves them, then presses play, leans the iPad against the wall, steps back, and follows a fully hands-free player with voice announcements and countdown beeps. Motivating, honest stats (last done, times completed, day streak, weekly minutes) — never dashboards. No server, no accounts — zero network calls except CloudKit private-database sync.

The heart of the app: **routine → compiled deterministic timeline → hands-free stage player with audio cues**. The core promise is that nothing during play ever requires touching the device (PRD §0.4, §6.1).

## Repository state

The v1 product surface is implemented across iPadOS/iOS and native macOS: gallery, routine builder, weekly plans, hands-free player, honest stats, private CloudKit sync, and the local Agent Bridge. The repo uses an XcodeGen-authored project, deterministic unit/UI test lanes, the design-token asset catalog, and a local `StepBackCore` Swift package for pure logic. `project.yml` is the project source of truth; the generated `StepBack.xcodeproj` is committed.

## Spec and planning artifacts

Agent-authored implementation specs, user-supplied spec drafts, and follow-up feature briefs belong in `docs/specs/`. Do not create `SPEC-*.md` files in the repository root; if a spec is provided at the root, move it into `docs/specs/` before committing and update any references to the new path.

Spec detail level: specs must be detailed enough that another agent can implement them faithfully without asking questions — name the owner screens/files, spell out design decisions with rationale (including considered-and-rejected alternatives), enumerate edge cases, new string-catalog keys, accessibility identifiers, test impact, and acceptance criteria. But keep them above code level: no Swift snippets, no function signatures, no line-by-line instructions — behavior and component references, not implementation.

Spec house format: header with **Status**, **Owner screens** (file paths), and **Docs this spec amends**; numbered sections for Problem, Goals, Non-goals, Design decisions (D1, D2, …), Edge cases, Accessibility & localization, Test impact, Acceptance criteria.

## Workflow: planning vs implementation (two-agent split)

Work in this repo is split between a **planning agent** (research + spec authoring) and an **implementer agent** (code from a spec path). The owner's inputs are deliberately short — "write a spec for ___", "implement docs/specs/___.md", or "fix: ___ (repro)" — and everything below is the agents' job, not the owner's.

- **Role is inferred from the request, and planner is the default.** A spec path in the prompt makes you the implementer; a defect repro makes you the implementer; anything else that adds or changes behavior makes you the planner — write the spec, commit it at Status: Ready, and stop. Never implement a feature in the same session that specced it unless the owner explicitly says so.

- **Milestones are implemented via specs, never directly from PLAN.md.** PLAN.md carries sequencing and gates, not implementation detail. Starting a milestone means the planning agent first writes `docs/specs/milestone-N-<slug>.md` (house format) — reading the PRD/DESIGN/ui-spec scope and verifying the Apple APIs involved (`apple-platform-think`) at spec time, since PLAN.md requires API verification *before locking choices*. Large milestones may honestly be two or three specs; say so rather than write one bloated spec. Spec authoring commits on `main`; implementation happens on the spec's `codex/<spec-slug>` branch.
- **Spec Status is the handoff protocol.** The planning agent finishes a spec at **Status: Ready**. The implementer flips it to **Status: Implemented** in the implementation commit, and for milestone specs also updates the PLAN.md milestone status line (`in progress` in the opening commit, `gate passed YYYY-MM-DD (<short-hash>)` in the closing one).
- **Bugs: spec only when there is a decision to make.** A defect against an existing spec or acceptance criterion (wrong color, timing off, crash) needs no spec — the correct behavior is already specified; the implementer fixes it directly from a repro. If the buggy code is on the in-flight milestone branch, fix it there as part of making the gate pass; if it is in already-merged code, use a small `codex/fix-<slug>` branch. But if the "bug" is actually a design gap — the specified behavior is wrong or unspecified — that is a decision, so it goes through the planning agent: a short spec, or an amendment to the existing spec plus the PRD/DESIGN edits the anti-drift rules require.
- **Mid-milestone features queue by default.** The checkpoint rule (no next milestone while the current one is red or uncommitted) applies to interleaved work too: a new feature spec gets Status: Ready and a header note naming the milestone it lands after. Interleave only when the change would invalidate work the current milestone is about to do — better to fold it into the in-flight spec than to build the wrong thing. The planning agent checks every feature idea against PRD §2 non-goals and records the right-sizing in the spec's Non-goals section.

## Keeping design, localization, and docs in sync (anti-drift rules)

The UI is consistent because three artifacts stay authoritative: `DESIGN.md` (tokens + rules), `design/ui-spec.html` (canonical screen mockups), and `Localizable.xcstrings` (every user-facing string, once the app target exists). Any spec or implementation that touches UI must actively keep them that way:

- **Ground specs in the design system before inventing anything.** When a spec has a design surface, re-read the relevant `DESIGN.md` sections and `ui-spec.html` screens first, and *quote the specific rules that constrain the decision* in the spec's design-decisions section (e.g., "one hero number per screen", the two-element glass budget, single Pulse Azure accent / no red, functional-hue contracts (Recover Mint = rest only), Dynamic Type with the sole stage-numerals exception, base-4/8 grid, appearance-invariant stage tokens, no `colorScheme` branches, every workout visual through `WorkoutVisual`). A design decision that doesn't cite the rule it satisfies is a drift risk; one that can't cite any is probably inventing a pattern that needs review. Prefer reusing an existing component (name it and its file) over describing a new one that looks similar.
- **New UI patterns amend the canonical docs in the same change.** If a feature introduces a component, layout, or interaction not yet in `DESIGN.md`/`ui-spec.html`, the spec's "Docs this spec amends" header must list them and the implementation commit must update them — the mockups and rules never lag the shipped app. If a feature genuinely conflicts with a `DESIGN.md` rule, do not silently deviate: either change the design to fit the rule, or amend `DESIGN.md` explicitly (with rationale) in the spec so the rule stays true.
- **Localization is enumerated, never implied.** Every spec that adds or changes user-facing text must include the key/value table: new string-catalog keys with English values, changed *values* on stable keys (keys never renamed for copy changes), and plural variants where counts appear ("3 sets", "12 workouts"). Spoken announcement templates are UI strings too (PRD §6.4). Locale-dependent data (durations, dates, numbers) comes from Foundation formatters, never from the catalog and never hardcoded. A spec whose strings aren't in the table will produce hardcoded strings — reject it.
- **Accessibility identifiers and Dynamic Type are spec content**, not implementation afterthoughts: list new identifiers, state the VoiceOver grouping for composite elements (routine cards, stage segments), and note any AX-size behavior the layout depends on (the stage's documented scaling exception included).
- **Use the design skills when building or reviewing UI** (`swiftui-design-principles`, and `apple-platform-think` for API grounding; `web-search-plus` when current-web verification is needed), and verify against `ui-spec.html` (the `design-spec` preview server) before calling UI work done. Player work additionally requires the DESIGN.md across-the-room verification (3 m, lit + dim room, both segment types).

## Session journals

The full-history maintainer workspace may include a `sessions/README.md` contract and private journals. When that contract is present, every substantive session follows it and the Claude/Codex hooks enforce its pointer, freshness, and secrets rules. Public snapshots omit private journals; the hooks intentionally become no-ops when the contract is absent. Contributors who want the same continuity discipline can adopt [session-journal](https://github.com/dctmfoo/session-journal).

When the private journal contract is enabled, update the journal **before** making a spec (or checkpoint) commit and include the journal file in that commit — the session record belongs to the change it records. This keeps the tree clean at stop time and makes the Stop-hook nudge a backstop, not the primary mechanism. A journal touched only after the last commit of a turn may be committed on its own or folded into the next commit; a dirty journal file does not count as "loose dirty work" under the commit discipline below.

## Commit discipline

Spec implementation must happen on a branch named for that spec, never directly on `main`. Use `codex/<spec-slug>` by default (for example, `codex/routine-builder-picker`) so the branch, commit, and spec file can be matched during review and later archaeology.

Do not leave completed implementation work as a loose dirty tree. For spec-driven work, finish the implementation and required verification, then create **one coherent commit per implemented spec** before calling that spec complete. If a request implements multiple specs, keep the repo green between specs and commit each spec separately rather than piling all changes into one uncommitted batch. Stage only files that belong to the current spec; preserve and call out any unrelated dirty work that was already present.

For non-spec changes, commit at natural checkpoints after the relevant tests/verification pass. The only normal reasons to hand off verified implementation without a commit are: the owner explicitly asked not to commit, verification is blocked, or the change is intentionally an exploratory tryout.

## Required reading (in this order, before writing code)

1. [PRD.md](PRD.md) — the complete product spec: goals/non-goals, data model (6 entities + bundled catalog), screens, the player engine, audio design, stats, acceptance criteria. **Read it fully before writing any code.** Its §0 ground rules are binding.
2. [DESIGN.md](DESIGN.md) — design system: machine-readable tokens in the YAML frontmatter + rules in the body. PRD defines *what*; DESIGN defines *how it looks and feels*.
3. [design/ui-spec.html](design/ui-spec.html) — canonical screen-by-screen mockups. On layout, this file wins; on tokens/rules, DESIGN.md wins.
4. [PLAN.md](PLAN.md) — the checkpointed implementation plan (TDD, milestone order, verification gates).

## Platform & stack (fixed decisions — see PRD §3)

- iPad-first; iPhone and native Mac equal-quality peers. iPadOS/iOS/macOS 26.0+, Swift 6 strict concurrency, SwiftUI with `@Observable` main-actor view models. Size classes only — never device-type branches.
- SwiftData + CloudKit mirroring (private DB) for routines, custom workouts, session history. CloudKit schema rules from day 1: all relationships optional with inverses, no `.unique`, defaults/optionality on every attribute.
- Built-in workout catalog is a **versioned bundled JSON data table**, never SwiftData (PRD §4.1) — catalog growth is a data change, not a migration.
- Audio: system speech synthesis + short tones, behind protocols. Verify all Apple APIs against current docs before locking choices; use the `apple-platform-think` and `swiftui-design-principles` skills. (A UserPromptSubmit hook, `.claude/hooks/apple-docs-reminder.sh`, re-injects this rule on Apple-shaped prompts — and on every prompt once Swift sources exist.)

## Non-negotiable constraints (recurring traps)

- **Durations are integer seconds end-to-end** — never Float/Double; format via `Duration`/Foundation formatters; tabular numerals in UI; the compiled timeline is the single source of truth for every displayed total (PRD §6.2).
- **The player never waits for input** (PRD §6.1): everything is time-based; rep counts are guidance labels only. Any design that requires a tap to keep a routine running violates the core promise.
- **The timeline compiler and runner are pure and deterministic**, driven by an injected clock behind a protocol with a fake for tests; audio cue *scheduling* is part of the tested runner. Speech/tone playback also behind protocols with fakes.
- **Every user-facing string lives in the String Catalog** (`Localizable.xcstrings`) from the first app-target commit — including spoken announcement templates and catalog workout/category name keys (PRD §3.1).
- **Media-readiness is a contract** (PRD §4.7): every workout visual renders through the single `WorkoutVisual` component; `mediaKey` slots exist from day 1; screens must not reflow when media arrives.
- **Workout-media experiments stay outside this repository.** Keep app binaries, model weights, source/driving clips, generated media, contact sheets, and paid-service exports in a separate untracked workspace; this repo may contain only product-facing instructions, research decisions, and an integration spec.
- **Steps snapshot their workout name** (`workoutNameSnapshot`) so deleted custom workouts and catalog changes never blank or crash a routine.
- **Stats are honest and derived** (PRD §7): streak computed from local calendar days at read time (never a stored counter); only completed sessions count toward streak/times-completed; no goals, no shame states.
- Respect PRD §2 non-goals: no generated/adaptive programming, no calories, no HealthKit/Watch/widgets/Live Activities in v1, no rep counting/AI coaching, no social, no music playback, no awards/charts. User-composed training plans are sequencing only. When in doubt, cut scope, not quality.
- External automation uses only the Mac app's `AgentBridge/` file-drop protocol. Agents read `manifest.json`, write new command JSON only to its declared `inboxPath`, and read outcomes; they never edit SwiftData/SQLite/CloudKit files or any other app-container path. The protocol has no delete/archive verb.
- Design: single Pulse Azure accent; Recover Mint means rest only; no red except system destructive delete; Dynamic Type only (sole documented stage-numerals exception); appearance-invariant stage tokens; thirteen custom asset-catalog token pairs + the six-color appearance-invariant stage set; no `colorScheme` branches in feature code; two-element custom glass budget.

## Commands

### Testing and verification ladder (mandatory)

Full UI lanes are **closing gates, not diagnostic loops**. Start with the cheapest test that can prove the behavior and climb only when the lower layer is green:

1. Static checks and deterministic generation for project/configuration changes.
2. `make test-core` for pure timeline, catalog, formatting, stats, and other package logic.
3. `make test-app-unit` for app models, persistence, routing state, source scans, and other logic that does not require UI interaction.
4. A focused iPhone or iPad UI class or method via `make test-focus-iphone TEST=...` or `make test-focus-ipad TEST=...` only when the behavior genuinely depends on rendered UI, accessibility pixels, or app lifecycle.
5. The full `make test-app` and `make test-ipad` lanes once at closeout, after implementation and focused checks are green.
6. Native Mac UI automation through the manual GitHub-hosted workflow only when AppKit windows, sheets, menus, keyboard input, or Mac accessibility behavior genuinely requires it. Use one focused method before a full suite.

If a full lane fails, **do not immediately rerun the full lane**. Isolate the failing class or method, diagnose it with headless/unit coverage where possible, and use the matching focused UI target only for the irreducible interaction. Run the full affected lane again once, at the final gate, after the focused failure is green. A production-code change made after that final run invalidates only the affected lane's receipt; rerun that lane once—not every platform indiscriminately.

All tests that do not require Mac UI automation run locally. Native Mac UI tests may run locally when the machine is available, or through the manual GitHub-hosted workflow when a clean hosted receipt is useful. Do not use a full hosted suite to diagnose one failure; select the exact failing method. A second hosted run requires a relevant code/configuration change or the single permitted fresh-runner retry for a pre-assertion initialization failure.

Before starting slow UI automation, tell the owner what focused or full lane will run and why. Keep it attached to the active task; do not leave it running after pausing or handing off. If the owner asks to stop, terminate the test/build/app processes immediately and verify they are gone. See [docs/verification/testing-strategy.md](docs/verification/testing-strategy.md) for the command matrix and failure protocol.

- Preview the design spec: `python3 -m http.server 8735 --directory .` then open `http://localhost:8735/design/ui-spec.html` (configured as the `design-spec` server in `.claude/launch.json`).
- `make gen` — regenerate the committed `StepBack.xcodeproj` from `project.yml`. `project.yml` is authoritative; never hand-edit the generated project.
- `make test-core` — run the standalone `StepBackCore` Swift package tests.
- `make test-app-unit` — run only the app unit-test bundle on the standard iPhone simulator; no UI-test bundle.
- `make test-focus-iphone TEST=<target/class[/method]>` — run one focused iPhone UI class or method.
- `make test-focus-ipad TEST=<target/class[/method]>` — run one focused iPad UI class or method.
- `make test-focus-mac TEST=<target/class[/method]>` — run one native Mac UI class or method locally; the manual hosted workflow accepts the same filter.
- `make test-app` — final-gate app unit and UI tests on the standard iPhone simulator. Override `SIM_DEST` for another available destination.
- `make test-ipad` — final-gate app unit and UI tests on the standard iPad simulator. Override `IPAD_DEST` for another available destination.
- `make test-mac` — run the full native macOS UI suite locally as a closing gate; never use it as a diagnostic loop.
- `make test` — run the core and standard iPhone app test lanes.
- `make test-perf` — opt in to the slow acceptance measurements (cold launch, play-tap → pre-roll signpost, gallery scroll, and real-clock drift) on `PERF_DEST`; simulator results are indicative only.
- `make test-perf-iphone` / `make test-perf-ipad` — run those measurements on the paired physical devices; these device results decide the PRD §8 acceptance verdicts.
- `make build-sim` — build the iOS app for the standard iPhone simulator.
- `make build-sim-ipad` — build the iOS app for the standard iPad simulator.
- `make build-mac` — build the native macOS app.

### Installing on physical devices

- `make devices` — list paired physical devices and their identifiers (`xcrun devicectl list devices`).
- `make install-iphone` — build a signed Debug app, then install and launch it on the configured iPhone.
- `make install-ipad` — the same for the configured iPad.

Use these targets instead of hand-rolled `xcodebuild`/`devicectl` invocations. Installs preserve existing app data (no uninstall step). The device must be unlocked, paired, and reachable (cable or same Wi-Fi). Maintainer builds copy `Makefile.local.example` to `Makefile.local` and supply the local Apple Developer team and paired-device identifiers; never commit that ignored file. Third-party forks must first replace the owner-controlled bundle IDs and private CloudKit container with identifiers provisioned by their own team, as described in `README.md`. `-allowProvisioningUpdates` handles device provisioning after those identities are valid.

### GitHub-hosted Mac UI automation

- `.github/workflows/macos-ui.yml` pins GitHub's `macos-26` image to Xcode 26.5 and runs without Apple signing or CloudKit secrets; XCTest uses the existing in-memory persistence seam.
- The workflow is manual-only: no push or pull-request trigger is permitted. One dispatch runs exactly one suite; functional and accessibility checks are intentionally separate.
- Hosted runners are only for native Mac UI automation. Run core tests, app unit tests, source scans, project generation, compilation, and unsigned build-for-testing locally.
- Hosted minutes are limited. Before dispatch, confirm the run is necessary and prefer an exact method filter. Never dispatch functional and accessibility together merely for completeness.
- Once the workflow exists on the default branch, dispatch one suite with `gh workflow run macos-ui.yml --ref <branch> -f suite=functional -f reason='<reason>'`. Add `-f test_filter=StepBackMacUITests/StepBackMacUITests/<method>` for a focused run. Inspect with `gh run list --workflow macos-ui.yml` and retrieve evidence with `gh run download <run-id>`.
- After every run, retain the GitHub job URL and its `started_at`/`completed_at` duration in the task's verification notes. Concurrent jobs count separately; use wall-clock job time even when GitHub's billing API reports zero billable milliseconds.
- CI is a closing receipt, not a diagnostic loop. Diagnose assertion logic locally with non-UI coverage where possible, make a relevant change, then use one focused hosted method if UI interaction is irreducible.
- An automation-initialization failure may be retried once through manual dispatch on a fresh hosted runner. Two matching initialization failures are a hosted-runner blocker; do not create a self-hosted runner without a new owner decision.
