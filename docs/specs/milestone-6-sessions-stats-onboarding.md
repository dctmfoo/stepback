# Spec: Milestone 6 — Sessions, stats & onboarding

**Status:** Implemented
**Owner screens:** `StepBack/Features/Player/` (session recording wiring on `PlayerStageRoot`, completion stat pair on `PlayerCompletionView`), `StepBack/Features/Onboarding/` (new — welcome screen), `StepBack/Features/Shell/TabAppShellView.swift` + `StepBack/Features/Shell/MacAppShellView.swift` (welcome presentation), `StepBack/Persistence/` (new session recorder + in-flight marker store, abandoned-session reconciliation in `StepBackBootstrap.swift`), `StepBack/Features/Settings/SettingsView.swift` (iCloud section), `StepBack/Features/Shared/L10n.swift` + `StepBack/Resources/Localizable.xcstrings` (§6 table), `StepBackTests/` + `StepBackUITests/` + `StepBackMacUITests/`, `PLAN.md` (Milestone 6 status line)
**Docs this spec amends:** `design/ui-spec.html` — two implementation-note corrections, no mockup/layout changes: (a) §onboarding "Build it with" says Get Started *triggers* seeding; seeding is and remains a bootstrap-launch responsibility (D8), Get Started only records welcome-seen; (b) §settings sync-line states drop "Syncing…" and the "· Just now" timestamp — the line is account-status-derived only (D11). `DESIGN.md` needs no amendment: every surface this milestone touches (motivation strip, routine-card footnote, completion stat pair, empty states) is already canonical there.

**Branch:** `codex/milestone-6-sessions-stats-onboarding`. **Sequencing:** implementation starts only after the Milestone 5 gate passes (its physical-device verification is currently the open item) and `codex/milestone-5-stage-player` merges — this spec builds directly on the M5 player and its reserved completion-stats slot. Implementer flips this spec to Status: Implemented and PLAN.md Milestone 6 to `in progress` in the opening commit / `gate passed YYYY-MM-DD (<short-hash>)` in the closing one.

**API grounding (offline Apple docset, read 2026-07-10):** availability claims in the D-decisions cite docset paths inline at first use.

---

## 1. Problem

