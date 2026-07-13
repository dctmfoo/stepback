# Spec: Milestone 3 — Browsing UI (Routines home, Gallery, detail screens)

**Status:** Implemented
**Owner screens:** `StepBack/Features/Shell/` (new — app shell: TabView scaffold, Mac split view, environment wiring), `StepBack/Features/Shared/` (new — `WorkoutVisual`, step/rest row components, category chip), `StepBack/Features/Routines/` (new — Routines home, motivation strip, routine card, routine detail), `StepBack/Features/Gallery/` (new — gallery, compact category page, workout detail, custom-workout editor, add-to-routine sheet), `StepBack/Features/Settings/` (new — minimal Settings tab), `StepBack/ContentView.swift` (retired — replaced by the shell), `StepBack/StepBackApp.swift` (root wiring), `StepBack/Resources/Localizable.xcstrings` (all new UI strings), `StepBackTests/` + `StepBackUITests/` (new browsing suites), `PLAN.md` (Milestone 3 status line)
**Docs this spec amends:** `PRD.md` §5.2 (two zero-state amendments and restore-starters semantics, spelled out in D6/D7/D9 — the implementation commit applies them). `DESIGN.md` §4 (motivation-strip zero-state rule and routine-card never-played line, D6/D7). `design/ui-spec.html` §routines (notes for the same two states and the restore semantics).

**Branch:** `codex/milestone-3-browsing-ui`. **Sequencing:** Milestone 2 is committed and green except the externally blocked signed-macOS gate; per the checkpoint rule, implementation of this spec starts only after that gate closes (PLAN.md Milestone 2 flips to `gate passed`). Implementer flips this spec to Status: Implemented and PLAN.md Milestone 3 to `in progress` in the opening commit / `gate passed YYYY-MM-DD (<short-hash>)` in the closing one.

---

## 1. Problem

Milestone 2 shipped a seeded, synced store and a 92-workout catalog behind a placeholder `ContentView`. Nothing is browsable: no tabs, no Routines home, no gallery, no way to see a routine or add a custom workout. PLAN.md Milestone 3 requires the browsing surfaces — tab scaffold, Routines home with motivation strip and routine cards, routine detail, gallery with categories + search + workout detail, custom-workout create/edit, the `WorkoutVisual` media-ready component, and designed empty states — with every string in the catalog and accessibility identifiers per screen.

This spec was also written against a "world-class UX" review pass (owner request): the canonical mockups were checked against current iOS 26 platform conventions (search tab role, tab-bar minimize behavior, transparent-by-default bars) and against the design values that distinguish award-tier fitness apps (Gentler Streak / The Outsiders: calm, honest, recovery-respecting, zero-shame surfaces). The verdict: the existing DESIGN.md/ui-spec direction already embodies those values; the real gaps were **unspecified zero-states and dead-end actions**, which this spec closes (D5–D9) rather than inventing new visual patterns.

## 2. Goals

- G1. **App shell:** three-tab `TabView` on iPhone/iPad, `NavigationSplitView` shell on Mac, per PRD §5 and DESIGN.md §10 — size classes and platform idioms only, no device-type branches.
- G2. **Routines home** per ui-spec §routines: motivation strip, adaptive routine-card grid sorted most-recently-played first, inline Play affordance, designed empty state with New Routine + Restore starter routines.
- G3. **Routine detail** per ui-spec §routine-detail: hero total from the compiled timeline, faithful step/rest row preview, stats line, Play primary, Duplicate/Delete secondary (Edit arrives with the Milestone 4 builder).
- G4. **Gallery** per ui-spec §gallery: category-sectioned adaptive grid in regular width, category pages in compact, `.searchable` across built-ins + custom workouts, "Add your own" affordance, custom workouts inline with the "Yours" caption.
- G5. **Workout detail + custom workouts** per ui-spec §workout-detail: 4:3 media slot, focus-area chips, "Appears in N routines", Add to Routine (existing routine or new-with-this-step), create/edit/delete custom workouts.
- G6. **`WorkoutVisual`** shipped as the single media-ready component (PRD §4.6) at all Milestone 3 sizes (1:1 small row tile, 1:1 gallery card, 4:3 detail header).
- G7. **Localization + accessibility:** every user-facing string in `Localizable.xcstrings` (§6 table), accessibility identifiers per screen, VoiceOver grouping per composite element, Dynamic Type through AX sizes.
- G8. **Gate:** ui-spec §routines/§gallery conformance check against the running app, VoiceOver pass on the Routines and Gallery tabs, pseudolocalization render check (PLAN.md Milestone 3 gate).

