# Spec: M0–M4 verification-audit fixes

**Status:** Implemented
**Owner screens:** `StepBack/Features/Builder/RoutineBuilderWorkoutPicker.swift`, `StepBack/Features/Builder/RoutineBuilderView.swift` (D12 conformance), `StepBack/Features/Shared/` (new shape-token helper), the ~11 corner-radius call sites listed in §4 D3 across `Shared/`, `Routines/`, `Gallery/`, `Builder/`, `StepBack/Resources/Localizable.xcstrings` (plural variants), `StepBackTests/RoutineBuilderModelTests.swift`, `StepBackUITests/StepBackUITests.swift`, `StepBackMacUITests/StepBackMacUITests.swift`
**Docs this spec amends:** `DESIGN.md` (shape section — names the radius scale the code must reference; see D3)

**Branch:** `codex/fix-m0-m4-audit`. **Sequencing:** lands on `main` after the Milestone 4 merge (`ad2457b`) and before Milestone 5 *implementation* starts; the Milestone 5 spec may be authored in parallel. This is a defect/conformance pass against already-specced behavior — it exists as a spec (rather than a direct fix) at the owner's request, and because D3 requires one genuine design decision.

**Implementation note:** the draft spec's §7 sample-total wording said 335 s, but `PRD.md`, `design/ui-spec.html`, and the shared compiler contract all establish the builder sample at 330 s / 5:30. The implementation and tests keep the established 330 s contract.

---

## 1. Problem

A full verification pass over Milestones 0–4 (2026-07-10: all four test lanes green; three audit sweeps against the specs and the CLAUDE.md non-negotiables) found the core logic clean but surfaced: two unimplemented behaviors from Milestone 4 spec D12, one real DESIGN.md rule violation (hand-tuned per-view corner radii at ~11 sites), a handful of off-grid spacing literals, two count-bearing strings without plural variants, and six test-coverage gaps against Milestone 4 §7. None block the app today; all are drift risks that get more expensive after the player lands.

## 2. Goals

- G1. Close the two Milestone 4 D12 conformance gaps: `.selection` haptic on picker selection, scroll-to-first-new-step on commit.
- G2. Eliminate hand-tuned corner-radius literals from feature code and make the DESIGN.md shape rule enforceable (named scale + concentric nesting).
- G3. Normalize off-grid spacing literals to the base-4 grid.
- G4. Add plural variants to the two count-bearing catalog strings that lack them.
- G5. Close the Milestone 4 §7 test-coverage gaps so the milestone's test contract is actually held by tests.

## 3. Non-goals

- No visual redesign: the shipped radii and layouts passed ui-spec conformance; D3 centralizes the values, it does not change what the user sees (±0 pt where a value is already on the named scale).
- No behavior changes beyond the two D12 items — everything else in M0–M4 verified conformant.
- The `detail.edit` control on routine detail is *not* a finding: Milestone 3 deferred Edit to Milestone 4, which specced it (M4 D3b).
- `perRoutine.lastDone` counting non-completed sessions stays as-is: PRD §4.5 scopes only streak/times-completed to completed sessions; "last done" reflecting any play-through is honest.
- No new features, strings beyond §6, or PLAN.md changes (no milestone status is affected).

## 4. Design decisions

