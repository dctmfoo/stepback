# Spec: Portrait (stacked) stage composition — centered hero stack

**Status:** Implemented
**Owner screens:**
- `StepBack/Features/Player/PlayerSegmentView.swift` (stacked-branch layout, visual sizing)
- `StepBack/Features/Player/PlayerStackedSegmentLayout.swift` (proportional hero/visual band allocation)
- `StepBack/Features/Player/PlayerStageView.swift` (stage vertical budget, stacked padding/spacers)
- `design/ui-spec.html` §player (new iPad-portrait work-segment frame)

**Docs this spec amends:**
- `DESIGN.md` — §10 media-slot table: stage slot wording (`beside/above the countdown`) corrected to match ui-spec's countdown-first portrait order.
- `design/ui-spec.html` — §player gains an iPad-portrait work-segment frame; the iPhone-portrait frame is already canonical and unchanged.

**Implementation branch:** `codex/player-portrait-stacked-stage`
**Queueing note:** independent of the in-flight `codex/agent-bridge` work; lands directly after it (or before — no shared files).

## 1. Problem

On iPad portrait the work-segment stage reads as undesigned while landscape is right. Three concrete defects, confirmed against the running app (2026-07-12 screenshot, "Easy Flat Tummy", Flutter Kicks, workout 3 of 15):

1. **Unbudgeted vertical space.** The stacked layout is the landscape text column naively stacked: content clusters in the top ~55% of the canvas, with a dead band between the routine header and the kicker and another below the visual. Landscape works because its two-column split consumes the canvas; portrait has no equivalent budget.
2. **Mixed alignment.** Kicker, countdown, workout name, and set indicator are left-aligned while the `WorkoutVisual` tile is centered, so the screen has no single axis.
3. **Undersized visual region.** The stacked visual is capped at a phone-sized height (~180 pt) and never rescales for the iPad canvas, so the DESIGN.md §10 stage media slot looks like a badge, and — under the no-reflow media contract — would stay too small when real media ships.

Root cause is drift, not a missing design: the canonical iPhone-portrait frame in `ui-spec.html` §player already shows the correct stacked composition (centered column, countdown above the visual). The implementation departed from it, and the departure is most visible on the tall iPad canvas.

There is also a **documentation conflict** this spec resolves: DESIGN.md §10's slot table says the stage visual sits "beside/above the countdown (landscape/portrait)" — visual *above* — while ui-spec.html's portrait frames and Mac notes put the countdown first. Per CLAUDE.md, ui-spec wins on layout; DESIGN.md must be amended so the two agree.

## 2. Goals

- G1. One centered composition for every stacked (non-wide) stage geometry — iPad portrait, iPhone portrait, and tall Mac stage windows — matching the canonical ui-spec portrait frame, scaled to the canvas.
- G2. A deliberate vertical budget on tall stacked canvases: no accidental dead bands; the `WorkoutVisual` region grows to earn its slot.
- G3. Zero regression to the wide (landscape/regular) layout, to rest/set-rest/get-ready compositions beyond alignment, to accessibility identifiers, to strings, and to all existing test lanes.
- G4. DESIGN.md, ui-spec.html, and the shipped app agree on portrait stage layout when this lands.

## 3. Non-goals

- **Visual-forward portrait (Option B from the design exploration):** leading with a full-width media region is the right evolution once real `mediaKey` assets exist; premature while the visual is a monogram tile. Revisit with the media milestone.
- **Persistent "Next: …" label during work (Option C):** beyond the current spec, which shows next-up only in the final 5 s of a work segment (ui-spec §player). Not included.
- **Countdown numeral resizing:** the stage-numerals proportion and caps are unchanged; the defect is space budgeting, not numeral size. (Also minimizes regression surface.)
- **Control bar, progress foot, completion/partial screens, pre-roll timing:** untouched.
- Checked against PRD §2 non-goals: this is pure layout correction within an existing screen — no new capability, right-sized as a small spec rather than a milestone amendment.

