# StepBack

**A private routine builder and hands-free workout player — compose routines from a workout gallery once, then press play and step back.** StepBack is iPad-first, with first-class iPhone and native Mac apps, private iCloud sync, and no accounts, analytics, ads, or third-party backend.

> Personal app in active development. App Store plans are still to be decided.

## Simple always works

StepBack started from one product rule: **setting up a workout must never be the reason you skip the workout.** Pick movements, set work/rest timing once, and save the routine. When it is time to train, press Play, lean the iPad against the wall, and follow the large timer and audio cues. Nothing mid-routine requires touching the device.

That constraint shapes the whole app: time-driven routines instead of rep-gated screens, one-tap playback from the home screen, calm stats instead of dashboards, and an across-the-room stage that makes work and rest unmistakable.

## What it does

| Area | What you get |
|---|---|
| Workout gallery | 90+ built-in movements across eight categories, search, focus areas, and custom workouts |
| Routine builder | Ordered steps with work time, sets, between-set rest, after-step rest, optional rep guidance, drag reorder, and one shared computed total |
| My Week | Seven weekday buckets for sequencing your own routines; today is derived from the selected weekly plan and completed sessions |
| Hands-free player | Get-ready countdown, automatic work/rest transitions, spoken cues, 3-2-1 tones, next-up context, oversized controls, and a screen that stays awake |
| Honest stats | Last done, times completed, weekly active minutes, and day streaks derived from session history; partial sessions stay partial |
| Private sync | SwiftData mirrored through the user's private CloudKit database; no service account or third-party backend |
| Platforms | iPadOS and iOS 26+, plus a native macOS 26+ app with keyboard controls and a resizable player stage |

## The agent bridge

StepBack has a second input surface for the era of people working alongside AI agents. The native Mac app publishes a read-only manifest describing the user's available workouts, routines, and plans, then watches an app-owned inbox. Claude Code and Codex skills in [`plugin/`](plugin/) can compose custom workouts, routines, and weekly plans conversationally.

The write boundary is deliberately narrow:

1. The agent reads the app-written manifest and prepares a proposed workout, routine, or week.
2. The person reviews the proposal and gives explicit confirmation in the conversation.
3. The agent drops a schema-validated JSON command into the app-owned inbox.
4. The running app validates, persists, and syncs the change, then writes a machine-readable outcome.

**Agents never touch SwiftData or CloudKit directly, and the protocol has no delete command.** The app remains the sole persistence writer. The included coach persona is the worked example: ask for a three-day dumbbell week, review the proposed schedule, and approve it into the app. Pain, injury, and medical topics route to explicit safety escalation instead of workout prescription.

See the [Agent Bridge protocol](plugin/README.md), its [Claude Code coach skill](plugin/skills/stepback-coach/SKILL.md), and the matching [Codex coach skill](plugin/codex-skills/stepback-coach/SKILL.md). The same app-owned-inbox pattern also ships in [Intelli-Expense](https://github.com/dctmfoo/intelli-expense) for review-gated receipt imports: two apps, one reusable trust boundary.

## Requirements

- macOS with Xcode 26 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.43+
- iOS/iPadOS/macOS 26+ deployment targets
- No Apple Intelligence requirement and no special workout hardware

Simulator builds and deterministic tests do not require an Apple Developer account. The maintainer's bundle IDs, App Store distribution setup, and private CloudKit production container are not part of the contributor build contract. A third-party physical-device fork must replace the `com.nags.*` bundle IDs and `iCloud.com.nags.stepback` container with identifiers owned by its Apple Developer team in `project.yml`, both entitlements files, and `StepBackModelContainer.swift`; then regenerate the project before signing.

## Building and testing

```sh
make gen
make test-core
make test-app-unit
make build-sim
```

`project.yml` is the source of truth; the generated `StepBack.xcodeproj` is committed and must stay reproducible.

| Target | Purpose |
|---|---|
| `make gen` | Regenerate the Xcode project with XcodeGen |
| `make test-core` | Run the pure `StepBackCore` timeline, catalog, plan, and stats tests |
| `make test-app-unit` | Run app models, persistence, routing, bridge, and source-contract tests without UI automation |
| `make test-app` | Run the full iPhone simulator unit and UI gate |
| `make test-ipad` | Run the full iPad simulator unit and UI gate |
| `make test-mac` | Run the native Mac UI gate on a local Mac |
| `make test-perf` | Opt in to launch, play-latency, gallery-scroll, and timer-integrity measurements |
| `make test-perf-iphone` / `make test-perf-ipad` | Run acceptance measurements on configured physical devices |
| `make build-sim` / `make build-sim-ipad` | Build for the standard iPhone or iPad simulator |
| `make build-mac` | Build the native Mac app; unsigned when no local team is configured |

After the app and CloudKit identifiers belong to your team, copy `Makefile.local.example` to `Makefile.local` and add your own signing and paired-device values:

```make
TEAM_ID := YOUR_TEAM_ID
IPHONE_ID := YOUR_PAIRED_IPHONE_ID
IPAD_ID := YOUR_PAIRED_IPAD_ID
```

`Makefile.local` is ignored by git. You can also supply the same variables on the command line, for example `make install-iphone TEAM_ID=... IPHONE_ID=...`. Never commit signing values, device identifiers, profiles, or local paths.

## Docs-first, agent-assisted development

The documentation is part of the product. [`PRD.md`](PRD.md) defines the behavior and explicit non-goals; [`DESIGN.md`](DESIGN.md) defines the tokens and interaction rules; [`design/ui-spec.html`](design/ui-spec.html) is the screen-by-screen layout reference; [`PLAN.md`](PLAN.md) records milestone gates; and [`docs/specs/`](docs/specs/) contains the implementation contracts.

The repository is therefore also a worked example of spec-driven development with Claude Code and Codex: agents implement against durable contracts, deterministic core logic is tested outside the UI, and external agent writes go through the same review-gated app boundary the product exposes.

## Privacy

StepBack stores routines, plans, custom workouts, settings, and session history on the user's devices and in their private iCloud database when sync is available. It has no account service, analytics, advertising, or third-party network backend. See the full [privacy policy](PRIVACY.md).

## License

[MIT](LICENSE) © 2026 Nagarajan Natarajan.