## 3. Non-goals

- **No routine builder** — creating/editing steps, reorder, pickers, the floating glass bar are Milestone 4. Consequences handled here: routine detail ships without an Edit action (D8), and "New Routine" from the gallery creates a one-step routine directly (D12) rather than opening a builder.
- **No player** — Milestone 5. Play affordances render per the card anatomy but route through a stubbed launcher protocol (D5); no full-screen stage, no audio, no idle-timer work.
- **No welcome screen** — Milestone 6 per PLAN.md; first launch lands directly on the seeded Routines home.
- **No session recording and no live stats** — Milestones 5/6. The motivation strip and stats lines ship with their real derivation (StepBackCore stats over `RoutineSession` rows) but the store has no sessions yet, so the zero-states in D6/D7 are what users actually see; no fake numbers, ever (PRD §7 honesty).
- **No Settings behavior** — the tab ships with the privacy line and version footer only (D14); audio toggles and get-ready arrive with the player (Milestone 5), the iCloud status line with hardening (Milestone 7).
- **No media content** — `WorkoutVisual` renders the monogram tile only; `mediaKey` stays nil (PRD §4.6). No instructions text (`instructionsKey` reserved, PRD §10).
- Checked against PRD §2 non-goals: no charts/rings/dashboards (motivation strip is one quiet row), no awards, no social, no color pickers for custom workouts (category hue only, DESIGN.md §2).

## 4. Design decisions

