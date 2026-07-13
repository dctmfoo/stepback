# SPEC — Training plans: weekly/monthly grouping of routines

**Status:** Implemented — model decisions D1–D6 superseded by `docs/specs/plans-weekly-schedule-redesign.md` (weekly-schedule redesign; D7's snapshot rule survives)
**Owner screens:** `StepBack/Features/Plans/` (new: plans home section, plan editor, plan detail), `StepBack/Features/Routines/RoutinesHomeView.swift` (amended: "Up next" hero card + Plans entry point), `StepBack/Persistence/Models.swift` (amended: new `Plan`/`PlanSlot` models), `StepBackCore` (new pure types: plan snapshot, plan progress derivation)
**Docs this spec amends:** PRD.md §2 (non-goals: narrows "multi-week programs, plans" — see D1), PRD.md screens list (adds Plans), DESIGN.md (adds plan-card and up-next-card patterns if not already covered by existing card rules), `design/ui-spec.html` (new Plans screens)
**Branch:** `codex/training-plans`
Sequencing: independent of other open specs; must land before SPEC-agent-bridge.md (which exposes plans to agents).

---

## 1. Problem

Routines exist as standalone, user-composed groups of workouts, but nothing organizes them across time. A user following a simple split ("push / pull / legs, repeat for a month") has to remember where they are, pick the right routine by hand every session, and gets no sense of progress across the week or month. Industry research (Boostcamp, Hevy, Strong, Apple Fitness+ Custom Plans, Garmin Coach, Fitbod — 2026) shows two dominant models: sequential day-numbered programs ("Week 2, Day 3") and calendar/weekday-anchored plans. It also shows the highest-value single feature is surfacing "what's next", and the most-complained-about behavior is calendar anchoring's "missed workout" guilt states (Garmin's missed-workout rigidity is its top forum complaint; weekday assignment is Hevy's top open feature request precisely because folders alone don't answer "what do I do today?").

## 2. Goals

- G1. A user can create a **plan**: a named, ordered sequence of weeks, each week an ordered list of slots referencing existing routines.
- G2. Exactly one plan can be **active**; the app always answers "what's next?" with a hero card on the routines home.
- G3. Completing (or skipping) the up-next slot advances the plan; progress reads as "Week 2 of 4 · 5 of 12 workouts done".
- G4. Plans are freely **editable mid-plan**: edits apply immediately to what hasn't been done; logged history never changes.
- G5. A finished plan announces completion and offers restart; a plan can be set to repeat.
- G6. Authoring is fast: duplicate week, duplicate plan, reorder slots and weeks.

## 3. Non-goals

Checked against PRD §2. This spec deliberately **amends** the PRD §2 non-goal "Multi-week programs, plans, or progressive overload logic" (see D1) — the rest of §2 stands, and within plans the following stay out:

- No prescription or progression: the app never generates, adapts, or suggests plan content. Plans are user-composed grouping/scheduling of user-composed routines. Progressive-overload logic remains a PRD §2 non-goal verbatim.
- No calendar-date anchoring, no "missed workout" states, no adaptive rescheduling (the Garmin/TrainerRoad complexity class — cut).
- No notifications or reminders (a calm "up next" card is the v1 surface; revisit on demand).
- No deload weeks, mesocycles, or periodization vocabulary — a lighter week is just another week the user authors; repetition is a repeat toggle.
- No plan templates, sharing, or marketplace (conflicts with PRD private/no-server stance).
- No multiple concurrent active plans.
- No versioning of plan edits (industry consensus: future-applies-immediately + immutable history; nobody ships user-visible plan versions).

## 4. Design decisions

### D1 — Sequential day-numbered model, not calendar anchoring (PRD amendment)

A plan is **ordered weeks of ordered slots**, each slot referencing a routine. Nothing is bound to a weekday or date. The user does "the next slot" whenever they train; a slot may carry an optional **weekday label** ("Mon") as display-only metadata that never creates a missed state. Rest days are the absence of a slot — not an entity.

