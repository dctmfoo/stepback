# SPEC — Plans redesign: the weekly schedule ("Today / My Week") model

**Status:** Implemented
**Owner screens:** `StepBack/Features/Plans/` (redesigned: `PlansSection.swift` removed, `UpNextPlanCard.swift` → Today card, `PlanCompletionCard.swift` removed, `PlanDetailView.swift` → week overview, `PlanEditorView.swift` → day-bucket editor, `PlansListView.swift` → plan picker), `StepBack/Features/Routines/RoutinesHomeView.swift` (amended: Today-first composition), `StepBack/Persistence/Models.swift` (amended: `Plan`/`PlanSlot` weekday shape + migration), `StepBackCore` (amended: plan snapshot, today/week derivation replaces cursor progress), `AgentBridge` plan verbs + `plugin/` contract docs/schemas/fixtures
**Docs this spec amends:** PRD.md §4.4 (session plan stamps), §4.5 (`Plan`/`PlanSlot`), §5.2 (home + plan screen bullets), §9-adjacent agent-bridge wording (G13 ¶ and the bridge non-goals line on "calendar scheduling"), DESIGN.md §4 (Up Next plan card → Today card; plan card/detail/editor entries), §5 (plan-surfaces line), `design/ui-spec.html` (all Plans frames), `plugin/README.md` + `plugin/schema/` + `plugin/fixtures/` + both `stepback-coach` skills (plan payload shape and verbs)
**Branch:** `codex/plans-weekly-schedule-redesign`
Sequencing: lands after the in-flight `codex/player-portrait-stacked-stage` branch merges; supersedes the plan-model decisions D1–D6 of `SPEC-training-plans.md` (D7's snapshot rule survives) and amends the plan surface of `SPEC-agent-bridge.md`.

---

## 1. Problem

The shipped training-plans feature is a sequential program: ordered weeks of ordered slots, a stored cursor, and an activation lifecycle ("Start Plan" / "Stop Plan"). Owner feedback after living with it: **it doesn't map to how he thinks**. His mental model — stated verbatim — is "a plan to do a routine or more each day of the week." The shipped model produces concrete confusions visible on the home screen today:

- "Start Plan" reads as *start working out now* (colliding with Play), when it actually means *enter an abstract activated state*. "Stop Plan" reads as *quitting*, when it means *deactivate*. Neither verb corresponds to anything a person does with a weekly schedule.
- Activation is buried: creating a plan does **not** activate it (`PlanEditorModel.save` never sets `isActive`), and the only Start Plan control sits two taps away on plan detail. A freshly created plan silently does nothing to the home screen except render a grey icon.
- "Week 1 of 1 · 0 of 1 workout done" is cursor bookkeeping leaking into the hero card. For the common case (one repeating week) "Week 1 of 1" is pure noise.
- The Up Next hero and the Plans-section card show the same plan twice on one screen, with a Skip button whose meaning (advance a cursor without logging) is invisible.
- "Up Next" answers *what is next in an abstract sequence*; the owner wants *what do I do **today***.

Research (Apple Fitness+ Custom Plans, Hevy, Boostcamp, Peloton programs, 2026): the two dominant models are day-numbered sequential programs (Boostcamp — right for finite periodized strength programs with progression, which PRD §2 excludes) and **weekday-anchored weekly schedules** (Apple Fitness+ Custom Plans: "tap the days you want to work out", the app then surfaces *today's* workout). Weekday assignment is Hevy's most-requested missing feature — users fake it with folder ordering and a "Routine of the day" widget. For an app whose plans are pure user-composed sequencing with no progression, the weekly schedule is the model that matches both the owner's words and the strongest industry pattern.

## 2. Goals

- G1. A plan **is a week**: each weekday holds zero or more routines; a day with none is a rest day. No week numbers, no cursor, no completion lifecycle — the week simply repeats.
- G2. The home screen leads with a **Today card**: today's planned routine, its compiled duration, and Play. The app's first answer is always "here is today."
- G3. **No activation verbs.** A sole plan drives Today automatically. With several plans, the user picks which one is "My Week" — a selection, like choosing a default, never a start/stop lifecycle.
- G4. **Done is derived, never stored.** A day's slot is done iff a completed session of that routine exists on that local calendar day — same read-time honesty as the streak (PRD §7). Ad-hoc runs count; there is nothing to advance and nothing to skip.
- G5. Editing is a seven-day form: pick routines per day. Existing plan data migrates without loss of authored content.
- G6. The agent bridge keeps full plan authoring under the new shape, with verbs that match the new model.

## 3. Non-goals

Checked against PRD §2; this spec *narrows* the plans surface rather than growing it:

- No finite multi-week programs, periodization, or progression — explicitly cut with the sequential model. If a genuine multi-week need appears later it returns as its own spec; the migration (D7) shows multi-week intent survives as multiple plans.
- No calendar-**date** anchoring, notifications, or reminders. Weekday assignment is not date scheduling: nothing is ever "missed", nothing references a specific date.
- No missed/catch-up states of any kind (owner decision: yesterday scrolls away; today is the only question the card answers).
- No plan templates, sharing, generation, or suggestion — unchanged.
- No multiple concurrent "My Week" selections; no per-plan history views.

## 4. Design decisions

### D1 — A plan is a repeating week of weekday buckets (supersedes SPEC-training-plans D1)

A plan holds seven weekday buckets (Monday…Sunday); each bucket holds an ordered list of routine slots (usually one, occasionally more). Empty bucket = rest day, still not an entity. Display order of days follows the user's locale first-weekday via `Calendar`; the buckets themselves are fixed weekdays, not positions.

Rationale: this is the owner's stated mental model and the Apple Fitness+ Custom Plans pattern ("Select your weekly schedule: tap the days you want to work out"). The sequential model's honest advantages (finite programs, progression arcs) are things PRD §2 excludes anyway — the shipped design was carrying complexity for a use case the product forbids. Rejected: the hybrid (weekday labels over a sequential cursor) — it keeps two sources of truth for "where am I" and keeps every confusing element (cursor, Start/Stop, Skip) the owner flagged.

### D2 — No activation lifecycle; "My Week" is a selection (supersedes D3 of the old spec)

The `Start Plan` / `Stop Plan` buttons, the activation section on plan detail, and the started/stopped mental state are removed. Instead:

- **One plan** (the overwhelmingly common case): it is My Week automatically, immediately on save. Creating your first plan makes the home Today-first with zero further taps — fixing the shipped dead-end where a new plan does nothing.
- **Several plans** (e.g. "Normal week", "Travel week"): exactly one is My Week. Every other plan's overview screen offers one selection action, **"Set as My Week"**; the current one shows a quiet "My Week" label instead. Switching is instant and stateless — nothing pauses, nothing resets, because there is no cursor to preserve.
- **Deleting the current plan** with others remaining does not silently promote another: the Today surface shows a calm chooser ("Choose your week") until the user picks. With no plans left, the home reverts to the pre-plans composition plus the plan-your-week nudge (D3).

This satisfies DESIGN.md's accent/verb discipline indirectly: the only imperative verbs on plan surfaces are now Play and Edit — words that mean what they say. Rejected: "Follow/Following" (social-app vocabulary in a private no-accounts app) and keeping Start/Stop with better copy (the verbs are wrong, not the copy).

### D3 — Today-first home: the Today card replaces Up Next, the Plans section, and the completion card

The Routines home leads with one **Today card** when a My Week plan exists, replacing three shipped surfaces (Up Next hero, Plans section with See All/+, completion card). Composition, citing the rules that constrain it:

- **Kicker:** caption-level uppercase "TODAY · WEDNESDAY" (weekday from `Calendar` localized standalone symbols) in Pulse Azure — same kicker grammar as the shipped "UP NEXT" (DESIGN.md §4 Up Next card: "Caption-level Pulse Azure" kicker; §3: "Caption label 11 semibold UPPERCASE … section kickers").
- **Routine name** at title2 bold, **compiled duration** in the hero-stat style — the same hierarchy as the routine card's "name, hero-stat duration" (DESIGN.md §4). The compiled timeline remains the single source of the displayed total (PRD §6.2). This card is the screen's one hero number; routine-card durations below it step down one weight grade to keep "One hero number per screen" (DESIGN.md §5) true — a deliberate DESIGN.md §4 routine-card amendment shipped with this spec.
- **Week strip:** seven small day marks in locale order — filled check for days with a completed planned session this week, Pulse-Azure ring on today, quiet dot for planned days, near-invisible placeholder for rest days. It is a schedule readout, not a chart (PRD §2 excludes charts; this renders authored structure + derived facts only, no aggregation). One line, no labels beyond single initials from `Calendar` `veryShortStandaloneWeekdaySymbols`.
- **One action:** the inline circular Pulse Azure **Play** — "the one-tap-from-launch promise" (DESIGN.md §4 routine card). No Skip (nothing to skip), no second button. Tapping the card body opens the My Week overview (D5).
- **States**, all on the same standard grouped surface (never a third glass element — the two-element custom glass budget stands, DESIGN.md §6):
  - *Planned + not done:* as above.
  - *Planned + done:* checkmark treatment, "Done for today", the completed routine's name, and the week strip; Play is replaced by nothing — the card goes quiet. (Doing more remains one tap away on any routine card below; the plan never demands more.)
  - *Multiple routines today:* the card shows the first not-yet-done slot; when all are done it shows the done state. A footnote counts "2 of 3 today" only when a day genuinely holds several routines.
  - *Rest day:* "Rest Day" with the next planned day and routine as a footnote ("Next: Thursday · Legs"). Icon tile uses Recover Mint Soft — a rest-adjacent soft fill, exactly the DESIGN.md §2 contract ("Recover Mint means rest only"; Mint Soft: "Rest-adjacent soft fills"). No Play on a rest day; the routines below remain available.
- Below the Today card: the motivation strip and routine cards, unchanged. Beneath the routine list, one quiet standard row — **"My Week · «plan name» ›"** — is the single management entry point (opens D5's overview). With multiple plans a "Choose your week" variant appears when none is selected (D2). The shipped Plans card section, "See All", and its "+" are deleted: the duplication between hero and section card was a flagged confusion.
- **No plans yet:** one quiet nudge row in the same slot — "Plan your week" with a footnote "Pick a routine for each day." Standard surface, one line; not the shipped `ContentUnavailableView` block, which gave a not-yet-used feature a hero-scale empty state. VoiceOver: the Today card is one grouped element ("Today, Wednesday, Push Day, 32 minutes, 3 of 5 days done this week") with Play as an action — same grouping discipline as the shipped card.

### D4 — Done is derived from session history; the cursor, Skip, and completion lifecycle are removed (supersedes D4/D6)

A slot is **done** iff a `RoutineSession` with `wasCompleted == true` for that routine exists on that slot's local calendar day. Consequences:

- Ad-hoc runs count: playing today's routine from its routine card, the gallery, or plan overview marks today done. The shipped distinction between "launched from the card" and "launched elsewhere" — invisible and surprising — disappears.
- Nothing advances, so **Skip is deleted**. Tomorrow arrives on its own; a rest day needs no acknowledgment.
- **Plan completion, the completion card, Restart, and the repeat toggle are deleted.** A repeating week has no end. (`plans.repeat.toggle`, `plans.complete.*` retire.)
- Derivation is a pure `StepBackCore` function over (plan snapshot, session day/routine facts, today's weekday, locale week) — same shape and testability as `DerivedStats`, honoring "streak computed … at read time (never a stored counter)" (CLAUDE.md / PRD §7). Timezone changes resolve at read time like the streak does.
- Sessions keep their plan stamps for history honesty: `planIDSnapshot`/`planNameSnapshot` stay; `planWeekIndex`/`planSlotIndex` stop being written (fields retained inert for CloudKit compatibility) and a `planWeekday` stamp is **not** added — the stamps were for stats context, and routine + date already carry everything the weekly model needs.
- "This week" on the week strip uses the local calendar week (locale first-weekday), consistent with weekly-minutes stats.

### D5 — Plan overview and picker replace plan detail and the plans list

- **My Week overview** (reworked `PlanDetailView`): an inset-grouped list of seven day rows in locale order — day name, routine name(s) with compiled durations, "Rest" for empty days, done-today/this-week checks, today's row accented in Pulse Azure (same role the "current slot" accent had, DESIGN.md §4 plan detail). Toolbar: Edit (pencil). Management (Duplicate Plan, destructive Delete Plan with confirmation) stays in a bottom section, unchanged pattern. Removed-routine slots keep the D7 snapshot treatment from the original spec verbatim ("Routine removed" secondary label; the plan's shape survives).
- **Plan picker** (reworked `PlansListView`, reached from the overview only when ≥2 plans exist, plus the D2 chooser state): plain list, each row name + a footnote summarizing the week ("5 days · Push, Pull, Legs…"), current plan marked "My Week", tapping another plan opens its overview where "Set as My Week" lives. "+" to create. The shipped per-plan "N of M workouts done" progress line retires — cross-plan progress was cursor vocabulary.
- The "Edited by agent" provenance footnote carries over unchanged.

### D6 — The editor becomes a seven-day form (supersedes D5's week/slot editor)

`PlanEditorView` keeps the sheet + `@Observable` draft + save-or-rollback transaction discipline (`RoutineBuilderModel` pattern via `ModelContext+Save`), but its content becomes seven fixed day sections in locale order. Each section: the day name header, its routine rows (reorderable within the day, replace/delete via the existing row actions), and "Add Routine" (the existing gallery-backed routine picker). An empty day's section body reads "Rest" in secondary text — rest days are visible, calm, and require no action. Name field stays; the repeat toggle, Add Week, Duplicate Week, week-actions menu, and weekday-label menu are all deleted (the day *is* the structure, so the display-only label concept dies). Saving the first plan makes it My Week (D2). Edits apply immediately — with no cursor there is nothing to reconcile, deleting the shipped reconciliation edge-case class entirely.

### D7 — Migration: authored content survives, bookkeeping does not

One-time lightweight migration on first launch at this version (an idempotent data pass, not a SwiftData schema migration — fields are only added or ignored, per CloudKit rules: new attributes optional/defaulted, none removed or renamed):

- Week 1 of each existing plan maps into weekday buckets: slots with a weekday label land on that day (preserving intra-day order); unlabeled slots fill the user's locale week in order onto empty days, overflow appending to the last day. 
- Weeks 2+ each become their own plan, named "«name» · Week N" — multi-week authorship survives as switchable weeks rather than being flattened or dropped.
- The shipped `isActive` flag maps to the My Week selection (its stored meaning — at most one true — is exactly the selection invariant, so the attribute is kept and re-documented rather than replaced). Cursor and tally fields stop being read or written; they remain inert in the store.
- Sync: a pre-update device writing cursor fields loses nothing — the fields are ignored, not conflicting. My Week selection conflicts resolve last-writer-wins with the deterministic tie-break the shipped exclusivity reconciliation already has.

### D8 — Agent bridge: same authoring power, new shape (amends SPEC-agent-bridge)

The bridge keeps full plan authoring; the contract changes shape with a manifest/command **schema version bump**:

- Manifest plans serialize as weekday buckets (day → ordered routine refs) plus the My Week marker; cursor/repeat fields disappear from the manifest.
- `createPlan`/`updatePlan` payloads take the weekday-bucket shape. Update remains full-replacement and non-destructive.
- `activatePlan` is retained but re-documented as "set as My Week" (selection semantics; behaviorally identical to the human action). `deactivatePlan` is **removed from the schema**: commands using it fail validation with a clear outcome message naming the replacement model. Rationale: a no-op success would lie to agents; the protocol has no other deprecated-verb precedent to follow.
- `plugin/README.md`, JSON schemas, fixtures (valid + invalid, including a rejected `deactivatePlan`), and both `stepback-coach` skills update in the implementation commit. PRD G13/§9 bridge wording and the bridge non-goals line ("Calendar scheduling … for plans") gain the D1 clarification: weekday assignment is in scope; date anchoring stays out.

## 5. Edge cases

- **Today has multiple routines:** card surfaces the first not-done slot; finishing it and returning home reveals the next; all done → done state. The "2 of 3 today" footnote appears only on multi-routine days.
- **Same routine on two days:** each day derives independently (done = session on *that* day). Doing Thursday's routine on Wednesday marks Wednesday's identical slot done (routine + day match is the whole truth); Thursday still shows it planned — honest and predictable.
- **Same routine twice on one day:** N slots need N completed sessions that day; the deriver counts sessions, not booleans.
- **Session completed just before midnight, home viewed after:** derivation is read-time against local days; the card flips back to "planned" for the new day. Matches streak behavior; no stored state to correct.
- **Routine deleted:** slot degrades to the name-snapshot "Routine removed" state (old D7 verbatim) in overview and editor; if it is today's only slot, the Today card shows the removed state with Edit as the affordance instead of Play (never a dead Play button — the shipped card already disables Play here; this spec upgrades that to a repair path).
- **Plan edited on another device:** Today re-derives on appear; no reconciliation needed. My Week conflict → D7 sync rule.
- **Entirely empty plan (all rest):** overview shows seven Rest rows; Today card shows the rest state with no "Next" line and an Edit affordance footnote. An empty plan can be My Week (it is simply an empty schedule — no activation gate exists anymore).
- **Weeks with locale first-weekday ≠ Monday:** all ordering (editor sections, overview rows, week strip) follows `Calendar`; the buckets are absolute weekdays so a locale change reorders display without moving assignments.
- **Migration degenerates:** plan with >7 unlabeled week-1 slots → overflow appends to the last day (user repairs in the editor, nothing lost); plan with zero slots → empty plan; two labels on the same day → both slots that day, order preserved.

## 6. Accessibility & localization

New string-catalog keys (English values; all in `Localizable.xcstrings`; keys never renamed for copy changes, so semantic changes get new keys):

| Key | Value | Notes |
|---|---|---|
| `plans.today.kicker` | `Today` | Card kicker; weekday appended via formatter, never in the catalog |
| `plans.today.done.title` | `Done for Today` | Done state |
| `plans.today.rest.title` | `Rest Day` | Rest state |
| `plans.today.next` | `Next: %1$@ · %2$@` | Weekday name (formatter) + routine name |
| `plans.today.multi.count` | `%1$lld of %2$lld today` | Plural variants; multi-routine days only |
| `plans.today.strip.accessibility` | `%1$lld of %2$lld days done this week` | Week-strip VoiceOver value; plural variants |
| `plans.myWeek.title` | `My Week` | Management row, overview label, picker badge |
| `plans.myWeek.row` | `My Week · %@` | Home management row with plan name |
| `plans.myWeek.set` | `Set as My Week` | Selection action on non-current plan overview |
| `plans.myWeek.choose` | `Choose Your Week` | D2 chooser state after deleting the current plan |
| `plans.nudge.title` | `Plan Your Week` | No-plans nudge row |
| `plans.nudge.message` | `Pick a routine for each day.` | Nudge footnote / editor guidance |
| `plans.day.rest` | `Rest` | Empty day in overview + editor |
| `plans.picker.summary` | `%1$lld days · %2$@` | Picker row footnote: planned-day count (plural) + routine-name list |
| `plans.today.repair` | `Fix in Editor` | Removed-routine Today state affordance |

Weekday names, single-initial strip labels, and durations come from `Calendar`/Foundation formatters — never the catalog. **Retired keys** (values removed from UI; catalog entries deleted in the implementation commit since no screen references them): `plans.activate`, `plans.deactivate`, `plans.upNext.title`, `plans.upNext.skip`, `plans.progress.week`, `plans.progress.workouts`, `plans.complete.title`, `plans.complete.restart`, `plans.complete.done`, `plans.repeat.toggle`, `plans.editor.addWeek`, `plans.editor.duplicateWeek`, `plans.editor.weekTitle`, `plans.editor.weekActions`, `plans.editor.deleteWeek`, `plans.editor.weekdayLabel`, `plans.editor.noDayLabel`, `plans.week.rest`, `plans.slot.accessibility`, `plans.see-all`, `plans.empty.title`, `plans.empty.message`. Kept as-is: `plans.new`, `plans.edit`, `plans.editor.addRoutine`, `plans.editor.replaceRoutine`, `plans.editor.duplicatePlan`, `plans.slot.routineRemoved`, `plans.delete`, `plans.delete.confirm.title`, `plans.defaultName`, `plans.section.title` (picker nav title "Plans").

Accessibility identifiers: `plans.today.card`, `plans.today.play`, `plans.myWeek.row`, `plans.myWeek.set`, `plans.nudge.row`, `plans.overview.list`, `plans.picker.list`, `plans.editor.list`, `plans.editor.save` (existing editor/save ids persist). VoiceOver grouping: Today card one element with Play action (D3); overview day rows announce "Wednesday, Push Day, 32 minutes, done" as one element each; the week strip is one element with the summary value above, never seven dots. Dynamic Type: the Today card stacks its duration below the name at accessibility sizes via the existing `ViewThatFits` discipline; the week strip hides at AX3+ in favor of its text summary (a readout, not information loss — the summary is the accessible value at every size).

## 7. Test impact

- **Core (`make test-core`)**: replace cursor/progress deriver tests with today-resolution and done-derivation tests — weekday bucket lookup, first-undone-slot selection, multi-slot counting, same-routine-two-days independence, week-strip derivation across locale first-weekdays, read-time day boundaries. Migration mapping (labels → buckets, unlabeled fill, weeks 2+ split, overflow) as pure functions over snapshots.
- **App unit (`make test-app-unit`)**: migration pass idempotence on the persistence layer; first-plan auto-selection; My Week exclusivity + deletion chooser state; retired-field inertness (cursor fields untouched by new writes); bridge command validation (weekday payloads accepted, `deactivatePlan` rejected with the specified outcome).
- **UI (focused, then full lanes at closeout)**: create first plan → Today card appears without further taps; complete today's routine ad-hoc → card flips to done; rest-day state; multi-plan Set-as-My-Week switch; editor seven-day form add/reorder/save; removed-routine repair path.
- **Mac lane**: overview/editor/picker render and operate via the hosted workflow only if AppKit-specific behavior is genuinely touched; otherwise local lanes suffice per the verification ladder.
- Bridge fixtures re-recorded; `plugin/` schema tests updated.

## 8. Acceptance criteria

1. A plan is a seven-weekday schedule; the editor is a seven-day form with per-day routine lists and visible Rest days; no week numbers, cursor, repeat toggle, Skip, or completion lifecycle exists anywhere in the UI.
2. Saving the first plan immediately drives a Today card on the home with kicker, routine, hero compiled duration, week strip, and one Play; rest-day, done, multi-routine, removed-routine, chooser, and no-plans states render per D3, and the shipped Plans section/See All/completion card are gone.
3. "Start Plan"/"Stop Plan" no longer exist; with multiple plans exactly one is My Week, switched only via "Set as My Week"; deleting the current plan yields the chooser state, never silent promotion.
4. Done-today derives at read time from completed sessions (ad-hoc runs count; abandoned sessions don't); no plan-progress state is stored beyond the My Week selection; existing cursor fields are inert but present.
5. Migration converts every existing plan per D7 with no loss of authored slots, verified by unit tests over the degenerate cases in §5.
6. The agent bridge accepts weekday-shaped create/update and selection-semantics `activatePlan`, rejects `deactivatePlan` with a clear outcome, and the manifest, schemas, fixtures, and both skills reflect the bumped schema.
7. PRD §4.4/§4.5/§5.2/G13+bridge non-goals, DESIGN.md §4/§5, and `design/ui-spec.html` are amended in the same change; §6's key table is fully in the catalog with plural variants, retired keys are removed, identifiers exist, and VoiceOver/Dynamic Type behave as specified.
8. `make test-core`, `make test-app-unit`, and the full app/iPad lanes pass at closeout; the Mac lane per the verification ladder.