- **D1. Picker selection fires the `.selection` haptic (M4 D12, DESIGN.md `haptics.picker_selection`).** Attach `sensoryFeedback(.selection, trigger:)` to the picker, triggered by changes to the selection collection, so row taps *and* tray-tile deselects both fire it (both are selection mutations on the same state — one trigger covers every path, including future ones). Verified: `sensoryFeedback(_:trigger:)` is iOS 17+/macOS 14+ (docset `/documentation/swiftui/view/sensoryfeedback(_:trigger:)`, read 2026-07-10) — fine on OS 26 targets; on hardware without haptics it is a silent no-op, which is the correct degraded state.
- **D2. Committing the picker scrolls the step list to the first new step (M4 D12).** Wrap the builder's step list in a `ScrollViewReader` and, on commit, scroll to the first appended step's row id (the same identity `expandedStepID` already uses — no new id scheme). Animated scroll, honoring Reduce Motion via the existing transaction behavior. Rationale as in M4 D12: after a multi-add the user's next action is editing the new steps; landing them off-screen hides the result of the commit.
- **D3. Corner radii become a named scale in one shared helper; nested shapes go concentric.** DESIGN.md's shape rule ("system-provided radii; custom cards use concentric corners relative to container"; `never:` hand-tuned per-view radii) is currently violated by literals at: `WorkoutVisual.swift` (10/16/20 switch), `RoutineCard.swift` (18), `RoutineBuilderWorkoutPicker.swift` (14), `RoutineBuilderStepEditor.swift` (14 ×2), `RoutineRestRow.swift` (12), `MotivationStrip.swift` (10), `CustomWorkoutEditor.swift` (10), `WorkoutDetailView.swift` (16), `RoutineStepRow.swift` (16), `AddCustomWorkoutTile.swift` (14/16). Fix in two parts:
  - **(a) One shared shape-token surface** in `StepBack/Features/Shared/` exposing the named scale — `tileSmall = 10`, `tileMedium = 16`, `tileLarge = 20`, `card = 16`, `insetRow = 12`, `cardProminent = 18` — and every feature call site references the name, never a number. Sites already on a scale value keep their exact rendering; the implementer maps each site to the nearest existing name **without inventing new values** (e.g. the picker/editor 14s become `insetRow` or `card`, whichever the side-by-side ui-spec §builder check confirms — a ±2 pt change on inner chrome is acceptable, changing `WorkoutVisual` or `RoutineCard` rendering is not).
  - **(b) Concentric corners where a shape is genuinely nested inside a custom rounded container** (the editor inset inside the step block, tray tiles inside the tray): the container declares `containerShape(_:)` and the nested view uses `ConcentricRectangle` / `.rect(corners: .concentric(minimum:))`. Verified current on iOS/iPadOS/macOS 26 (docset `/documentation/swiftui/concentricrectangle`, all-platforms 26.0 availability, read 2026-07-10; Apple's Liquid Glass adoption guidance explicitly prescribes container-concentric nesting). Top-level cards in system lists/grids have no custom container — they use the named scale from (a); that is what "system-provided radii" can mean there, and the DESIGN.md amendment says so explicitly so this rule stops being unenforceable.
  - **DESIGN.md amendment:** the `shape:` rule gains the named scale and the two-case guidance (named token at container level, concentric when nested), keeping the `never: hand-tuned per-view radii` line — now with a mechanical definition of compliance. Rejected: relaxing the rule to bless the literals (leaves the next screen free to invent 13 and 17); migrating everything to `ConcentricRectangle` (top-level cards have no container shape to be concentric to — it would be concentric theater over a hardcoded root value anyway).
- **D4. Spacing literals move onto the base-4 grid.** `spacing: 2` → 4 (three sites: `MotivationStrip.swift`, `RoutineBuilderFloatingBar.swift`, `RoutineBuilderWorkoutPicker.swift`), `spacing: 14` → 12 (`RoutineBuilderFloatingBar.swift`), `spacing: 10` → 8 (`RoutineBuilderWorkoutPicker.swift`). Each change is verified against ui-spec §builder/§routines side-by-side; if a site visibly degrades at the grid value, the implementer picks the *other* adjacent grid value (e.g. 14 → 16), never keeps the off-grid one. Rationale: DESIGN.md `spacing.grid: 4` — where labels hug (the 2s), 4 pt is the grid's own minimum step.
- **D5. Plural variants for the two count-bearing strings.** `home.week.minutes` ("%lld min this week") and `routine.stats.last-done` ("Last done %@ · %lld×") gain plural variation on their count argument in `Localizable.xcstrings`. English values for `one`/`other` may be identical ("min" and "×" are invariant in English) — the point is the variation *structure*, so adding a language never requires a schema edit (PRD G12, CLAUDE.md "plural variants where counts appear"). Keys are not renamed; no code changes.
- **D6. Test additions are conformance tests to the M4 spec, not new contracts.** Exactly the M4 §7 items found missing — enumerated in §7 below. No test rewrites beyond what the gaps name.

## 5. Edge cases

- D1: rapidly toggling a selection fires one feedback per state change — acceptable; no debouncing (system behavior for selection feedback).
- D2: commit into an empty draft scrolls to step 0 (trivially visible — the scroll is a no-op, must not crash); commit in the regular-width side-by-side pane scrolls the *step list*, not the picker pane.
- D3: `WorkoutVisual` renders identically before/after (its 10/16/20 values map 1:1 onto `tileSmall/tileMedium/tileLarge`) — any pixel change there is a defect, it is the media-readiness contract's component.
- D4: AX-size layouts re-checked at the three changed-spacing sites (the floating bar's two-line wrap behavior from M4 §6 must survive).
- D5: pseudolocalization render check still passes; `xcstrings` remains valid JSON (`jq empty`).

## 6. Accessibility & localization

No new strings and no changed English display values. Changed catalog *entries*: `home.week.minutes` and `routine.stats.last-done` gain plural variation (D5) with English `one`/`other` values as today. No new accessibility identifiers; no VoiceOver behavior changes (D1's haptic is non-auditory; D2's scroll does not move VoiceOver focus — the existing post-commit expansion state already drives focus).

## 7. Test impact

Closing the Milestone 4 §7 gaps, verbatim against that spec:

- **`StepBackTests`:** dirty-flag unit test backing M4 D15 (fresh draft not dirty; each mutation class dirties; save resets; cancel-equivalent state comparison).
- **`StepBackUITests`:**
  - Extend the gate test to the full PRD §5.4 sample — five workouts in one picker pass, every step's timing set via steppers, floating-bar total equals the compiled 330 s / 5:30 figure, Save, detail hero matches (M4 §7 "the gate test").
  - Reorder test: move a step via drag handles, assert its rest row traveled and the total is unchanged (M4 §7; PLAN.md Milestone 4 names it).
  - Edit test: open Edit, change one value, Save, assert detail updated; separate Cancel path asserts the persisted routine unchanged (M4 §7).
  - Discard test: dirty the draft, Cancel, assert the discard dialog appears and `builder.discard.confirm` works; swipe-dismiss is blocked while dirty (M4 §8.4).
- **`StepBackMacUITests`:** builder smoke — New Routine opens the builder, a step is added via the picker, Save lands the routine (M4 §7 Mac item).
- New D1/D2 behaviors: covered by the extended gate test implicitly (scroll target visible for the stepper interactions); the haptic is not UI-testable — model-level selection state is already covered.

## 8. Acceptance criteria

1. Picker selection (row tap and tray-tile deselect) fires the `.selection` sensory feedback; commit scrolls the step list so the first newly added step is visible, in both compact-sheet and regular-width pane presentations.
2. `grep`-level check: no numeric corner-radius literal remains in `StepBack/Features/` — every radius resolves through the shared named scale or a concentric shape; `WorkoutVisual` and `RoutineCard` render pixel-identical to before.
3. `DESIGN.md` shape section names the scale and the concentric rule in the same commit (anti-drift).
4. No `spacing:` literal in `StepBack/Features/` sits off the base-4 grid.
5. `home.week.minutes` and `routine.stats.last-done` carry plural variation; pseudolocalization renders; string-catalog JSON valid.
6. All §7 tests exist and pass; `make test-core`, `make test-app`, `make test-ipad`, `make test-mac` green; `make gen` idempotent.
7. Re-running the M4-spec conformance audit finds no NOT-MET items.

## 9. Implementation evidence

- `ShapeRadius` now centralizes the feature radius scale; feature code no longer carries numeric corner-radius literals, and nested builder/picker surfaces use concentric shapes.
- Picker selection uses `.selection` sensory feedback and the picker commit scrolls to the first appended step.
- Builder, gallery, routine, and Mac smoke coverage now exercises dirty state, discard, edit/save/cancel isolation, reorder/rest-row preservation, exact search ranking, full 330 s builder sample, and Mac builder save.
- Verification run:
  - `make gen`
  - `make test-core`
  - `make test-app`
  - focused iPad builder UI test
  - `make test-ipad`
  - `make test-mac`
  - radius literal grep: no matches in `StepBack/Features`
  - off-grid `spacing:` grep: no matches in `StepBack/Features`
  - `jq empty StepBack/Resources/Localizable.xcstrings`
  - `xcrun xcstringstool compile --dry-run --output-directory /tmp/stepback-xcstrings StepBack/Resources/Localizable.xcstrings`
  - pseudo-language iPad launch smoke with screenshot `/tmp/stepback-pseudolang-ipad.png`
  - `git diff --check`