Rationale and rejected alternatives: weekday/date anchoring (Apple Fitness+, Garmin) buys "today's workout" but forces missed-workout semantics on day one and produces the guilt states users complain about; Fitbod-style computed next workouts require recovery modeling the PRD forbids ("the app never prescribes"). The sequential model (Boostcamp, and how Strong/Hevy users behave de facto) degrades gracefully for train-whenever users, makes skip handling free, and reuses routines as-is.

PRD §2 currently reads "Multi-week programs, plans, or progressive overload logic. Routines are user-composed; the app never prescribes." This spec amends that line to: progressive overload / adaptive prescription remain out; **user-composed plans** (pure grouping + sequencing of existing routines, zero prescription) are in scope. The amendment preserves the rule's intent — the app still never prescribes — and the PRD edit ships in the same change as this spec's implementation.

### D2 — Data model: `Plan` + `PlanSlot`, snapshots in core

Two new SwiftData models in `StepBack/Persistence/Models.swift`, following the repo's CloudKit rules (all relationships optional with inverses, no `.unique`, defaults on every attribute — CLAUDE.md persistence rules):

- **Plan**: id, name, createdAt, updatedAt, isActive flag, repeat flag, cursor (current week index + current slot index), completed-slot tally for the current run, cascade relationship to slots.
- **PlanSlot**: week index, sort index within week, routine reference by id **plus a routine-name snapshot** (same snapshot discipline as `RoutineStep.workoutNameSnapshot`), optional weekday-label token.

Pure mirrors live in `StepBackCore` (a plan snapshot type and a progress-derivation function alongside `Stats/DerivedStats.swift` patterns), keeping core free of SwiftData/UI per the milestone-1 boundary. Progress strings ("Week 2 of 4", "5 of 12") are derived in core from the snapshot + cursor, unit-testable without persistence.

Rejected: deriving the cursor purely from `RoutineSession` history — sessions don't record *why* a routine was run (ad-hoc vs plan slot), and back-deriving position from logs breaks the moment a user runs a routine outside the plan. A stored cursor is the simple truth; sessions gain an optional plan-context stamp (D4) for stats, not for position.

### D3 — One active plan; "Up next" hero on the routines home

At most one plan is active. Activating a plan deactivates the previous one (cursor preserved, so switching back resumes where it left off). The routines home gains an **Up next** hero card when a plan is active: plan name, "Week 2 of 4", the next slot's routine name and compiled duration (from `TimelineCompiler`, the single source of displayed totals), and a play affordance that launches the routine player exactly as launching it from routine detail would. Card visuals follow the existing card language and single Pulse Azure accent; the compiled-duration rule and two-element glass budget from DESIGN.md apply unchanged.

Rejected: a separate Plans tab as the primary surface — the home already answers "what do I train now?"; plans are a layer over routines, not a sibling world. Plans get a section/entry point on the existing home, not a new tab.

### D4 — Completing and skipping advance the cursor; history is append-only

- Finishing a player session launched **from the up-next card** advances the cursor to the next slot (wrapping to the next week; see D6 at plan end) and stamps the created `RoutineSession` with plan context (plan name snapshot, week index, slot index — snapshot fields, not required relationships, per CloudKit rules).
- **Skip** is an explicit, calm action on the up-next card: advances the cursor without creating a session. No "missed", no red, no streak-shaming (DESIGN.md: no red except destructive delete).
- Running any routine *outside* the plan (from routine detail or gallery) never touches the cursor — ad-hoc training stays first-class.
- An abandoned session (`wasCompleted == false`) does not advance the cursor; the slot remains up next.

### D5 — Editing: future applies immediately, past is immutable