- **D1. Shell: `TabView` with `Tab` values on iOS/iPadOS; `NavigationSplitView` on macOS.** `Tab` (iOS 18+/macOS 15+) and `NavigationSplitView` verified in the offline docset — both inside the 26.0 floor. The Mac sidebar lists Routines / Gallery / Settings with content + detail columns per ui-spec §platforms; the platform split is an `#if os(macOS)` idiom at the shell only, which DESIGN.md §10 explicitly prescribes ("Size classes and platform idioms drive every difference") — feature views below the shell are shared and size-class-driven. Tab bars keep system material and behavior: no custom backgrounds (DESIGN.md glass budget: "system-owned … always system material"), no `tabBarMinimizeBehavior` override, no bottom accessory — considered and rejected as decoration; the iPadOS 26 floating pill comes free.
- **D2. Search stays `.searchable` on the Gallery, not a system search Tab.** iOS 26 offers `Tab(role: .search)` (bottom-trailing dedicated search tab). Rejected: StepBack's search scope is the workout library only — a system search tab implies app-wide search (routines + settings + workouts), which doesn't exist and isn't wanted; PRD §5 fixes "search lives in `.searchable` on Gallery" and DESIGN.md §5 repeats it. Recording the rejection here so the convention was consciously weighed, not missed.
- **D3. `WorkoutVisual` contract (the component this milestone creates).** One view, three inputs: workout reference (catalog id or custom-workout id), rendered size variant (`smallRow` 1:1, `galleryCard` 1:1, `detailHeader` 4:3 — the DESIGN.md `media_readiness.slots` table; the 4:3 stage variant is declared in the API now, used in Milestone 5). Today it always resolves to the monogram: category-hue soft fill with the category SF Symbol, concentric radius (DESIGN.md: "Monogram tile: category-hue soft fill, category SF Symbol, concentric radius. Same tile family at every size"). Soft fill is the category color at 13% opacity over the surface — ui-spec §gallery's documented recipe ("hue at ~13% over surface — the same recipe as PulseAzureSoft"), which adapts to dark automatically without new asset pairs or `colorScheme` branches. Resolution rules: custom workout → its category's hue/symbol; catalog id missing from the current catalog (PRD §4.1 resilience) → the DESIGN.md fallback symbol `figure.strengthtraining.functional` on `systemFill` — quiet, never blank, never an error. Feature code renders workouts **only** through this component (PRD §4.6.2).
- **D4. Routines home.** Adaptive `LazyVGrid` in regular width, single column in compact (DESIGN.md §5: "never a stretched single column"). Card anatomy exactly per DESIGN.md §4/ui-spec: name (body medium) → hero duration (hero-stat role, rounded semibold tabular, from the compiled timeline — PRD §6.2 one source of truth) → workout count + category-mix dots (one dot per distinct category, catalog order, non-interactive) → stats footnote → inline circular PulseAzure Play (≥ 44 pt, a separate target from the card's navigation). Sort: most recently played first (PRD §5.2), defined as: latest `RoutineSession.startedAt` for the routine (completed or partial), never-played routines after all played ones, tie-break `createdAt` descending then `id` — deterministic before sessions exist (seeded order on day one). Context menu on the card: Play, Duplicate, Delete (destructive role) — Delete never rides a swipe on the card (DESIGN.md §5).
- **D5. Play affordances route through a `PlayerLauncher` protocol injected via the environment; Milestone 3 ships the stub.** The stub is inert (the button renders, VoiceOver labels it, UI tests assert its presence and identifier; activating it does nothing visible). Rejected alternatives: omitting Play until Milestone 5 (breaks the card anatomy and the one-tap-from-launch layout, guaranteeing rework and a second ui-spec conformance pass) and a "coming soon" alert (a designed dead end — worse than inert during sequential development; no release ships between Milestones 3 and 5). The protocol boundary is the same pattern the audio services already use (PRD §3) and is what Milestone 5 replaces.
- **D6. Motivation strip zero-state (design gap → decision).** PRD §5.2 and the mockups assume sessions exist. Before the first-ever `RoutineSession` row, the strip is **not rendered at all** — the home opens with the routine grid. Rationale: "0-day streak · 0 min this week" on first launch is a shame state by another name, and PRD §7 forbids shame states; an empty strip row is dead chrome; hiding until there is something honest to say is the Gentler-Streak-class move. Once any session exists the strip always renders (a broken streak shows the new number — DESIGN.md §8). "Best 11" secondary line from the mockups ships only when best > current streak; otherwise the streak stat stands alone. **Amends PRD §5.2** ("A compact motivation strip … appears once the first session has been recorded") **and DESIGN.md §4** (same sentence on the Motivation strip entry); ui-spec §routines gets a note.
- **D7. Never-played routine stats line (design gap → decision).** A routine with zero sessions shows "Not played yet" in the stats footnote slot — factual, forward-looking, no guilt (DESIGN.md §8 voice). "Last done %@ · N×" appears from the first session (relative date via Foundation's relative formatting; times-completed counts only `wasCompleted` sessions, PRD §7). On day one all three starters read "Not played yet", which is the truth. **Amends PRD §5.2 / DESIGN.md §4** (routine card entry) with this line.
- **D8. Routine detail ships without Edit.** Hero total (the one hero number per screen, DESIGN.md §5) from the shared compiler; step rows + Recover-Mint rest rows rendered between steps exactly as compiled (trailing rest omitted — "a routine never ends on a rest", PRD §6.2); stats line under the hero; Play primary (D5 stub); Duplicate and Delete secondary; Delete confirms with the system destructive role and preserves sessions via `routineNameSnapshot` (PRD §4.4). Edit is builder work and arrives in Milestone 4 — shipping a disabled Edit button would be a designed dead end; ui-spec keeps Edit because it documents the finished product, and Milestone 4's conformance check covers it. Duplicate is pure data (copy routine + steps, name per §6's `routine.duplicate.name` format, `seedIdentifier` nil on the copy so the dedupe sweep never touches it, `createdAt`/`updatedAt` now) and is first-class per PRD §5.2.
- **D9. Empty state + "Restore starter routines" semantics (design gap → decision).** The home empty state (only reachable by deleting every routine) uses the `ContentUnavailableView` shape with primary **New Routine** and secondary **Restore starter routines** (ui-spec §routines). Restore is the explicit user action Milestone 2 D8 anticipated (the once-per-install flag deliberately blocks automatic re-seeding): it re-inserts, as pristine copies (`updatedAt == createdAt`, `seedIdentifier` set), **every starter whose `seedIdentifier` is absent from the store**, using the same seeding path as first launch. Inserting only missing starters keeps the action idempotent and safe outside the empty state (it also backs a future Settings row without change); the Milestone 2 dedupe sweep already guarantees convergence if sync races the restore. New Routine from here creates an empty named routine and pushes its detail (its own empty step list invites Milestone 4's builder; before Milestone 4 the CTA still produces something real and deletable rather than a dead button — same reasoning as D5). **Amends PRD §5.2** ("re-seed starters" → "restore any missing starter routines as fresh copies").
- **D10. Gallery information architecture.** Regular width: one scrolling view, category sections in fixed catalog order (Milestone 1 D9 order), section header = category symbol + name + count ("N workouts", "· N yours" appended when custom workouts exist there), adaptive 1:1 tile grid. Compact width: the same sections render as a category list whose headers navigate to full category pages (PRD §5.3 "category grid entry points on compact"; ui-spec §gallery note), keeping tiles ≥ 3-up and names unclamped at AX sizes. Search (`.searchable`, prompt "Search N workouts") spans built-ins + custom workouts by localized/display name, case- and diacritic-insensitive; results keep category grouping; empty results use the system `ContentUnavailableView.search` (verified in the docset with `.searchable`). The "Add your own" dashed tile renders at the end of every category's tile set and in the toolbar (+), both opening the custom-workout editor pre-selected to that category (toolbar defaults to Full Body per PRD §4.2).
- **D11. Workout detail.** 4:3 `WorkoutVisual` header (the reserved media region — zero reflow when media ships), name, category chip in the category hue, focus-area chips in quiet system fill (display-only, PRD §4.1), and an "Appears in N routines" line derived at display time by scanning `RoutineStep.workoutID` across routines (routine names joined with Foundation's list format; capped at three names + "and N more" via the §6 key). Custom workouts additionally show their notes paragraph and Edit/Delete in the toolbar; Delete confirms and explains the snapshot contract in one line (§6 copy). No empty "How to" section (instructions deferred, PRD §10).
- **D12. Add to Routine (existing or new) without the builder.** The primary action opens a system sheet listing existing routines (name + total + workout count) plus **New Routine**. Choosing a routine appends one step with the PRD §5.4 smart defaults (30 s work, 1 set, no set-rest, 15 s rest-after; `workoutNameSnapshot` captured now; `sortIndex` after the last step; the previous *step's* values-as-defaults rule is builder behavior and stays in Milestone 4). Confirmation is lightweight (the sheet dismisses; the routine's totals update everywhere from the shared compiler). New Routine creates a routine with the suggested default name (§6 `routine.default-name`) containing this one step and pushes its detail. Rejected alternatives: deferring the button to Milestone 4 (the gallery would be a library with no checkout — G1's "Add to routine" is a PRD §5.3 requirement and acceptance #8 depends on it) and opening a mini-editor for the new step (that *is* the builder; duplicated effort, guaranteed drift).
- **D13. Custom-workout editor.** A small system sheet (ui-spec §workout-detail second frame): Name (required in UX — Save disabled until non-empty after trimming; schema stays defaulted per CloudKit, PRD §4.2), Category single-select from the eight fixed categories (checkmark row list, default Full Body or the originating category per D10), Notes optional. Editing an existing custom workout pre-fills; renaming updates the gallery immediately but **existing steps keep their `workoutNameSnapshot`** (PRD §4.3 contract — the snapshot updates only when a step is re-added; stated in §5 edge cases so tests pin it). Save fires the `.success` haptic (DESIGN.md haptics: `routine_saved: .success` — same "creation saved" meaning). Deleting from the editor or detail confirms with the snapshot explanation. No color/icon pickers — "Users never pick colors" (DESIGN.md §2).
- **D14. Settings tab ships minimal-honest.** Content: the privacy statement and the version footer (both PRD §5.6 items with zero dependencies). Audio toggles + get-ready rows arrive with the player they configure (Milestone 5); the iCloud status line arrives with hardening (Milestone 7) — a status line without the sync verification work behind it would be decoration. PLAN.md's Milestone 3 gate ("VoiceOver pass on both tabs") already scopes this milestone's depth to Routines + Gallery. Rejected: an empty "coming soon" tab (dead end) and shipping the full §5.6 form now (its rows would configure features that don't exist — dishonest UI).
- **D15. View-model and data-flow shape.** `@Observable` main-actor view models per house standard (PRD §3); SwiftData reads via queries/fetches in the feature layer, mapped to core snapshots at the boundary Milestone 2 D1 fixed (compiled totals and stats always via `StepBackCore` — UI never re-derives math). The catalog service and `PlayerLauncher` stub flow through the environment from the shell. All duration/date/count rendering via Foundation formatters (`Duration.UnitsFormatStyle` for "24 min" / "5 min 30 s" / "30 s", relative date formatting for "2 days ago", list format for routine names) — never hand-assembled strings (PRD §3.1.3).
- **D16. Motion and polish floor.** Standard system transitions only; numeric text that changes in place (live totals on detail after add-to-routine) uses the numeric content transition; no custom springs, no celebration surfaces this milestone (completion motion is Milestone 5/6). Reduce Motion needs no special casing because nothing custom moves. This restraint is the DESIGN.md §7 baseline, recorded so nobody "improves" browsing with decoration.

## 5. Edge cases

Routines home:
- Zero sessions anywhere (day one): no motivation strip (D6); all cards read "Not played yet" (D7); sort falls back to `createdAt` desc then `id` (D4) — stable across launches and devices.
- All routines deleted: empty state with New Routine + Restore (D9). Restore with all three starters present inserts nothing (no-op, sheet/button still succeeds silently). Restore with one starter surviving inserts only the two missing.
- A routine whose every step references deleted custom workouts still renders card, detail, and totals via `workoutNameSnapshot` + the D3 fallback tile — never blank, never a crash (PRD §4.1/§4.3).
- Very long routine names: one line, truncated tail on cards; full name in detail navigation title; VoiceOver reads the full name.
- Duplicate of a duplicate: name format applies to the visible name ("Morning Core copy copy" is acceptable and honest; no numbering scheme).

Gallery / workout detail / custom workouts:
- Search with zero results → `ContentUnavailableView.search`; clearing restores the sectioned browse.
- Search query matching only custom workouts still shows their category section header.
- Category with zero custom workouts shows no "· N yours" fragment (separate key, not string surgery — §6).
- Custom workout deleted while its detail is pushed: the screen pops (row gone from gallery); referencing routines unaffected (snapshot).
- Renaming a custom workout: gallery/detail update; existing step rows keep the old snapshot name (D13) — test-pinned, not accidental.
- "Appears in 0 routines": the line is omitted entirely (no sad empty sentence).
- Add to Routine when zero routines exist: the sheet shows only New Routine.
- Custom workout name of only whitespace: Save stays disabled; no schema-level validation (CloudKit defaults, PRD §4.2).

Layout / accessibility:
- AX Dynamic Type: card stats wrap below the name (ui-spec §routine-detail a11y note); hero stat scales with its text style and remains the only large number; gallery tiles reflow to fewer columns rather than truncating names.
- Dark mode: zero layout change (DESIGN.md "token problem, not layout problem"); category soft fills derive from the token pairs at 13% opacity (D3).
- RTL: leading/trailing only; category-mix dots and chips mirror for free.
- iPhone landscape / iPad portrait: the same size-class rules; no orientation special cases.

## 6. Accessibility & localization

**VoiceOver grouping:** each routine card is one element ("Morning Core, 5 minutes 30 seconds, 5 workouts, last done 2 days ago, completed 14 times") with Play as a separate element ("Play Morning Core", button); each step row is one element ("Bridge, 30 seconds, 3 sets, 10 seconds between sets"); rest rows read "Rest, 15 seconds"; gallery tiles read name + category ("Russian Twist, Core"); the "Yours" caption is appended for custom workouts. Durations in VoiceOver use the spelled-out Foundation width, never "30 s".

**Accessibility identifiers** (UI-test contract; `<id>` = routine/workout id):
`tab.routines` `tab.gallery` `tab.settings` · `home.motivationStrip` `home.newRoutine` `home.card.<id>` `home.card.play.<id>` `home.empty.newRoutine` `home.empty.restore` · `routineDetail.hero` `routineDetail.play` `routineDetail.duplicate` `routineDetail.delete` `routineDetail.step.<index>` `routineDetail.rest.<index>` · `gallery.search` `gallery.section.<categoryID>` `gallery.tile.<workoutID>` `gallery.addCustom` · `workoutDetail.visual` `workoutDetail.addToRoutine` `workoutDetail.edit` `workoutDetail.delete` · `addToRoutine.routine.<id>` `addToRoutine.newRoutine` · `customEditor.name` `customEditor.category.<categoryID>` `customEditor.notes` `customEditor.save` `customEditor.cancel` · `settings.privacy` `settings.version`

**New string-catalog keys** (English values; plural variants where marked; durations/dates/lists always via Foundation formatters, never keys):

| Key | English value | Notes |
|---|---|---|
| `tab.routines` | Routines | tab + home large title |
| `tab.gallery` | Gallery | tab + large title |
| `tab.settings` | Settings | tab + large title |
| `home.streak` | %lld-day streak | plural (one/other) |
| `home.streak.best` | Best %lld | only when best > current (D6) |
| `home.week.minutes` | %lld min this week | |
| `home.week.sessions` | %lld sessions | plural |
| `home.new-routine` | New Routine | toolbar + empty state |
| `home.empty.title` | No routines yet | |
| `home.empty.message` | Pick workouts from the gallery and press play — that's the whole app. | |
| `home.empty.restore` | Restore starter routines | |
| `routine.workout-count` | %lld workouts | plural |
| `routine.stats.last-done` | Last done %1$@ · %2$lld× | %1$@ = relative date |
| `routine.stats.never` | Not played yet | D7 |
| `routine.play` | Play | |
| `routine.duplicate` | Duplicate | |
| `routine.duplicate.name` | %@ copy | |
| `routine.default-name` | Routine %lld | next free number (D12) |
| `routine.delete` | Delete Routine | menu/action |
| `routine.delete.confirm.title` | Delete “%@”? | |
| `routine.delete.confirm.message` | Its workout history stays in your stats. | PRD §4.4 |
| `routine.rest` | Rest · %@ | %@ = formatted duration |
| `step.summary.sets` | %1$@ × %2$lld | e.g. “30 s × 3” |
| `step.summary.set-rest` | %@ between sets | |
| `step.summary.reps` | ~%lld reps | guidance only (PRD §6.1) |
| `gallery.search.prompt` | Search %lld workouts | plural |
| `gallery.category.count` | %lld workouts | plural |
| `gallery.category.yours` | %lld yours | plural; appended with “·” |
| `gallery.add-your-own` | Add your own | |
| `gallery.yours` | Yours | tile caption |
| `workout.appears-in` | Appears in %lld routines | plural; omitted at 0 |
| `workout.appears-in.more` | and %lld more | plural; after 3 names |
| `workout.add-to-routine` | Add to Routine | |
| `workout.edit` | Edit | custom only |
| `workout.delete` | Delete Workout | custom only |
| `workout.delete.confirm.title` | Delete “%@”? | |
| `workout.delete.confirm.message` | Routines that use it keep its name. | PRD §4.2 |
| `addto.title` | Add to Routine | sheet title |
| `addto.new-routine` | New Routine | |
| `custom.new.title` | New Workout | |
| `custom.edit.title` | Edit Workout | |
| `custom.name` | Name | |
| `custom.category` | Category | |
| `custom.notes` | Notes | |
| `custom.notes.placeholder` | Optional | |
| `common.save` | Save | |
| `common.cancel` | Cancel | |
| `settings.privacy` | No accounts. Everything stays in your private iCloud. | PRD §5.6 verbatim |
| `settings.version` | StepBack %1$@ (%2$@) | version, build |
| `ax.play-routine` | Play %@ | VoiceOver Play label |
| `ax.rest` | Rest, %@ | VoiceOver rest row |

Step-summary fragments join with “·” as a symbol-separated list (tabular numerals), not sentence concatenation — same grammar as ui-spec §builder documents. Category, workout, focus-area, and starter keys already exist (Milestone 2 §6); no key is renamed.

## 7. Test impact

- **New app-target unit suites** (`StepBackTests`, in-memory stores per Milestone 2 D10):
  - *Home ordering:* the D4 sort across played/never-played/tied routines, deterministic across enumeration order.
  - *Zero-states:* strip-visibility rule (no sessions → hidden; one partial session → shown), "Not played yet" vs. "Last done" line selection, best-streak line suppression (D6/D7).
  - *Restore:* the D9 matrix (all present / some missing / none missing), pristine invariants on restored copies, coexistence with the Milestone 2 dedupe sweep.
  - *Duplicate:* copies steps and values, nil `seedIdentifier`, name format.
  - *Add to Routine:* appends with exact smart defaults + snapshot + `sortIndex`; new-routine path creates one-step routine with the default name; totals via the shared compiler.
  - *Custom workouts:* save validation (whitespace), rename-keeps-snapshots, delete-keeps-steps, appears-in derivation (0 / ≤3 / >3 routines).
  - *Search:* case/diacritic insensitivity across catalog + custom names.
- **UI tests** (`StepBackUITests`, iPhone + iPad lanes): launch → three tabs present; home shows three starter cards with identifiers; card → detail shows hero + step/rest rows for a starter; gallery browse → tile → detail → Add to Routine → existing routine's total updates on home; create custom workout → appears in gallery with "Yours" → delete it → referencing routine still renders; empty-state flow (delete all → restore brings starters back). Play buttons asserted present-and-labeled only (D5).
- **Manual gate evidence** (journaled): ui-spec §routines/§gallery side-by-side conformance via the `design-spec` server; VoiceOver pass on both tabs; pseudolocalization + AX-size render check; dark-mode sweep.
- Lanes: `make test-core` (untouched, must stay green), `make test-app`, `make test-ipad`, `make test-mac`, `make build-sim`, `make build-sim-ipad`, `make build-mac`.

## 8. Acceptance criteria

1. All §7 lanes green; no test touches CloudKit or the network.
2. Fresh launch lands on the Routines home showing exactly the three starters as cards — no motivation strip, every card "Not played yet" (D6/D7) — matching ui-spec §routines anatomy in light and dark, compact and regular.
3. Routine detail for a starter shows the compiled hero total (byte-equal to the card's figure), the step/rest sequence exactly as Milestone 2 D7 defines it, and working Duplicate/Delete; no Edit control ships (D8).
4. Gallery renders all 92 workouts in the eight fixed categories with monogram tiles through `WorkoutVisual` only; search finds "bridge" and a just-created custom workout; empty search shows the system unavailable view.
5. PRD acceptance #8's browsing half works end-to-end: add "Wall Sit" (Legs & Glutes) → appears in gallery with "Yours" → Add to Routine appends a 30 s/1 set/15 s-rest step → delete Wall Sit → the routine still displays it by name.
6. Deleting every routine reaches the designed empty state; Restore starter routines brings back exactly the missing starters as pristine copies.
7. Every §6 key exists in `Localizable.xcstrings` with plural variants where marked; the app renders correctly under pseudolocalization; no user-facing string literal exists in view code.
8. Every §6 accessibility identifier is present; VoiceOver reads routine cards, step rows, rest rows, and gallery tiles as the specified grouped elements on both tabs.
9. The PRD/DESIGN/ui-spec amendments named in the header (D6/D7/D9) are applied in the implementation commit.
10. One coherent commit on `codex/milestone-3-browsing-ui` (plus status flips per the workflow); tree clean afterward.
