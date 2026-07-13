# Spec: Milestone 5 — The stage (live player)

**Status:** Implemented
**Owner screens:** `StepBack/Features/Player/` (new — stage container, work/rest/pre-roll segment layouts, stage control bar, completion view, player session model, audio services, wake service), `StepBack/Features/Shared/PlayerLauncher.swift` (real launcher replaces `NoopPlayerLauncher`), `StepBack/Features/Settings/SettingsView.swift` (gains Audio + Player sections), `StepBack/App/` (Mac stage `Window` scene declaration), `StepBack/Resources/Localizable.xcstrings` (§6 table), `StepBackCore` (only if cue-scheduling gaps surface — see §7), `StepBackTests/` + `StepBackUITests/` + `StepBackMacUITests/`, `PLAN.md` (Milestone 5 status line)
**Docs this spec amends:** none — the stage is fully canonical in DESIGN.md (`stage` tokens, `stage_numerals`, `across_the_room`, `glass_budget`, `haptics`, `motion`) and ui-spec.html §player/§settings; every decision below cites those rules. This is one spec, not two: the stage UI, the audio services, and the lifecycle rules are not independently gateable (a silent stage and a stageless audio engine both fail PRD acceptance #3), so splitting would manufacture a fake seam.

**Branch:** `codex/milestone-5-stage-player`. **Sequencing:** starts after the Milestone 4 merge (`ad2457b`); `docs/specs/fix-m0-m4-audit.md` lands on `main` before this implementation begins. Implementer flips this spec to Status: Implemented and PLAN.md Milestone 5 to `in progress` in the opening commit / `gate passed YYYY-MM-DD (<short-hash>)` in the closing one.

**API grounding (offline Apple docset, read 2026-07-10):** every availability claim in D-decisions below was verified against the Dash Apple API Reference; docset paths are cited inline at first use.

---

## 1. Problem

Milestones 0–4 built everything around the product's heart except the heart: routines exist, compile deterministically, and the tested `TimelineRunnerDriver` can already drive segments and schedule cues against fake sinks — but Play still routes into `NoopPlayerLauncher`. PLAN.md Milestone 5 requires the full-screen stage (pre-roll, work/rest layouts, stage tokens and numerals, progress, controls, completion and partial-completion views), idle-timer management, lifecycle pause/resume per PRD §6.3, Mac keyboard controls and window scene, and real speech + tone services behind the Milestone-1 protocols with polite audio-session coexistence. Gate: PRD acceptance #3/#4/#5, the DESIGN.md across-the-room verification, and a Reduce Motion pass.

## 2. Goals

- G1. **The stage**: full-screen, appearance-invariant dark player per ui-spec §player — pre-roll, work segment (countdown-led), rest/set-rest segments (next-up-led, Recover Mint), progress foot, glass control bar — landscape-iPad-first, adapting to portrait and compact.
- G2. **Hands-free end-to-end**: automatic advancement through the compiled timeline; voice announcements and 3-2-1 beeps + work-start tone exactly where the Milestone-1 runner schedules them; the screen never sleeps mid-routine.
- G3. **Real audio services** behind the existing core protocols: system speech synthesis and generated tones, coexisting politely with the user's own music (duck, never stop).
- G4. **Lifecycle honesty** (PRD §6.3): resign-active auto-pauses preserving position; audio interruptions pause; explicit resume re-enters with a fresh 3-2-1; end-early confirms and shows the partial acknowledgment.
- G5. **Completion view**: calm celebratory summary (hero active minutes counting up once, routine name, workouts completed) with Done and Go Again; partial sessions get the smaller honest acknowledgment.
- G6. **Settings grows its player controls**: voice toggle, tones toggle (both default on), get-ready duration (default 5 s, 0–30 s in 5 s steps) — the three PRD §5.6 player rows.
- G7. **Mac is a real stage**: separate resizable window scene with space/arrows/escape keyboard controls (PRD acceptance #12 groundwork).
- G8. **Gate**: PRD acceptance #3, #4, #5; DESIGN.md `across_the_room.verification` (3 m, lit + dim, both segment types, iPad landscape + portrait and iPhone); Reduce Motion pass; all test lanes green.

## 3. Non-goals

- **No session recording** — `RoutineSession` rows, per-routine stats updates, the motivation strip going live, and the completion view's streak/times-completed line are Milestone 6 (PLAN.md). The completion layout reserves that stats line's slot (media-readiness discipline applied to data: the screen must not reflow when M6 fills it) but renders it only when sessions exist — i.e., not in M5.
- **No onboarding changes** — Milestone 6.
- **No iCloud status line in Settings** — it needs no player and belongs with M6/M7 sync verification work; ui-spec §settings shows it, and it stays specced there for that milestone.
- **No Live Activities, Dynamic Island, widgets, Watch, HealthKit, music playback** (PRD §2). The player *coexists* with the user's music; it never plays any.
- **No per-routine audio or get-ready overrides** — Settings owns these globally (PRD §5.6).
- **No rep-driven timing** — `repGuidance` renders and is spoken once, never gates advancement (PRD §6.1).
- Checked against PRD §2: everything here is §5.5/§6 scope; nothing adds programs, coaching, or dashboards.

## 4. Design decisions

**Presentation & shell**

- **D1. iOS/iPadOS present the stage as `fullScreenCover`; the Mac stage is its own `Window` scene.** `fullScreenCover` has no macOS availability (docset `/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)` — iOS/iPadOS/Catalyst/tvOS/visionOS/watchOS only); `Window` is macOS 13+ (docset `/documentation/swiftui/window` — macOS 13, visionOS 26, **not iOS**), so the scene declaration is compile-time conditional for the Mac target and the launcher opens it via the `openWindow(id:)` environment action (docset `/documentation/swiftui/environmentvalues/openwindow`). Style: `.hiddenTitleBar` with `windowResizability(.contentMinSize)` and a sensible minimum frame — no "fullscreen" window style exists (docset `/documentation/swiftui/windowstyle`); the user zooms/full-screens natively, and the stage composition scales because the countdown is viewport-scaled by definition (DESIGN.md `stage_numerals`). Rejected: a Mac sheet (ui-spec §platforms explicitly demands "a proper resizable stage, not a stretched sheet").
- **D2. One real `PlayerLauncher` per platform behind the existing `PlayerLaunching` protocol.** The iOS implementation sets presented-routine state driving the cover; the Mac implementation calls `openWindow` with the routine's identity. Play → pre-roll must stay under 300 ms (PRD §8): compilation is a pure function over an already-loaded routine — no async work on the play path.
- **D3. Rotation is free; layout is size-class- and geometry-driven.** Landscape/regular: countdown column beside the 4:3 `WorkoutVisual` region; portrait/compact: countdown stacked above it (ui-spec §player compact frame; DESIGN.md §10). No orientation locks, no device-type branches (PRD §3).

**Engine & state**

- **D4. An `@Observable` main-actor `PlayerSessionModel` owns one run: compiled timeline + the core `TimelineRunnerDriver` over `ContinuousClock`, with the UI subscribed to segment/tick state.** The Milestone-1 driver already sleeps to absolute offsets from a single anchor (no chained timers, no cumulative drift — PRD §8) and schedules cues; the model adds no timing math. `ContinuousClock` is the correct monotonic reference because it "does not stop incrementing while the system is asleep" (docset `/documentation/swift/continuousclock`), so position recomputation after backgrounding is exact; `SuspendingClock` would under-count (docset `/documentation/swift/suspendingclock`). Elapsed/remaining and the progress fraction come from the compiled timeline's integer seconds — the same source as every displayed total (PRD §6.2). The get-ready segment is compiled in via the existing `getReadySeconds` parameter but excluded from the progress denominator (ui-spec pre-roll caption: "get-ready is not part of the routine's compiled 5 min 30 s") — progress and elapsed/remaining measure the routine total.
- **D5. Pause is sticky; resume is explicit and re-enters with a fresh 3-2-1.** PRD §6.3's "returning resumes at the paused segment (with a fresh 3-2-1 tone)" is read as *position* resumption, not autoplay: after any pause (user, resign-active, interruption) the stage shows the paused state and resuming — tap or space — plays a fresh 3-2-1 re-entry countdown before the segment continues. Rationale: auto-play on foreground-return would surprise a user who came back to check a message (and acceptance #5's call scenario says the session *is paused* when the call ends, not resumed); the fresh 3-2-1 satisfies the "never lost, never jarring" intent for both texts. The re-entry countdown is engine-level (position unchanged; three tones then advancement resumes), so it is deterministic and testable with the fake clock.
- **D6. Back/skip/end semantics.** Skip jumps to the next segment start. Back restarts the current segment; a second Back within a short window (or within the first ~2 s of a segment) goes to the previous segment — the standard media convention PRD §5.5 names. End raises a confirmation (destructive-role End action per the no-red exception); confirming tears down the stage and, in M5, shows the partial acknowledgment when ended mid-routine (recording is M6). Completion of the final segment transitions to the completion view automatically.

**Audio**

- **D7. Speech: `AVSpeechSynthesizer` behind the existing core announcement protocol.** Current and cross-platform native (docset `/documentation/avfaudio/avspeechsynthesizer` — iOS 7+, macOS 10.14+; no deprecation; OS 26 introduced no successor synthesis API). The service retains its synthesizer instance for the player's lifetime (docset trap: "the system doesn't automatically retain the speech synthesizer"), uses the app's shared audio session on iOS (`usesApplicationAudioSession` default true; the property doesn't exist on native macOS — docset `/documentation/avfaudio/avspeechsynthesizer/usesapplicationaudiosession`), and speaks the localized templates from §6 — announcement *content* is chosen by the UI layer from string-catalog templates; the core runner only signals *when* (its Milestone-1 contract).
- **D8. Tones: `AVAudioEngine` + `AVAudioSourceNode` generating short sine beeps behind the existing tone protocol.** One code path for iOS and macOS with programmatic volume (docset `/documentation/avfaudio/avaudiosourcenode` — iOS 13+/macOS 10.15+). Rejected: `AudioServicesPlaySystemSound` (file-based, system-volume-locked, can't sit above ducked music — docset `/documentation/audiotoolbox/audioservicesplaysystemsound(_:)` notes no programmatic volume); bundled audio assets (PRD §6.4 forbids). Tone vocabulary is the Milestone-1 set: countdown ×3 (distinct short beeps), work-start (distinct, brighter). Voice and tones honor their Settings toggles independently at the service layer, so toggling never touches the runner.
- **D9. Audio session (iOS-family only): `.playback` + `[.duckOthers, .interruptSpokenAudioAndMixWithOthers]`, activated per cue window, deactivated with `.notifyOthersOnDeactivation`.** `.playback` keeps cues audible under the silent switch and screen lock (docset category page — the fitness-timer convention PRD §6.4 requires); `.duckOthers` implies mixing and Apple's docs name "an exercise app" as the exact use case for adding `.interruptSpokenAudioAndMixWithOthers`. Apple warns ducking should last only seconds, so the session activates when a cue window opens (first beep of a T-3 run, or a segment-start announcement) and deactivates shortly after the window's last cue ends — the user's music returns to full volume during the work, which is also the polite behavior. `AVAudioSession` does not exist on native macOS (docset `/documentation/avfaudio/avaudiosession` — no macOS row): the Mac service compiles the session policy out entirely; speech and engine output just play.
- **D10. Interruptions: observe `AVAudioSession.interruptionNotification` (iOS-family) and pause on `.began`.** Current API, posted on the main thread; the handler also respects `AVAudioSessionInterruptionWasSuspendedKey` (a delayed began-notification after process suspension must not re-pause a session the scene-phase path already paused) (docset `/documentation/avfaudio/avaudiosession/interruptionnotification`). Resume stays explicit per D5 — `.shouldResume` hints are ignored by design (recorded so nobody "fixes" it).

**Lifecycle & wake**

- **D11. `scenePhase != .active` auto-pauses.** View-level `@Environment(\.scenePhase)` on the stage reflects its containing scene on both platforms (docset `/documentation/swiftui/scenephase`; the doc's own example is a timer disabled when inactive). Position is preserved by D4's absolute-offset math; no progress is lost to backgrounding, calls, or Siri (PRD §6.3). On Mac, backgrounding the window does *not* pause (the stage may legitimately be watched while another window has focus) — only miniaturizing/closing does; recorded as the deliberate platform difference, driven by the same scenePhase semantics.
- **D12. Screen wake: `UIApplication.isIdleTimerDisabled = true` while the stage is presented on iOS-family; `ProcessInfo.beginActivity([.idleDisplaySleepDisabled, .userInitiated], reason:)` on macOS.** Both verified current (docset `/documentation/uikit/uiapplication/isidletimerdisabled`, whose docs bless exactly this use case and demand resetting when done; `/documentation/foundation/processinfo/beginactivity(options:reason:)` — macOS 10.9+). A small wake service behind a protocol owns set/reset symmetry: enabled on stage appear, disabled on completion, end, and scene-phase background — never leaked past the player's lifetime.

**Stage visuals**

- **D13. The stage renders exclusively on the four appearance-invariant stage tokens** (StageCanvas/StageSurface/StageText/StageTextDim) with PulseAzure as work identity and RecoverMint as rest/get-ready identity — accents only (kicker, progress fill, resume button), never a canvas flood (DESIGN.md `stage.rules`, ui-spec work-segment caption). No `colorScheme` reads anywhere in the player (the stage does not participate in appearance — DESIGN.md dark-mode section).
- **D14. The countdown is the app's single fixed-size exception: SF Pro Rounded, heavy, `monospacedDigit`, scaled from stage geometry to ≥ 25 % of stage height in iPad landscape.** All other stage text is Dynamic Type (workout name ≥ title scale, set indicator and next-up ≥ headline scale — DESIGN.md `across_the_room.minimums`); at accessibility sizes the stage stacks vertically and the countdown yields height before any label truncates (DESIGN.md `stage_numerals.accessibility`).
- **D15. Work vs rest is encoded twice** (DESIGN.md `across_the_room.state_identity`): work leads with the countdown (kicker "Work · Set 2 of 3", name below, next-up replacing the workout-indicator line in the final 5 s per the ui-spec caption); rest/set-rest/get-ready lead with "Next: %@" / "First: %@" at title scale beside the next workout's `WorkoutVisual`, mint hue, countdown large-but-secondary. The stage's media region is the reserved `WorkoutVisual` stage slot (4:3, beside/above per orientation — PRD §4.6; the component's `stage` size already exists from Milestone 3).
- **D16. Foot: full-width progress bar ≥ 6 pt, elapsed/remaining in tabular numerals, and the glass control bar** — StageSurface material, the second and final custom glass element (DESIGN.md `glass_budget`; the budget is now exactly spent). Controls: back · pause/resume (largest, segment-hue) · skip · End (confirms), all ≥ 64 pt targets. No haptics on any transition (DESIGN.md `haptics.player_transitions`); the completion view fires the single `.success` sensory feedback (the user is walking back to the device — DESIGN.md §7), via `sensoryFeedback` (verified iOS 17+/macOS 14+).
- **D17. Motion per DESIGN.md `motion`:** segment crossfade + slight scale settle ≤ 300 ms; final-3-s numeral pulse synced to the beeps; completion hero count-up ≤ 800 ms, once. Under Reduce Motion (`\.accessibilityReduceMotion`, docset-verified) every one becomes an opacity-only fade and the pulse is dropped — the beeps carry the emphasis (DESIGN.md `motion.reduced_motion`).
- **D18. Mac keyboard: space = pause/resume with explicit empty modifiers, ← / → = back/skip, ⎋ = End (confirming).** `keyboardShortcut(_:modifiers:)` defaults to `.command`, so space is bound with `modifiers: []` (docset `/documentation/swiftui/view/keyboardshortcut(_:modifiers:)`); arrows and `.escape` exist on `KeyEquivalent`. Escape maps through the confirmation, never instant teardown.

**Completion & settings**

- **D19. Completion view per ui-spec:** kicker "Nice work", hero active minutes counting up once, routine name, workouts-completed line, Done + Go Again. Go Again recompiles and restarts a fresh run (pre-roll included). The streak/times-completed stat pair renders only when session data exists — in M5 the slot is laid out and empty-collapsed without reflow (see Non-goals). Ending early shows the smaller partial acknowledgment ("You did %@ — saved to history" — the "saved" clause becomes literally true in M6; shipping the string now avoids a key churn) with a single Done.
- **D20. Settings: three new rows in two sections, stored in `@AppStorage`, device-local by design.** Audio: voice announcements toggle, countdown tones toggle (both default on — PRD §6.4). Player: get-ready duration, wheel-style picker 0–30 s in 5 s steps, default 5 (ui-spec §settings). Device-local rationale: audio and pre-roll are environmental preferences (the wall iPad and the pocket iPhone legitimately differ); CloudKit-synced settings would also add model schema for no user benefit — consistent with "Mac-only state stays out of the synced model" (DESIGN.md §10). Toggles tint the accent (one-accent rule); the get-ready row's icon tile is mint (it configures a breathing segment — ui-spec caption).

## 5. Edge cases

Playback:
- Zero-second get-ready (Settings = 0): no pre-roll segment compiles; play starts directly at the first work announcement.
- Single-segment routine (one step, one set, no rests): pre-roll → work → completion; skip from the only segment completes the routine; back restarts it.
- Skip from the final segment completes; back on the first segment restarts it (no previous — second back is a no-op).
- Skip/back during pause: allowed, position updates, stage stays paused (intervention without forced resume).
- Rapid repeated skip: each lands on a segment boundary; cue windows for skipped segments are cancelled — no queued stale announcements (the M1 runner's scheduling contract; §7 pins it at the service layer too).
- A routine edited on another device mid-play: the running timeline is immutable by construction (compiled before play — PRD §6.2); changes apply next play.
- Voice off / tones off / both off: the runner still schedules; the services drop their channel silently. VoiceOver segment announcements (§6) fire regardless of the voice *audio* toggle — they are an accessibility channel, not a preference.

Lifecycle:
- Backgrounded while paused, relaunched: M5 preserves nothing across process death (abandoned-session recording is M6's contract); returning within the same process resumes per D5.
- Interruption `.began` arriving after scene-phase already paused (or with `wasSuspended`): idempotent — one paused state, no double 3-2-1 on resume.
- Locking the screen: `.playback` keeps cue audio eligible, but the session is paused by scenePhase anyway (hands-free means *screen visible*; playing on through a locked screen would desync stage and voice).
- End confirmation open when the app resigns active: session pauses beneath it; the dialog survives.
- Mac: closing the stage window mid-run equals End-without-summary in M5 (position discarded; recording lands in M6); reopening from Play starts fresh. The window remembers nothing into the synced model.

Audio coexistence:
- User's music playing: cues duck it during cue windows only; music returns to full volume between cues; the app never stops it (PRD §6.4). Verified on device as part of the gate.
- No other audio playing: session activation/deactivation is inaudible.
- Silent switch on (iPhone): cues still audible during an active session (`.playback` — fitness-timer convention, PRD §6.4).

## 6. Accessibility & localization

**New string-catalog keys** (English values; `common.save`/`common.cancel` reused; durations, elapsed/remaining, and counts always via `DisplayFormatters` — never hand-assembled):

| Key | English value | Notes |
|---|---|---|
| `player.kicker.work` | Work | work-segment kicker prefix |
| `player.kicker.rest` | Rest | rest + set-rest kicker |
| `player.kicker.get-ready` | Get ready | pre-roll kicker |
| `player.set-indicator` | Set %1$lld of %2$lld | shown when sets > 1 |
| `player.workout-indicator` | Workout %1$lld of %2$lld | work-segment sub-line |
| `player.next` | Next: %@ | rest headline + final-5 s work line |
| `player.first` | First: %@ | pre-roll headline |
| `player.pause` | Pause | control label (VoiceOver; icon-only visually) |
| `player.resume` | Resume | |
| `player.skip` | Skip | |
| `player.back` | Back | |
| `player.end` | End | control bar label |
| `player.end.confirm.title` | End this routine? | confirmation |
| `player.end.confirm` | End Routine | destructive role |
| `player.end.keep` | Keep Going | |
| `player.complete.title` | Nice work | completion kicker |
| `player.complete.workouts` | %lld workout completed / %lld workouts completed | plural variants |
| `player.complete.done` | Done | |
| `player.complete.go-again` | Go Again | |
| `player.partial.message` | You did %@ — saved to history | %@ = formatted active duration |
| `speech.work` | %@ | spoken: workout name, sets = 1 |
| `speech.work-set` | %1$@ — set %2$lld of %3$lld | spoken: work start when sets > 1 |
| `speech.reps` | About %lld reps | spoken once after work announcement when guidance set |
| `speech.rest` | Rest — next: %@ | spoken at rest/set-rest start (set-rest: next = same workout's next set per template below) |
| `speech.set-rest` | Rest — next: set %1$lld of %2$lld | spoken at set-rest start |
| `speech.get-ready` | Get ready — first: %@ | spoken at pre-roll start |
| `speech.complete` | Nice work — %@ | spoken at completion; %@ = formatted active duration |
| `settings.section.audio` | Audio | section header |
| `settings.voice` | Voice announcements | toggle |
| `settings.voice.detail` | Workout names, rests, completion | row subtitle |
| `settings.tones` | Countdown tones | toggle |
| `settings.tones.detail` | 3-2-1 beeps and transitions | row subtitle |
| `settings.section.player` | Player | section header |
| `settings.get-ready` | Get ready | picker row |
| `settings.get-ready.detail` | Before the first workout | row subtitle |

Spoken templates are UI strings (PRD §3.1/§6.4) — they live in the catalog exactly like visible text. Elapsed/remaining render as formatted durations with a system minus for remaining (formatter-provided, not a string literal).

**Accessibility identifiers:** `player.stage`, `player.countdown`, `player.kicker`, `player.name`, `player.setIndicator`, `player.workoutIndicator`, `player.next`, `player.progress`, `player.elapsed`, `player.remaining`, `player.playPause`, `player.skip`, `player.back`, `player.end`, `player.end.confirm`, `player.complete.minutes`, `player.complete.done`, `player.complete.goAgain`, `player.partial.message`; `settings.voice`, `settings.tones`, `settings.getReady`.

**VoiceOver:** the stage announces segment changes via `AccessibilityNotification.Announcement` mirroring the audio cues (DESIGN.md `accessibility.voiceover`) — verified current and cross-platform (docset `/documentation/accessibility/accessibilitynotification/announcement`, iOS 17+/macOS 14+), with high speech-announcement priority on segment changes so they pre-empt in-flight announcements. The countdown is one updating element (label "Time remaining", value the spoken duration — not per-second chatter: value updates are polite except the final 3 s). The control bar is four labeled buttons; the progress foot is one grouped element ("Progress: x of y, n remaining", spoken durations). Completion is readable top-to-bottom; Done is the default focus target.

**Dynamic Type:** everything except the countdown follows Dynamic Type (D14). At AX sizes the stage stacks vertically, the countdown yields height before any label truncates, and the control bar keeps ≥ 64 pt targets. Verified at AX XXXL in the gate.

## 7. Test impact

- **StepBackCore:** expected no changes — compiler and runner (pause/resume/skip/back/complete, cue offsets) are Milestone-1-tested. If wiring reveals a scheduling gap (e.g., a re-entry-countdown hook for D5 or cue-window cancellation on skip), it is implemented and tested *in core* — never patched in the UI layer. Timeline immutability and the get-ready-excluded progress denominator get explicit core tests if not already pinned.
- **App unit tests (`StepBackTests`):** `PlayerSessionModel` against the fake clock — play/pause/resume position math, D5 re-entry (fresh 3-2-1 tones on resume, position unchanged), D6 back-twice semantics, progress fraction excluding get-ready, elapsed/remaining equal to compiled totals; speech/tone services against the runner's cue stream with recording fakes — correct localized template selection (work vs work-set vs set-rest vs rest vs get-ready vs complete), toggle behavior (voice off drops announcements, tones off drops beeps, VoiceOver announcements unaffected), skip cancels the pending cue window; wake-service set/reset symmetry across appear/complete/end/background.
- **UI tests (`StepBackUITests`):** play a short seeded routine — assert pre-roll appears within the cover, kicker/name/countdown/progress identifiers exist, pause toggles to Resume, skip advances segments, back restarts, End shows the confirmation and the partial acknowledgment, and skipping through reaches the completion view with Done dismissing the cover. (Timing-sensitive assertions run against a short-duration routine plus skip; wall-clock waits stay minimal.) iPad lane exercises the landscape side-by-side stage composition.
- **Mac (`StepBackMacUITests`):** stage window opens from Play; space pauses/resumes; escape raises the End confirmation (smoke — the engine is shared code proven on iOS lanes).
- Audio-session coexistence (duck-not-stop under real music) and physical across-the-room checks are device verifications in the gate, not simulator tests — recorded in the closing session journal.

## 8. Acceptance criteria

1. From Routines home, Play on a routine reaches the pre-roll in one tap (< 300 ms perceived), the first workout is announced, and the entire routine then advances hands-free: every work/set-rest/rest segment in compiled order, voice announcing each per §6 templates, 3-2-1 beeps before every transition and the distinct work-start tone at every work start, next-up appearing during rests and the final 5 s of work segments (PRD acceptance #3).
2. The screen never sleeps while the stage is active on iPhone/iPad, and the Mac display is prevented from sleeping during play; wake state is always restored when the stage ends by any path.
3. Work vs rest vs get-ready are unmistakable at 3 m on an iPad in landscape in a lit and a dim room — hue *and* layout, per DESIGN.md `across_the_room` (PRD acceptance #4); countdown ≥ 25 % stage height in iPad landscape; stage text contrast ≥ 7:1; verified on hardware via `make install-ipad` and recorded in the session journal.
4. Pause, background the app, return: the stage shows the paused position exactly; resume plays a fresh 3-2-1 and continues; an audio interruption (call/Siri) pauses the same way (PRD acceptance #5 for the in-process cases; process-death recording is M6).
5. Cues duck the user's music during cue windows and never stop it; cues are audible with the silent switch on during an active session; between cues the music plays at full volume (device verification).
6. Voice and tones toggles work independently and default on; get-ready duration changes the compiled pre-roll (0 s = no pre-roll); all three persist per device.
7. Completion shows the hero active-minutes count-up (once, ≤ 800 ms), routine name, and workouts completed, with Done and Go Again both functional; ending early shows the partial acknowledgment instead; no streak/times-completed values appear in M5 and the layout does not reflow when M6 adds them.
8. Mac: the stage opens as a separate resizable window; space/←/→/⎋ behave per D18; the window's composition follows the same stage rules at any size (PRD acceptance #12 for the player scope).
9. Reduce Motion converts every stage animation to opacity-only fades with beeps carrying the final-countdown emphasis; VoiceOver receives segment-change announcements mirroring the audio cues and can operate all four controls; AX XXXL holds per §6 (PRD acceptance #11 for the player scope).
10. Every new user-facing string (including all spoken templates) resolves from `Localizable.xcstrings` and renders under pseudolocalization; all §6 identifiers exist; the glass budget remains exactly two custom elements app-wide.
11. `make test-core`, `make test-app`, `make test-ipad`, `make test-mac` green; `make gen` idempotent; PLAN.md Milestone 5 gate closed citing the green commit.