The plan editor edits the plan in place at any time, active or not: rename, add/remove/reorder weeks and slots, change a slot's routine, set weekday labels, duplicate a week, duplicate the plan. Edits take effect immediately for everything at or after the cursor. Logged `RoutineSession` rows are never rewritten (their plan stamps are snapshots). Cursor reconciliation when the shape changes under it is defined in Edge cases. This matches the Boostcamp/TrainerRoad consensus: no versioning, no "applies next cycle" ceremony.

The editor reuses the builder interaction patterns of `RoutineBuilderModel` (in-memory `@Observable` draft, save-or-rollback in one `ModelContext` transaction via `Persistence/ModelContext+Save.swift`); a plan draft maps onto `Plan`/`PlanSlot` the way the routine draft maps onto `Routine`/`RoutineStep`.

### D6 — Completion and repeat

Advancing past the final slot of the final week either: (repeat on) resets the cursor to week 1 slot 1 silently and increments nothing user-visible beyond the fresh progress readout, or (repeat off) marks the run complete — the up-next card becomes a quiet completion card ("Plan complete") with Restart and Done actions. Restart resets the cursor and tally; Done deactivates the plan. Completion stats stay time-honest per PRD (session counts and active time, derived from stamped sessions; no fabricated scores).

### D7 — Deleting things a plan points at

Deleting a routine that plan slots reference leaves the slots in place showing the routine-name snapshot in a disabled "routine removed" state — the plan's shape (the user's authored intent) survives; the user repairs by re-pointing or removing the slot. Deleting a plan cascades its slots and never touches routines or sessions. This mirrors the existing snapshot philosophy (`workoutNameSnapshot`, `routineNameSnapshot`) — display survives referent deletion.

## 5. Edge cases

**Cursor reconciliation on edit:**
- Slot under the cursor removed → cursor moves to the next surviving slot (or week); if nothing survives ahead, plan-complete rules (D6) apply.
- Weeks reordered/inserted before the cursor → cursor follows its slot object, not its numeric position (progress readout recomputes).
- All slots removed → editor allows saving an empty plan but an empty plan cannot be activated; an active plan edited to empty deactivates with the completion card suppressed (no "complete" for zero work).

**Activation:**
- Activating plan B while A is active: A deactivates, keeps its cursor; reactivating A resumes.
- Fresh plan activation starts at week 1, slot 1; reactivating a completed non-repeating plan offers restart.

**Sync (CloudKit private DB):**
- Cursor advanced on two devices before sync → last-writer-wins on the Plan record, consistent with the rest of the app; sessions from both devices survive (append-only), so at worst the up-next card repeats one slot — acceptable, never data loss.
- Concurrent activation on two devices converges deterministically after sync: the most recently updated non-empty plan remains active (with id as a stable tie-breaker) and every other plan is deactivated.
- Slot's routine deleted on another device → D7 removed-state renders on next launch.

**Player interplay:**
- Up-next launch while another session is somehow in flight follows existing player rules (player is modal; no concurrent sessions).
- Skip is available only for the current slot — no skipping arbitrarily ahead (edit the plan instead).

**Empty/degenerate states:**
- No plans yet → Plans section shows a standard empty state with a create affordance.
- One-week plan with repeat on behaves as a weekly loop (the "weekly plan" case); a four-week plan is the "monthly plan" case — no separate weekly/monthly modes exist.
- A week with zero slots is allowed (an authored rest week); the cursor passes through it without stopping.

## 6. Accessibility & localization

New string-catalog keys (English values; all in `Localizable.xcstrings`):