## 4. Design decisions

- **D1. The stacked stage adopts the canonical centered column.** Order: kicker → countdown → workout name → set/rep detail, then the `WorkoutVisual` region below, all on one center axis with centered text. This is not a new pattern — it is the existing ui-spec iPhone-portrait frame ("Same hierarchy stacked: countdown above the `WorkoutVisual` region") applied to every stacked geometry. Cites: DESIGN.md `across_the_room.hero` ("Exactly one hero: the countdown… Nothing else on the stage competes in size") — the countdown stays first and largest; `swiftui-design-principles` restraint (single axis, spacing from the base-4/8 grid). Rejected alternative: keeping the left axis with budgeted thirds (Option C's skeleton) — it preserves the mixed-axis tension with the centered control bar and progress foot, and diverges from the canonical mockup instead of converging on it.
- **D2. Rest/set-rest/get-ready keep their layout inversion, centered.** The next-up name still leads at title scale with the countdown secondary, per DESIGN.md `across_the_room.state_identity` ("Work vs rest is encoded twice — segment hue AND layout… Never hue alone"). Only the alignment axis changes (leading → center) to match the work composition's axis; the *order* inversion remains the rest identity.
- **D3. The visual region scales with the canvas instead of a phone-fixed cap.** In stacked geometry the 4:3 `WorkoutVisual` stage slot (DESIGN.md §10) targets roughly 30 % of stage height, clamped by available width minus stage padding, with a floor at today's phone size so iPhone portrait renders essentially as it does now. The region's size is a function of geometry only — never of whether media has arrived — preserving the PRD §4.7 no-reflow contract when monograms become loops. Rejected alternative: full-width visual (that is Option B; see Non-goals).
- **D4. Leftover height is spent deliberately.** The stacked stage divides into the fixed header, a hero block (kicker/countdown/name/detail), the visual region, and the fixed progress-foot + control-bar band; remaining height distributes as proportional breathing space *around* the hero block and visual rather than pooling above and below one centered cluster. All fixed spacing stays on the base-4/8 grid (DESIGN.md grid rule). No numeric spacer values are pinned here — the acceptance test is visual (§8, criterion 2).
- **D5. Geometry-driven, not device- or orientation-driven.** The stacked composition continues to trigger from the existing wide/stacked geometry split; no device-type or orientation branches (PRD §3; milestone-5 spec D3 "Rotation is free; layout is size-class- and geometry-driven"). Tall Mac stage windows get the same composition for free.
- **D6. DESIGN.md §10 is amended to match ui-spec.** The slot-table entry becomes "4:3 region beside (landscape) / below (portrait) the countdown". Rationale recorded here per the anti-drift rule that a conflicting DESIGN.md rule is amended explicitly, never silently deviated from: ui-spec is the layout authority, its portrait frames are countdown-first, and countdown-first is what `across_the_room.hero` implies for the work segment.
- **D7. ui-spec.html gains an iPad-portrait work-segment frame** in §player showing the scaled centered stack (countdown hero, ~30 %-height 4:3 visual, budgeted bands), so the canonical mockups cover the geometry this spec exists to fix. The mockups never lag the shipped app (CLAUDE.md anti-drift).

## 5. Edge cases

- **Final-5 s next-up line (work segments):** when the "Next: …" line appears in the stacked layout, its vertical slot must be reserved from segment start so its appearance does not nudge the countdown or visual ("the stage never hard-cuts", DESIGN.md `segment_transition`; one hero must not visibly jump). Wide layout behavior unchanged.
- **Resume countdown overlay** (pause → resume 3-2-1): renders in the same countdown slot; no layout difference from a normal tick.
- **Missing workout (deleted custom / no `WorkoutItem`):** the visual falls back exactly as today via `workoutNameSnapshot` + monogram tile; the reserved region size is identical (no-reflow).
- **Very long workout names:** name stays Dynamic Type and may wrap to two lines centered; the visual region yields height before any label truncates.
- **Short stacked canvases** (iPhone landscape-ish windows on Mac, split view): the wide/stacked threshold is unchanged; canvases that are stacked but short simply have less breathing space — the floor sizes keep hero, visual, foot, and controls all visible down to today's iPhone-portrait envelope.
- **Accessibility text sizes:** per DESIGN.md `stage_numerals.accessibility`, the stage stacks vertically (already true here) and the countdown yields height before any label truncates; the visual region compresses first, then the countdown.
- **Segment transition crossfade** (≤ 300 ms, scale settle) is unchanged; the new spacers must not animate independently of the segment content.

## 6. Accessibility & localization

- **No new strings.** No changed values. Nothing for `Localizable.xcstrings`; spoken announcements untouched.
- **No new or renamed accessibility identifiers.** `player.kicker`, `player.countdown`, `player.name`, `player.next`, `player.setIndicator`, `player.visual.category`, and the control/progress identifiers are all unchanged — this is what keeps the existing UI-test surface green by construction.
- **VoiceOver grouping and order unchanged:** kicker → countdown (label "time remaining", spoken value) → name → detail, then controls; alignment is not an AX-visible property.
- **Dynamic Type:** all stage text except the countdown remains Dynamic Type (the sole documented exception); the AX-size yielding order in §5 applies.

## 7. Test impact (regression plan)

Nothing in `StepBackCore`, the session model, persistence, or strings changes — the diff is confined to two view files plus the two design docs.

1. **Unaffected-by-construction receipts:** `make test-core` and `make test-app-unit` (no logic touched; run as the cheap ladder rungs).
2. **Existing UI lanes:** all player UI tests assert identifiers and flows, not geometry; with identifiers and flow order unchanged they must pass unmodified. Any UI-test edit accompanying this spec is a red flag in review.
3. **New focused coverage:** one iPad UI-test method that enters the player, rotates (or launches) into portrait, and asserts the work-segment surface is intact — `player.countdown`, `player.name`, `player.visual.category`, `player.progress`, and the control bar all present — then skips to a rest segment and asserts `player.next` leads. Run via `make test-focus-ipad TEST=...` during development.
4. **Closing gates:** one full `make test-app` and `make test-ipad` after implementation and the focused check are green, per the testing ladder.
5. **Mac:** shared SwiftUI, no Mac-specific behavior change; local `make build-mac` compile receipt only. No hosted-runner dispatch is justified by this spec (hosted Macs are reserved for irreducible native-Mac UI behavior).
6. **Manual design gate (required):** DESIGN.md `across_the_room.verification` — 3 m test, lit and dim room, both segment types, iPad portrait **and** landscape (landscape must be visually unchanged — that is the regression check), plus iPhone portrait against the canonical frame. Verify against the amended `ui-spec.html` via the `design-spec` preview server before calling it done.

## 8. Acceptance criteria

1. iPad portrait, work segment: one center axis for kicker, countdown, name, detail, and visual; countdown is unmistakably the single hero; visual renders as a 4:3 region of roughly 30 % stage height; no dead band taller than the hero block anywhere on the canvas.
2. The 3 m lit + dim verification passes on iPad portrait for work and rest segments, and iPad landscape is confirmed visually unchanged from before the change.
3. iPhone portrait matches the existing canonical ui-spec frame (centered stack, countdown above visual) with no size regressions at today's envelope.
4. Rest/set-rest/get-ready segments keep next-up-first order and Recover Mint hue in the centered stacked form.
5. In the final 5 s of a stacked work segment, the next-up line appears without moving the countdown or the visual.
6. `DESIGN.md` §10 slot wording and the new `ui-spec.html` iPad-portrait frame land in the implementation commit; DESIGN.md and ui-spec agree on portrait order.
7. No changes to `Localizable.xcstrings`, no identifier changes, no edits to existing UI tests; the new focused iPad method plus `make test-core`, `make test-app-unit`, `make test-app`, and `make test-ipad` are green at closeout.