Every stats surface in the app is built, tested, and permanently empty. `RoutineSession` exists in the schema (`StepBack/Persistence/Models.swift`), `DerivedStats` in StepBackCore is fully tested (streak dedup, time zones, week boundaries, DST), the motivation strip, routine-card footnotes, routine-detail stats line, and home most-recently-played ordering all read real session data via `@Query` — but **nothing anywhere writes a `RoutineSession` row**. The M5 player computes `wasCompleted` / `completedStepCount` / `totalStepCount` / `activeSeconds` in its `RunnerSessionSummary` and then discards them at dismissal. There is also no crash/relaunch recovery (PRD §8 reliability: "the in-flight session is recorded as abandoned on next launch"), no welcome screen (PRD §5.1, acceptance #1), and no Settings iCloud status line (PRD §5.6).

PLAN.md Milestone 6: session recording (complete/partial/abandoned-on-relaunch), per-routine stats lines, motivation strip live, completion summary numbers, welcome screen + seeding polish. Gate: PRD acceptance #1/#6/#7; streak double-count and time-zone tests green.

## 2. Goals

- G1. **One honest `RoutineSession` row per play-through** (PRD §4.4): written on completion, on confirmed early end, on Mac stage-window close mid-run, and — via next-launch reconciliation — for runs killed by crash or force-quit.
- G2. **Abandoned-on-relaunch recovery** (PRD §6.3/§8): a device-local in-flight marker checkpointed during play; at launch an orphaned marker becomes an honest partial session row, silently.
- G3. **Stats surfaces go live**: motivation strip appears after the first session, card footnotes flip from "Not played yet" to "Last done … · N×", home reorders by most recently played, all with zero new read-side UI — the M3 components light up.
- G4. **Completion summary numbers complete** (PRD §5.5, acceptance #6): the M5-reserved stat slot fills with updated day streak and times-completed, without reflow.
- G5. **Welcome screen** (PRD §5.1, acceptance #1): one screen — icon, one-line promise, Compose/Play/Follow rows, privacy footnote, Get Started — shown once per install, local state only.
- G6. **Settings iCloud status line** (PRD §5.6): a read-only sync row derived from CloudKit account status, with the designed degraded state.
- G7. **Gate**: PRD acceptance #1, #6, #7; streak double-count and time-zone tests green (already green in core — re-pinned at app level); all test lanes green.

## 3. Non-goals

- **No session-history browsing UI.** PRD §5 defines no history screen; G7 says "glanceable, never a dashboard". Rows exist for stats only.
- **No charts, goals, targets, awards, or shame states** (PRD §2, §7). A recovered abandoned session surfaces nowhere except the honest numbers; a broken streak just shows the new number.
- **No cross-device sync verification** — recording rows sync via the existing CloudKit mirroring for free; verifying acceptance #10 on two devices is Milestone 7. The Settings sync line ships here (D8) but its two-device behavior is verified in M7.
- **No stored streak counter or any denormalized stat** (PRD §7 — computed from local calendar days at read time; `DerivedStats` already does this).
- **No notification/reminder around abandoned sessions**, no "resume where you left off" across process death — PRD §6.3 requires *recording*, not restoration; a relaunched app starts fresh.
- **No synced settings or synced onboarding state** — welcome-seen is `@AppStorage`, never CloudKit (PRD §5.1); consistent with M5's device-local player settings.
- **No permission pre-prompts, feature tours, or multi-page onboarding** (ui-spec §onboarding: "the three rows *are* the app's entire mental model").
- Checked against PRD §2: everything here is §4.4/§4.5/§5.1/§5.6/§7 scope; nothing adds programs, dashboards, or social surface.

## 4. Design decisions

**Session recording**

- **D1. A main-actor session recorder service, behind a protocol with a fake, owns the write side; the player model stays persistence-free.** `PlayerSessionModel` already exposes everything a row needs (`RunnerSessionSummary`: `wasCompleted`, `completedStepCount`, `totalStepCount`, `activeSeconds` — active time already excludes paused time and get-ready by the core runner's contract). The recorder is told when a run starts, checkpoints, and ends; it assembles the `RoutineSession` from the summary plus the routine's identity (`id`, name snapshot) and its own injected date provider (`startedAt` captured at run start, `endedAt` at record time — deterministic in tests, house style). `PlayerStageRoot` drives it from the hooks it already owns (start/restart, phase changes, scene-phase changes, end confirmation). Rejected: writing from `PlayerSessionModel` (couples the deterministic run model to SwiftData; the model is shared Mac/iOS and fake-clock-tested); writing from the completion *views* (partial and window-close paths would duplicate or miss writes).
- **D2. Exactly one SwiftData write per run, at run end — never mid-run.** The row is inserted on: final-segment completion (`wasCompleted` true), confirmed early end (partial), and Mac stage-window close mid-run (partial — upgrading M5's documented "position discarded" behavior). Rejected: inserting an open row (`endedAt` nil) at run start and closing it later. Rationale: `RoutineSession` is CloudKit-mirrored, so an open row would sync mid-workout to other devices as a phantom in-flight session — and worse, any *other* device's launch-time reconciliation (G2) would see it as orphaned and falsely close it. Recovery state must be device-local (D3); the synced store only ever contains finished, honest rows.
- **D3. The in-flight marker is a device-local codable payload behind a store protocol (`UserDefaults`-backed in production, in-memory fake in tests).** Payload: routine id, routine name snapshot, `startedAt`, `totalStepCount`, plus the latest checkpoint (`activeSeconds`, `completedStepCount`, `updatedAt`). Written at run start; refreshed at every segment boundary, on pause, and on scene-phase resign-active; cleared whenever a run-end row is recorded (D2). `UserDefaults` updates memory immediately and writes to disk asynchronously (docset `/documentation/foundation/userdefaults` Discussion) — so a hard crash can lose at most the tail after the last flushed checkpoint. That failure mode only ever *undercounts*, which is the honest direction (PRD §7). Rejected: an atomically-written file store (more moving parts for the same undercount guarantee); checkpointing every second (needless churn — segment boundaries bound the loss to one segment).
- **D4. Launch-time reconciliation turns an orphaned marker into an abandoned partial row, silently.** During bootstrap (alongside the existing seeding/dedupe pass in `StepBackBootstrap`), a present marker means the previous process died mid-run: insert a `RoutineSession` with `wasCompleted` false, counts and `activeSeconds` from the last checkpoint, `endedAt` = the marker's `updatedAt` (the last moment the session was provably alive — never a guessed death time), routine relationship resolved by id and left nil if the routine is gone (sessions of a deleted routine survive via the name snapshot, PRD §4.4). Then clear the marker. No banner, no dialog, no mention anywhere — the numbers simply stay honest (PRD §7 no-shame rule; ui-spec §settings note "never an error dialog" is the house pattern for silent degraded handling).
- **D5. Zero-progress runs record nothing.** If a run ends (any path, including reconciliation) with zero `activeSeconds` and zero completed steps — e.g. End during the get-ready pre-roll — no row is written, and the early-end path skips the partial acknowledgment and dismisses the stage directly. Rationale: `DerivedStats.weeklySessionCount` counts partials, so a zero row would inflate "N sessions" with a session in which nothing happened; and the partial acknowledgment's copy ("You did %@ — saved to history") must never describe a save that didn't happen or an effort that wasn't made. This narrows M5's behavior (which showed the acknowledgment unconditionally) — recorded here as the deliberate change, cited against PRD §7 honesty.
- **D6. Go Again records-then-restarts.** The completed run's row was already written at the completion transition (D2); Go Again simply begins a new recorder run (fresh `startedAt`, fresh marker) alongside the model restart `PlayerStageRoot.restart()` already performs. Two play-throughs, two rows — PRD §4.4's "one row per play-through" taken literally.

**Completion summary numbers**

- **D7. The completion stat pair is computed by `DerivedStats` from all session snapshots (including the row just recorded), with injected calendar and now.** `PlayerCompletionView` fills the slot M5 reserved (its D19: rendered "only when session data exists", laid out reflow-free): updated current streak and the routine's times-completed, per the ui-spec completion mockup ("5 days / Streak · 15× / Completed", tabular numerals). No new math: `DerivedStats.currentStreak` and `DerivedStats.perRoutine(...).timesCompleted` exist and are core-tested, satisfying "the streak counts days with ≥ 1 completed session, computed from local calendar days at read time" (PRD §7). The partial acknowledgment stays a single line — no stat pair on partials (DESIGN.md §4 completion component: partials get "a smaller honest acknowledgment"; showing an unchanged streak there would read as reproach).

**Welcome & seeding polish**

- **D8. Seeding remains a bootstrap-launch responsibility; Get Started only records welcome-seen.** The shipped M2 seeder already implements PRD §5.1 exactly (flag-gated, empty-store-only so CloudKit content wins, `saveOrRollback`, dedupe sweep on foreground) and its gate passed. Seeding at launch — before the cover is dismissed — means the Routines home is fully populated the instant Get Started fades, and a first launch killed on the welcome screen still seeds. ui-spec §onboarding's build-note ("Get Started dismisses and triggers idempotent seeding") is amended to match (header note above); the *user-visible* contract in that section — one screen, three starters behind it, idempotent across devices — is unchanged.
- **D9. Welcome presents as `fullScreenCover` on iOS-family and as a `sheet` on macOS, driven by a local `@AppStorage` welcome-seen flag; any dismissal counts as seen.** `fullScreenCover` has no macOS availability (docset `/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)` — Platforms: iOS/iPadOS/Mac Catalyst/tvOS/visionOS/watchOS); the Mac shows the standard window-modal sheet (docset `/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)`), matching the M5 precedent of per-platform presentation behind one shared content view. `@AppStorage` is cross-platform (docset `/documentation/swiftui/appstorage` — iOS 14+/macOS 11+) and device-local, satisfying PRD §5.1's "onboarding-seen state is local, never in CloudKit". The flag flips in the presentation's dismiss path, not only in the button action: the welcome is informational, not a consent gate — if the Mac sheet is escaped, showing it again next launch would be nagging. Layout per ui-spec §onboarding: app-icon tile, "StepBack" heading, the one-line promise, three icon rows (PulseAzureSoft tiles, PulseAzure glyphs — quoted token rule from that section), privacy footnote with lock glyph, one prominent Get Started (the app's single accent; no red, no gradients). All Dynamic Type, base-grid spacing, `ContentUnavailableView`-adjacent simplicity — no new design patterns, so no DESIGN.md amendment.
- **D10. UI-test launches suppress the welcome by default; an env opt-in shows it.** The existing bootstrap test seam (`-StepBackUITesting`, `StepBackUIEmptyStore`) grows a sibling: welcome-seen defaults to true under UI testing so the existing 11-flow suites keep passing untouched, and `StepBackUIShowWelcome=1` opts a lane in for the acceptance-#1 flow test. Mirrors the established pattern exactly.

**Settings iCloud line**

- **D11. The sync row is a read-only line derived from `CKContainer.accountStatus`, re-checked on `CKAccountChanged`, behind a status-service protocol with a fake.** `accountStatus(completionHandler:)` is current on all four platforms (docset `/documentation/cloudkit/ckcontainer/accountstatus(completionhandler:)`), and its Discussion prescribes exactly this pattern: check before relying on the private database, observe `CKAccountChanged` (docset `/documentation/foundation/nsnotification/name-swift.struct/ckaccountchanged` — iOS 9+/macOS 10.11+) and re-check. States: available → "Up to date"; first check in flight → "Checking…"; every other status (`noAccount`, `restricted`, `couldNotDetermine`, `temporarilyUnavailable`) → the designed degraded line "iCloud unavailable — changes stay on this device" (ui-spec §settings: a read-only line, "never an error dialog"). The mocked "Syncing… / · Just now" refinements are dropped from ui-spec (header note): SwiftData drives CloudKit through an internal `NSPersistentCloudKitContainer` (docset `/documentation/swiftdata/syncing-model-data-across-devices`) that it does not expose, so there is no public, supportable per-sync-event surface to power a truthful timestamp — an account-status line is what can be shown honestly. Right-sizing: PLAN.md's M6 line doesn't name this row, but the M5 spec explicitly deferred it to "M6/M7 sync verification work" and M7 is a verification/hardening milestone that builds no features — so the row lands here, and M7 verifies it. In UI-test/in-memory runs the bootstrap wires the fake (fixed "Up to date") so no test lane touches CloudKit.

**Read-side surfaces**

- **D12. No new read-side UI.** The motivation strip (`MotivationStrip.swift`, gated by `RoutineLibrary.shouldShowMotivation` = first session exists — ui-spec: "hidden until the first-ever session row exists"), card footnote (`RoutineCard.swift` — "Not played yet" → "Last done … · N×"), routine-detail stats line (`RoutineDetailView.swift`), and most-recently-played ordering (`RoutineLibrary.sorted`) are all implemented and already read live `@Query` data. This milestone's read-side work is *verification*, not construction: app-level tests pin that a recorded session flips each surface (§7). Any visual defect found in them is an M3 bug fixed on this branch under the normal defect rule, not new design.

## 5. Edge cases

Recording:
- End early two seconds into the first work segment: partial row with `activeSeconds` 2, acknowledgment shown — the smallest honest session.
- End during pre-roll (zero progress): no row, no acknowledgment, stage dismisses (D5).
- Complete → Go Again → end the second run early: two rows — one completed, one partial (D6).
- Backgrounded-then-killed while paused: the resign-active checkpoint captured the position; reconciliation records the partial with paused time excluded (`activeSeconds` is active-only by the runner's contract). PRD §6.3's "killed while paused" case exactly.
- Crash mid-segment: loss bounded by the last segment-boundary/pause checkpoint; recovered row undercounts, never overcounts (D3).
- Relaunch with no marker (normal previous exit): reconciliation is a no-op.
- Marker payload undecodable (app-version change): clear silently, record nothing — never crash on recovery.
- Routine deleted (other device, synced) between crash and relaunch: recovered row keeps `routineNameSnapshot`, relationship nil (PRD §4.4).
- Mac stage window closed mid-run: partial row recorded at teardown, no acknowledgment UI (the window is gone) — zero-progress rule still applies.
- Force-quit on the completion view: the completed row was written at the completion transition, marker already cleared — no double row on relaunch.

Stats surfaces:
- Second completed session the same day: times-completed increments, streak does not (PRD acceptance #6; core-tested, re-pinned at app level).
- Partial session only: motivation strip appears (first session row exists), weekly minutes include it, times-completed stays 0, streak stays 0 (PRD acceptance #7, §7).
- Sessions synced in from another device while home is visible: `@Query` refreshes; strip and footnotes update live.
- Time-zone change: streak/week recompute at read time in the current calendar (PRD §7; core-tested).

Welcome & settings:
- Second device, same iCloud, first app launch: welcome shows (flag is local); store already has synced routines so seeding correctly declines (`storeNotEmpty`) — welcome and seeding are independent by design.
- App killed on the welcome screen: seeding already ran (D7); welcome shows again next launch (flag never flipped) — correct, it was never seen to completion.
- Welcome over an empty-store UI-test launch: suppressed unless `StepBackUIShowWelcome=1` (D10).
- iCloud signed out while Settings is visible: `CKAccountChanged` fires, the row flips to the degraded line without dialogs; app behavior is otherwise unchanged (local store keeps working).
- No network: account status is still resolvable locally; whatever CloudKit reports maps through D11's three states — the row never spins forever ("Checking…" resolves on the first callback).

## 6. Accessibility & localization

**New string-catalog keys** (English values; durations/dates/counts via `DisplayFormatters` — never hand-assembled; existing keys `routine.stats.never`, `routine.stats.last-done`, `home.streak`, `home.week.minutes`, `player.partial.message`, `settings.privacy` are reused unchanged):

| Key | English value | Notes |
|---|---|---|
| `welcome.title` | StepBack | heading over the icon tile |
| `welcome.tagline` | Build your routine once. Then press play, step back, and follow. | the one-line promise (PRD §5.1) |
| `welcome.compose` | Compose | row title |
| `welcome.compose.detail` | Pick workouts from the gallery into your own routine — times, sets, rests. | |
| `welcome.play` | Play | row title |
| `welcome.play.detail` | One tap starts the whole routine. The screen stays awake. | |
| `welcome.follow` | Follow | row title |
| `welcome.follow.detail` | Voice and tones guide every move — no need to touch the screen again. | |
| `welcome.privacy` | No accounts. Your routines sync only to your private iCloud. | distinct from `settings.privacy` copy per ui-spec |
| `welcome.get-started` | Get Started | the single CTA |
| `player.complete.streak` | %lld day / %lld days | plural variants; stat-pair value |
| `player.complete.streak.label` | Streak | caption under the value |
| `player.complete.times` | %lld× | stat-pair value; multiplication sign, not letter x |
| `player.complete.times.label` | Completed | caption under the value |
| `settings.section.icloud` | iCloud | section header |
| `settings.sync` | Sync | row title |
| `settings.sync.up-to-date` | Up to date | row subtitle, account available |
| `settings.sync.checking` | Checking… | row subtitle, first check in flight |
| `settings.sync.unavailable` | iCloud unavailable — changes stay on this device | designed degraded state |

**Accessibility identifiers:** `welcome.screen`, `welcome.tagline`, `welcome.compose`, `welcome.play`, `welcome.follow`, `welcome.privacy`, `welcome.getStarted`; `player.complete.streak`, `player.complete.times`; `settings.sync`. (Existing ids `home.motivationStrip`, `home.card.<id>`, `player.complete.minutes`, `player.partial.message`, `home.empty.restore` are asserted, not added.)

**VoiceOver grouping:** each welcome row (icon + title + detail) is one combined element; the Get Started button is the natural final focus. Each completion stat pair (value + label) combines into one element ("Streak, 5 days" / "Completed, 15 times" — the `×` must read as "times", so the combined label is built from the localized pieces, not the visual glyph). The Settings sync row combines title + status into one read-only element. The recovered-abandoned path has no UI, so no announcements.

**Dynamic Type:** everything in this milestone is standard Dynamic Type — no new exceptions. The welcome layout must survive AX sizes by scrolling (rows stack; the CTA stays reachable); the completion stat pair inherits the M5 stage-stacking behavior and, per that spec, yields to the hero minutes before truncating.

## 7. Test impact

- **StepBackCore:** expected no changes — `DerivedStats` already covers streak same-day dedup, missed-day reset, time zones, week boundaries, DST, and partial-vs-completed aggregation. If recorder wiring reveals a gap (e.g. a needed field on `SessionSnapshot`), it is implemented and tested in core, never patched in the app layer.
- **App unit tests (`StepBackTests`):** the recorder against an in-memory container, a fake marker store, and a fixed date provider — completed run writes one `wasCompleted` row with summary-matching counts; early end writes an honest partial; zero-progress end writes nothing (D5); Go Again yields two rows (D6); checkpoints refresh the marker at segment boundaries/pause/resign-active; normal record clears the marker. Reconciliation — orphaned marker inserts the abandoned row (`endedAt` = marker `updatedAt`) and clears; zero-progress marker just clears; no marker is a no-op; missing routine leaves the relationship nil; undecodable payload clears without throwing. Integration: a recorded row flips `shouldShowMotivation`, card stats line, and home ordering; same-day double completion leaves streak unchanged while times-completed increments (acceptance #6 at app level). Welcome flag: default false, flips on dismiss, suppressed under UI-test defaults (D10). Sync status service: each account status maps to its D11 line; `CKAccountChanged` triggers a re-check (fake-driven).
- **UI tests (`StepBackUITests`):** onboarding lane (`StepBackUIShowWelcome=1`) — welcome elements present, Get Started dismisses, home shows the three starters, Play reaches the pre-roll within two taps of home (acceptance #1). Session lane — skip through a short routine to completion: stat pair identifiers present with values, Done dismisses, home now shows the motivation strip and the card's updated footnote; relaunch-free partial lane — end a second run early, partial acknowledgment appears, times-completed on the card did not increment. Settings lane — sync row exists with a deterministic (fake-fed) status line.
- **Mac (`StepBackMacUITests`):** welcome sheet appears under the opt-in env and Get Started dismisses it (smoke); the recorder paths are shared code proven in the iOS lanes.
- Abandoned-on-relaunch across a real process kill, and the sync line against a real iCloud account, are device verifications recorded in the closing session journal — simulator tests cover the logic through the marker-store and status-service fakes.

## 8. Acceptance criteria

1. First launch (fresh install): welcome screen shows exactly the §6 content; Get Started lands on a Routines home already showing the three starters; Play on any starter reaches the pre-roll — two taps total from home (PRD acceptance #1); the welcome never appears again on subsequent launches.
2. Completing a routine writes exactly one `RoutineSession` with `wasCompleted` true and counts/active-seconds matching the run summary; the completion view shows the updated streak and times-completed in the reserved slot without reflow, alongside the existing hero minutes.
3. The routine's card immediately shows "Today" in its footnote and the incremented times-completed; the motivation strip appears above the list; home orders that routine first. Completing a second session the same day increments times-completed but not the streak (PRD acceptance #6).
4. Ending a routine partway (with any progress) writes an honest partial row: times-completed unchanged, weekly minutes include the partial active time, acknowledgment shown (PRD acceptance #7). Ending with zero progress writes nothing and shows no acknowledgment.
5. Force-quitting mid-run (including while paused in the background) yields, on next launch, one abandoned partial row whose counts never exceed the last checkpoint — verified on device with a real process kill; no recovery UI appears.
6. Go Again after a completion produces two rows across the two runs; closing the Mac stage window mid-run records a partial.
7. The Settings iCloud section shows the read-only sync row with the three D11 states; signed-out iCloud shows the degraded line with no dialog and the app remains fully usable.
8. All new strings resolve from `Localizable.xcstrings` and render under pseudolocalization; plural variants correct for streak days; all §6 identifiers exist; VoiceOver reads the welcome rows, completion stat pairs, and sync row as grouped elements per §6.
9. No stored aggregate anywhere: deleting all session rows returns every surface to its pre-first-session state (strip hidden, "Not played yet", creation-order home) — demonstrating stats are derived at read time (PRD §7).
10. `make test-core`, `make test-app`, `make test-ipad`, `make test-mac` green; `make gen` idempotent; ui-spec amendments (header note) landed in the same implementation commit; PLAN.md Milestone 6 gate closed citing the green commit.