| Key | Value | Notes |
|---|---|---|
| `plans.section.title` | `Plans` | Home section header / entry point |
| `plans.empty.title` | `No Plans Yet` | Empty state |
| `plans.empty.message` | `Group your routines into a weekly or monthly plan.` | Empty state body |
| `plans.new` | `New Plan` | Create affordance |
| `plans.upNext.title` | `Up Next` | Hero card label |
| `plans.upNext.skip` | `Skip` | Advances cursor without a session |
| `plans.progress.week` | `Week %1$lld of %2$lld` | Progress readout |
| `plans.progress.workouts` | `%1$lld of %2$lld workouts done` | Plural variants on both counts |
| `plans.complete.title` | `Plan Complete` | Completion card |
| `plans.complete.restart` | `Restart Plan` | Completion action |
| `plans.complete.done` | `Done` | Deactivates |
| `plans.editor.addWeek` | `Add Week` | Editor |
| `plans.editor.duplicateWeek` | `Duplicate Week` | Editor |
| `plans.editor.duplicatePlan` | `Duplicate Plan` | Editor / context menu |
| `plans.editor.addRoutine` | `Add Routine` | Slot insertion |
| `plans.editor.weekTitle` | `Week %lld` | Week headers |
| `plans.editor.weekdayLabel` | `Day Label` | Optional weekday-label picker title |
| `plans.slot.routineRemoved` | `Routine removed` | D7 disabled slot state |
| `plans.activate` | `Start Plan` | Activation |
| `plans.deactivate` | `Stop Plan` | Deactivation |
| `plans.repeat.toggle` | `Repeat when finished` | Plan setting |
| `plans.delete.confirm.title` | `Delete Plan?` | Destructive confirmation |

Weekday labels use `Calendar`/`DateFormatter` localized standalone weekday symbols — never catalog strings. Durations on the up-next card come from the compiled timeline through the existing duration formatter.

Accessibility identifiers: `plans.home.section`, `plans.upNext.card`, `plans.upNext.play`, `plans.upNext.skip`, `plans.editor.list`, `plans.editor.addWeek`, `plans.editor.save`, `plans.detail.activate`, `plans.complete.restart`.

VoiceOver: the up-next card is one grouped element ("Up next, Push Day, Week 2 of 4, 32 minutes"), with Play and Skip as actions. Editor rows announce "Week 2, slot 1, Push Day" with reorder support via standard list reordering. Dynamic Type: the hero card wraps to vertical stacking at accessibility sizes; progress readout never truncates below AX3 (wraps to two lines).

## 7. Test impact

- **Core (`make test-core`)**: plan snapshot + progress derivation (week/slot counts, cursor math, wrap/complete/repeat, empty-week pass-through, reconciliation after slot removal) — pure unit tests, no persistence.
- **App unit (`make test-app-unit`)**: Plan/PlanSlot persistence round-trip; activation exclusivity; cursor advance on completed session, non-advance on abandoned session; D7 removed-routine state; save-or-rollback on editor drafts.
- **UI**: create plan → activate → up-next card appears with correct progress; complete a (short, seeded) session from the card and verify cursor advance; skip advances without a session row; edit active plan and verify immediate effect; completion card and restart.
- **Mac lane (`make test-mac`)**: plans home section and editor render and operate (shared UI, size-class adaptive; no device-type branches).
- Full `test-app`/`test-ipad`/`test-mac` at closeout per CLAUDE.md ladder.

## 8. Acceptance criteria

1. A user can create, edit, duplicate, and delete a plan of N weeks × ordered routine slots, with optional weekday labels and a repeat toggle; authoring supports duplicate-week.
2. Exactly one plan is active at a time; the routines home shows the Up Next hero with plan name, week-of-week progress, next routine, and compiled duration.
3. Completing a session launched from the card advances the cursor and stamps the session; skipping advances without a session; ad-hoc routine runs never move the cursor; abandoned sessions never advance it.
4. Mid-plan edits apply immediately ahead of the cursor; logged sessions are never rewritten; all cursor-reconciliation edge cases in §5 behave as specified.
5. Plan completion presents restart/done (or loops silently with repeat on); deleting a referenced routine degrades slots to the removed state without breaking the plan.
6. PRD §2, DESIGN.md, and `design/ui-spec.html` are amended in the same change; every string in §6's table is in the catalog with plural variants where noted; all identifiers exist; VoiceOver grouping and AX-size wrapping behave as specified.
7. `make test-core`, `make test-app-unit`, and the full app/iPad/Mac lanes pass at closeout.
