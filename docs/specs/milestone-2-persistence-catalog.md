# Spec: Milestone 2 — Persistence & catalog content

**Status:** Implemented
**Owner screens:** none (no UI ships in this milestone). Owner files: `StepBack/Persistence/` (new — SwiftData models, model-container setup, snapshot mapping, seeding + dedupe), `StepBack/Resources/workout-catalog.json` (new — production catalog v1), `StepBack/Resources/Localizable.xcstrings` (catalog name keys), `StepBack/StepBack.entitlements` + `StepBack/StepBackMac.entitlements` (new), `StepBack/Info.plist` (background mode), `project.yml` (+ regenerated `StepBack.xcodeproj` via `make gen`), `StepBackTests/` (new persistence/catalog/seeding suites), `PLAN.md` (Milestone 2 status line)
**Docs this spec amends:** `PRD.md` §4.2, §4.3, §5.1 (schema-identity and seeding-mechanism amendments spelled out in D3/D8/D9 — the implementation commit applies them). `DESIGN.md` and `design/ui-spec.html` are untouched: no UI pattern, screen, or visual component ships.

**Branch:** `codex/milestone-2-persistence-catalog`. Implementer flips this spec to Status: Implemented and PLAN.md Milestone 2 to `in progress` in the opening commit / `gate passed YYYY-MM-DD (<short-hash>)` in the closing commit.

---

## 1. Problem

Milestone 1 shipped the pure core (catalog format contract, timeline compiler/runner, stats math) with trimmed fixtures only. The app still persists nothing and ships no content: there are no SwiftData models, no CloudKit sync, no production catalog, and a first launch lands on an empty placeholder. PLAN.md Milestone 2 requires the four PRD §4 entities as a CloudKit-safe SwiftData schema with private-database mirroring, a genuinely useful bundled catalog (≥ 80 workouts across the eight categories) plus three starter routines as data, and idempotent seeding so the Routines home (Milestone 3) is never an empty dead end (PRD §5.1, G9, G10).

## 2. Goals

- G1. **SwiftData schema:** `Routine`, `RoutineStep`, `CustomWorkout`, `RoutineSession` per PRD §4.2–4.4, CloudKit-safe from day one (every attribute optional or defaulted, every relationship optional with an inverse, no unique constraints), mapping losslessly to the Milestone 1 core snapshots at the persistence boundary.
- G2. **CloudKit mirroring:** the app's model container mirrors to the user's private CloudKit database on iOS/iPadOS and macOS, with the entitlements and background-mode capability the platform requires; unit tests run against a local in-memory store with sync disabled.
- G3. **Production catalog:** `workout-catalog.json` (catalog v1) bundled in both app targets — 92 workouts across the eight fixed categories, three starter routines, decoded at launch through the Milestone 1 strict `CatalogDecoder`.
- G4. **Catalog localization:** every catalog name key (categories, workouts, focus areas, starter routines) exists in `Localizable.xcstrings` with its English value — the gallery (Milestone 3) inherits a fully localizable content set.
- G5. **Idempotent seeding:** first launch seeds the three starter routines exactly once per install, only into a store with no routines; a cross-device dedupe sweep guarantees CloudKit sync never leaves duplicate starters (PRD acceptance #10).
- G6. **Gate:** app launches to a seeded store on simulator and Mac; all test lanes green; sync smoke-tested across two simulators/devices when feasible.

## 3. Non-goals

- No UI ships: no tab scaffold, no Routines home, no gallery, no empty states — Milestone 3. `ContentView` stays a placeholder; the seeded store is verified by tests and launch smoke, not by screens.
- No onboarding welcome screen (Milestone 6 per PLAN.md "welcome screen + seeding polish"); only the seeding half of PRD §5.1 ships now, because Milestone 3's home needs content to render.
- No player, no audio, no settings storage — Milestones 5/6.
- No workout media content and no `WorkoutVisual` component — `mediaKey` stays nil in every v1 catalog entry (PRD §4.6, G11); the component is Milestone 3 UI work.
- No CloudKit schema promotion to production and no explicit `initializeCloudKitSchema()` pass — development-environment schema is created by automatic export during the sync smoke test; promotion is Milestone 7 hardening (D12).
- No SwiftData migrations and no catalog-version upgrade handling beyond decoding `catalogVersion` — v1 is the first schema and first catalog.
- No instructions text (`instructionsKey` stays nil, PRD §10).
- Checked against PRD §2 non-goals: this milestone adds content and persistence only — no programs, no third-party network surface (CloudKit private DB is the sole allowed network path, G9), no awards, no social.

## 4. Design decisions

- **D1. Models live in the app target (`StepBack/Persistence/`), never in `StepBackCore`.** Milestone 1 D6 fixed the boundary: core takes value snapshots; persistence adapts to core, not vice versa. Each model exposes conversion to its core snapshot (`Routine` → `RoutineSnapshot` with steps ordered by `sortIndex`; `RoutineSession` → the core session value shape), so the compiler and stats functions never see SwiftData types. Rejected alternative: models in the package — would drag SwiftData (and CloudKit-forced optionality) into the pure core and break `make test-core`'s no-persistence gate.

- **D2. CloudKit-safe schema shape, verified against current Apple docs** (offline docset, `/documentation/swiftdata/syncing-model-data-across-a-persons-devices`: SwiftData sync via `NSPersistentCloudKitContainer` does not support unique constraints or non-optional relationships): every attribute has a default value or is optional; every relationship is optional with an explicit inverse; no unique constraints anywhere. Concretely:
  - `Routine.steps` ↔ `RoutineStep.routine`: to-many with cascade delete (deleting a routine deletes its steps); step order is always derived from `sortIndex` (PRD §4.3), never from stored array order — CloudKit does not preserve to-many ordering.
  - `RoutineSession.routine` ↔ `Routine.sessions`: nullify on routine delete — sessions survive via `routineNameSnapshot` (PRD §4.4, §5.2).
  - `CustomWorkout` has no relationships: steps reference it by string id (D3), which is what makes deletion safe (PRD §4.2).
  - Required-in-UX fields (`Routine.name`, `CustomWorkout.name`) are defaulted-empty in the schema; the UI layer validates (PRD §4.2's "optional-with-default in schema for CloudKit").

- **D3. Explicit synced string identity on `Routine` and `CustomWorkout`: an `id` attribute holding a UUID string, generated at creation, never mutated.** PRD §4.3 already requires steps to reference "the custom workout's identifier" as a string, but SwiftData's `persistentModelID` is store-local and not a portable string — a `RoutineStep.workoutID` written on one device must resolve the same custom workout on another, so the identity must be an ordinary synced attribute. `Routine.id` additionally gives the dedupe sweep (D9) a deterministic cross-device tie-break. No unique constraint on either (D2); collisions are cryptographically negligible. **Amends PRD §4.2 and §4.3:** add an `id` row (`String`, UUID string, stable across sync) to both tables.

- **D4. CloudKit container and capabilities.** The model container uses the private database with the explicit container id `iCloud.com.nags.stepback` (`ModelConfiguration(cloudKitDatabase: .private(_:))`, offline docset `/documentation/swiftdata/modelconfiguration`, iOS 17+/macOS 14+ — opting out of entitlement-order discovery keeps the choice deterministic). Capabilities per the same syncing guide: both targets get an entitlements file with iCloud → CloudKit services + that container; the iOS target adds the remote-notifications background mode (silent pushes carry CloudKit change notifications); the macOS target adds App Sandbox with outgoing-network-client (CloudKit needs network from a sandboxed Mac app) and the push-environment entitlement. `project.yml` is the source of truth: entitlements files are authored on disk and wired via target settings, then `make gen` regenerates the committed project — never hand-edit `StepBack.xcodeproj`.

- **D5. The production catalog is one bundled JSON resource, decoded once at launch through `StepBackCore.CatalogDecoder`.** Strictness is inherited from Milestone 1 D8: the catalog is first-party data shipped with matching code, so a decode failure is an authoring error that unit tests catch before ship — the app treats it as unrecoverable, never silently repairs. The decoded catalog is held by an app-level environment value/service so Milestone 3+ screens read one shared instance. The JSON lives in `StepBack/Resources/` (already a resource of both app targets in `project.yml`).

- **D6. Catalog content v1 is the table in §6 — it is the contract, not an illustration.** `catalogVersion` 1; the eight categories in the fixed Milestone 1 D9 order with the same `symbolName`s already proven in the trimmed fixture; 92 workouts (≥ 80 per PLAN.md, 10–14 per category so no category feels thin); all `mediaKey`/`instructionsKey` nil (Non-goals). Every workout is equipment-free bodyweight work, consistent with the wall-propped-iPad use case. The five PRD §5.4 sample-routine workouts (`bridge`, `squat`, `russian-twist`, `bicycle-crunch`, `mountain-climber`) are present so acceptance #2 can be built from the picker. **"Wall Sit" is deliberately absent** so PRD acceptance #8 (add it as a custom workout) exercises a genuinely new entry.

- **D7. Starter routines are catalog data (Milestone 1 D10 format), three of them — short / medium / long** (PRD §5.1), composed only of catalog workouts, each ending on a work step (a routine never ends on a rest — the compiler drops trailing rest, and authored data shouldn't rely on that):

  **`starter.quick-start` — "Quick Start"** (total 290 s ≈ 5 min, hand-computed sum of steps, getReady excluded):
  | # | workoutID | work | sets | setRest | restAfter | repGuidance |
  |---|---|---|---|---|---|---|
  | 1 | `jumping-jack` | 30 | 1 | 0 | 15 | — |
  | 2 | `squat` | 30 | 2 | 10 | 15 | — |
  | 3 | `push-up` | 30 | 2 | 10 | 15 | — |
  | 4 | `plank` | 30 | 1 | 0 | 15 | — |
  | 5 | `mountain-climber` | 30 | 1 | 0 | 0 | — |

  **`starter.full-body-classic` — "Full-Body Classic"** (total 835 s ≈ 14 min):
  | # | workoutID | work | sets | setRest | restAfter | repGuidance |
  |---|---|---|---|---|---|---|
  | 1 | `jumping-jack` | 40 | 1 | 0 | 20 | — |
  | 2 | `squat` | 40 | 3 | 15 | 20 | 15 |
  | 3 | `push-up` | 30 | 3 | 15 | 20 | — |
  | 4 | `lunge` | 40 | 2 | 10 | 20 | — |
  | 5 | `bridge` | 30 | 3 | 10 | 20 | — |
  | 6 | `russian-twist` | 30 | 2 | 10 | 20 | — |
  | 7 | `mountain-climber` | 30 | 2 | 10 | 20 | — |
  | 8 | `plank` | 45 | 1 | 0 | 0 | — |

  **`starter.full-session` — "The Full Session"** (total 1180 s ≈ 20 min):
  | # | workoutID | work | sets | setRest | restAfter | repGuidance |
  |---|---|---|---|---|---|---|
  | 1 | `high-knees` | 40 | 1 | 0 | 20 | — |
  | 2 | `jump-squat` | 30 | 3 | 15 | 20 | — |
  | 3 | `push-up` | 30 | 3 | 15 | 20 | — |
  | 4 | `reverse-lunge` | 40 | 2 | 10 | 20 | — |
  | 5 | `plank-up-down` | 30 | 2 | 10 | 20 | — |
  | 6 | `bicycle-crunch` | 30 | 3 | 10 | 20 | — |
  | 7 | `skater` | 40 | 2 | 10 | 20 | — |
  | 8 | `superman` | 30 | 2 | 10 | 20 | — |
  | 9 | `hollow-hold` | 30 | 2 | 10 | 20 | — |
  | 10 | `burpee` | 30 | 2 | 15 | 30 | — |
  | 11 | `downward-dog` | 40 | 1 | 0 | 15 | — |
  | 12 | `child-pose` | 60 | 1 | 0 | 0 | — |

  The single `repGuidance` value (Full-Body Classic squats, ~15) deliberately exercises the optional field end-to-end through seeding. Totals are asserted in tests via the shared compiler (Milestone 1 G5: one source of truth).

- **D8. Seeding rule: seed the three starters iff the local install has never seeded AND the store contains zero `Routine` rows; run at launch after the container loads, on the main context.** Two conditions, both required:
  - *Store-empty check* (PRD §5.1): CloudKit-synced content that already arrived wins over re-seeding.
  - *Once-per-install flag* (local `@AppStorage`-style value, never synced — same locality stance as PRD §5.1's onboarding-seen state): without it, a user who deletes all routines would be re-seeded on next launch, which contradicts PRD §5.2's deliberate empty state ("invitation to build or re-seed starters" — re-seeding there is an explicit user action, Milestone 3/6).
  Seeding snapshots localized values at seed time: `Routine.name` from the starter's `nameKey`, each step's `workoutNameSnapshot` from the workout's `nameKey` (PRD §4.3 — snapshots are plain strings; a later language switch does not rename existing routines, by design). Seeded routines are ordinary user routines afterwards — editable, deletable, no UX special-casing (PRD §5.1). **Amends PRD §5.1:** the parenthetical "(seed only when the store has no routines at all…)" becomes "seed at most once per install, and only when the store has no routines at all; cross-device duplicates from sync races are removed by the deterministic dedupe sweep".

- **D9. Cross-device duplicate defense: `Routine.seedIdentifier` (optional string, nil on user-created routines, set to the starter key on seeded ones) plus a deterministic pristine-dedupe sweep.** The store-empty check alone cannot satisfy PRD acceptance #10: a second device's first launch almost always precedes its first CloudKit import, so both devices seed and the merge yields six starters. The sweep runs after the container loads at launch and when the app returns to the foreground; for each `seedIdentifier` present on more than one routine it keeps exactly one and deletes the surplus, under these rules:
  - A copy is **pristine** iff it has never been touched: `updatedAt == createdAt` and no sessions reference it.
  - If exactly one copy is non-pristine, keep it; delete the pristine surplus.
  - If several copies are non-pristine, keep all non-pristine copies (user data is never deleted), delete only pristine ones (keeping at least one copy overall).
  - Among all-pristine copies, keep the minimum by `(createdAt, id)` — the `id` tie-break (D3) makes every device delete the *same* surplus copies, so concurrent sweeps converge instead of annihilating both copies.
  Later milestones must maintain `updatedAt` on every user edit (already implied by PRD §4.3); this spec's contract is that seeding writes `updatedAt = createdAt`. Rejected alternatives: a synced "has seeded" flag via key-value store (its own sync race, plus PRD §5.1's stance that seed/onboarding state stays local) and listening for CloudKit import events (heavier machinery for the same eventual result; can be revisited in Milestone 7 if the smoke test shows the launch/foreground sweep reacting too slowly).

- **D10. Test stores are local and in-memory: `ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)`** (both parameters verified on the `ModelConfiguration` initializers page, offline docset). `.none` overrides entitlement discovery so unit tests never touch CloudKit or require an iCloud account (same guide, "Disable automatic sync" section). Seeding and dedupe take the model context and the once-per-install flag as injected parameters so every §5 case is a deterministic unit test.

- **D11. The launch sequence this milestone owns:** create the model container (D4) → run seeding (D8) → run the dedupe sweep (D9) → hand the catalog service (D5) and container to the (still-placeholder) UI. Cold-launch budget stays PRD §8's < 1 s: seeding is a one-time three-routine insert; the sweep on subsequent launches is a fetch over routines with non-nil `seedIdentifier`.

- **D12. CloudKit development schema is created by automatic export during the two-device smoke test; explicit `initializeCloudKitSchema()` and production promotion are deferred to Milestone 7** (the syncing guide's DEBUG-wrapped initialization pattern is the documented mechanism when we need it; running it every debug launch buys nothing at this stage). The smoke test procedure and result (or the reason it was infeasible — e.g., no iCloud account on simulators) are recorded in the session journal per the PLAN.md gate's "when feasible".

## 5. Edge cases

Seeding (each a named unit test over D8's injected inputs):
- Fresh install, empty store → seeds exactly 3 routines with correct localized names, snapshots, `sortIndex` order, `seedIdentifier` set, `updatedAt == createdAt`.
- Second run of the seeding pass (flag set) → no-op.
- Flag unset but store already has any routine (synced content arrived first) → no-op, flag set.
- Flag set and store empty (user deleted everything) → no re-seed (PRD §5.2 empty state stays reachable).
- Store has sessions and/or custom workouts but zero routines, flag unset → seeds (PRD §5.1 says "no routines at all"; other entities are irrelevant).
- iCloud signed out → container still works local-only; seeding proceeds; mirroring resumes when an account appears (CloudKit mirroring's own behavior; smoke-verified, not unit-tested).

Dedupe sweep (named unit tests, in-memory store):
- Two pristine copies of one starter (differing `createdAt`) → the older survives on both "devices" (simulated as two sweeps over the same data).
- Two pristine copies with identical `createdAt` → the smaller `id` survives (deterministic tie-break).
- One pristine + one edited copy → edited survives regardless of age.
- One pristine + one played copy (session attached, `updatedAt` untouched) → played copy survives (session reference makes it non-pristine).
- Two edited copies → both survive.
- Duplicate `seedIdentifier` where one copy's surplus deletion also cascades its steps; no orphan `RoutineStep` rows remain.
- Routines with nil `seedIdentifier` sharing a name → never touched by the sweep (user routines are out of scope by construction).

Schema / mapping:
- `Routine` → `RoutineSnapshot` mapping orders steps by `sortIndex` even when insertion order differs; compiled total of a mapped seeded starter equals D7's hand-computed total.
- `RoutineSession` round-trips the core runner's summary shape (Milestone 1 D12) including partial sessions.
- Deleting a `Routine` cascades its steps and nullifies (not deletes) its sessions; the session keeps `routineNameSnapshot`.
- Deleting a `CustomWorkout` leaves referencing steps intact (name snapshot renders; nothing dangles — D2/D3).

Catalog:
- The production JSON decodes through the strict Milestone 1 decoder: exact category set/order, 92 unique workout ids, every starter step referencing an existing id (all enforced by existing `CatalogError` paths — a failing catalog cannot ship).
- All three starter definitions compile into valid timelines via the shared compiler with the D7 totals.
- Every `nameKey` (8 categories + 92 workouts + 3 starters) and every focus-area key resolves in the string catalog to a non-key value (test iterates the decoded catalog — the JSON and xcstrings can never drift silently).

## 6. Accessibility & localization

No UI ships, so no VoiceOver surfaces or accessibility identifiers are added. This milestone's localization payload is the catalog string set (PRD §3.1.2: built-in workout and category names are catalog data with localization keys). All keys below land in `Localizable.xcstrings` with these English values. Key conventions (already established by the Milestone 1 fixture): `category.<id>`, `workout.<id>`, `focus.<id>`, `starter.<slug>`. Keys are never renamed for copy changes.

**Categories** (fixed order, `symbolName` per Milestone 1 fixture):

| id | key | English value | symbolName |
|---|---|---|---|
| `full-body` | `category.full-body` | Full Body | `figure.mixed.cardio` |
| `core` | `category.core` | Core | `figure.core.training` |
| `arms-shoulders` | `category.arms-shoulders` | Arms & Shoulders | `dumbbell.fill` |
| `chest-back` | `category.chest-back` | Chest & Back | `figure.strengthtraining.traditional` |
| `legs-glutes` | `category.legs-glutes` | Legs & Glutes | `figure.squat` |
| `cardio` | `category.cardio` | Cardio | `figure.run` |
| `mobility-stretch` | `category.mobility-stretch` | Mobility & Stretch | `figure.flexibility` |
| `balance` | `category.balance` | Balance | `figure.yoga` |

**Focus areas** (the complete v1 set; ids appear in workout `focusAreas` below):

| id | English value | | id | English value |
|---|---|---|---|---|
| `core` | Core | | `back` | Back |
| `obliques` | Obliques | | `shoulders` | Shoulders |
| `glutes` | Glutes | | `triceps` | Triceps |
| `quadriceps` | Quadriceps | | `hip-flexors` | Hip Flexors |
| `hamstrings` | Hamstrings | | `endurance` | Endurance |
| `calves` | Calves | | `stability` | Stability |
| `chest` | Chest | | `flexibility` | Flexibility |

(Keys: `focus.<id>`, e.g. `focus.hip-flexors` = "Hip Flexors".)

**Workouts** — catalog v1 content contract (key: `workout.<id>`; `mediaKey`/`instructionsKey` nil throughout):

*Full Body (10)*
| id | English value | focusAreas |
|---|---|---|
| `burpee` | Burpee | endurance, chest, quadriceps |
| `half-burpee` | Half Burpee | endurance, quadriceps, core |
| `bear-crawl` | Bear Crawl | core, shoulders, quadriceps |
| `crab-walk` | Crab Walk | triceps, glutes, core |
| `inchworm` | Inchworm | core, hamstrings, shoulders |
| `squat-thrust` | Squat Thrust | quadriceps, endurance, core |
| `sprawl` | Sprawl | endurance, core, chest |
| `plank-to-push-up` | Plank to Push-Up | core, triceps, shoulders |
| `turkish-get-up` | Turkish Get-Up | core, shoulders, stability |
| `frogger` | Frogger | hip-flexors, quadriceps, core |

*Core (11)*
| id | English value | focusAreas |
|---|---|---|
| `plank` | Plank | core |
| `side-plank` | Side Plank | obliques, core |
| `russian-twist` | Russian Twist | obliques, core |
| `bicycle-crunch` | Bicycle Crunch | core, obliques |
| `crunch` | Crunch | core |
| `reverse-crunch` | Reverse Crunch | core, hip-flexors |
| `dead-bug` | Dead Bug | core, stability |
| `leg-raise` | Leg Raise | core, hip-flexors |
| `flutter-kick` | Flutter Kicks | core, hip-flexors |
| `hollow-hold` | Hollow Hold | core |
| `v-up` | V-Up | core, hip-flexors |

*Arms & Shoulders (10)*
| id | English value | focusAreas |
|---|---|---|
| `pike-push-up` | Pike Push-Up | shoulders, triceps |
| `tricep-dip` | Triceps Dip | triceps, shoulders |
| `diamond-push-up` | Diamond Push-Up | triceps, chest |
| `arm-circle` | Arm Circles | shoulders |
| `shoulder-tap` | Shoulder Taps | shoulders, core |
| `plank-up-down` | Plank Up-Down | triceps, shoulders, core |
| `wall-handstand-hold` | Wall Handstand Hold | shoulders, core, stability |
| `sphinx-push-up` | Sphinx Push-Up | triceps, core |
| `reverse-plank` | Reverse Plank | shoulders, glutes, core |
| `crab-toe-touch` | Crab Toe Touch | triceps, core, endurance |

*Chest & Back (11)*
| id | English value | focusAreas |
|---|---|---|
| `push-up` | Push-Up | chest, triceps, core |
| `wide-push-up` | Wide Push-Up | chest, shoulders |
| `incline-push-up` | Incline Push-Up | chest, triceps |
| `decline-push-up` | Decline Push-Up | chest, shoulders |
| `kneeling-push-up` | Kneeling Push-Up | chest, triceps |
| `wall-push-up` | Wall Push-Up | chest, triceps |
| `superman` | Superman | back, glutes |
| `swimmer` | Swimmer | back, shoulders |
| `reverse-snow-angel` | Reverse Snow Angel | back, shoulders |
| `scapular-push-up` | Scapular Push-Up | back, shoulders |
| `back-extension` | Back Extension | back, glutes |

*Legs & Glutes (14 — deliberately no Wall Sit, see D6)*
| id | English value | focusAreas |
|---|---|---|
| `squat` | Squat | quadriceps, glutes |
| `bridge` | Bridge | glutes, hamstrings, core |
| `single-leg-bridge` | Single-Leg Bridge | glutes, hamstrings, stability |
| `lunge` | Forward Lunge | quadriceps, glutes |
| `reverse-lunge` | Reverse Lunge | quadriceps, glutes, stability |
| `side-lunge` | Side Lunge | quadriceps, glutes |
| `curtsy-lunge` | Curtsy Lunge | glutes, quadriceps |
| `sumo-squat` | Sumo Squat | glutes, quadriceps |
| `squat-pulse` | Squat Pulse | quadriceps, glutes |
| `split-squat` | Split Squat | quadriceps, glutes, stability |
| `calf-raise` | Calf Raise | calves |
| `step-up` | Step-Up | quadriceps, glutes |
| `donkey-kick` | Donkey Kick | glutes |
| `fire-hydrant` | Fire Hydrant | glutes, hip-flexors |

*Cardio (12)*
| id | English value | focusAreas |
|---|---|---|
| `mountain-climber` | Mountain Climber | endurance, core, hip-flexors |
| `jumping-jack` | Jumping Jack | endurance, calves |
| `high-knees` | High Knees | endurance, hip-flexors |
| `butt-kick` | Butt Kicks | endurance, hamstrings |
| `skater` | Skaters | endurance, glutes, stability |
| `jump-squat` | Jump Squat | quadriceps, glutes, endurance |
| `tuck-jump` | Tuck Jump | endurance, quadriceps |
| `star-jump` | Star Jump | endurance, shoulders |
| `fast-feet` | Fast Feet | endurance, calves |
| `shadow-boxing` | Shadow Boxing | endurance, shoulders |
| `lateral-shuffle` | Lateral Shuffle | endurance, glutes |
| `invisible-jump-rope` | Invisible Jump Rope | endurance, calves |

*Mobility & Stretch (14)*
| id | English value | focusAreas |
|---|---|---|
| `cat-cow` | Cat-Cow | back, core, flexibility |
| `child-pose` | Child's Pose | back, flexibility |
| `downward-dog` | Downward Dog | hamstrings, calves, flexibility |
| `cobra-stretch` | Cobra Stretch | core, back, flexibility |
| `hip-flexor-stretch` | Hip Flexor Stretch | hip-flexors, flexibility |
| `hamstring-stretch` | Hamstring Stretch | hamstrings, flexibility |
| `quad-stretch` | Standing Quad Stretch | quadriceps, flexibility, stability |
| `shoulder-stretch` | Cross-Body Shoulder Stretch | shoulders, flexibility |
| `neck-roll` | Neck Rolls | flexibility |
| `thread-the-needle` | Thread the Needle | back, shoulders, flexibility |
| `worlds-greatest-stretch` | World's Greatest Stretch | hip-flexors, hamstrings, flexibility |
| `butterfly-stretch` | Butterfly Stretch | hip-flexors, flexibility |
| `pigeon-pose` | Pigeon Pose | glutes, hip-flexors, flexibility |
| `standing-forward-fold` | Standing Forward Fold | hamstrings, back, flexibility |

*Balance (10)*
| id | English value | focusAreas |
|---|---|---|
| `single-leg-stand` | Single-Leg Stand | stability |
| `tree-pose` | Tree Pose | stability, glutes |
| `warrior-three` | Warrior Three | stability, glutes, hamstrings |
| `single-leg-deadlift` | Single-Leg Deadlift | hamstrings, glutes, stability |
| `standing-knee-raise` | Standing Knee Raise | hip-flexors, stability |
| `heel-to-toe-walk` | Heel-to-Toe Walk | stability, calves |
| `single-leg-hop` | Single-Leg Hop | stability, calves, endurance |
| `side-leg-raise` | Side Leg Raise | glutes, stability |
| `single-leg-calf-raise` | Single-Leg Calf Raise | calves, stability |
| `bird-dog` | Bird Dog | core, back, stability |

**Starter routines:**

| key | English value |
|---|---|
| `starter.quick-start` | Quick Start |
| `starter.full-body-classic` | Full-Body Classic |
| `starter.full-session` | The Full Session |

Guardrails: routine names and `workoutNameSnapshot`s are snapshotted plain strings at seed time (D8), so no dynamic localization applies to persisted rows — this is the PRD §4.3 snapshot contract, not a localization gap. No formatted-duration or date strings ship in this milestone; when they do (Milestone 3), they come from Foundation formatters, never the catalog.

## 7. Test impact

- **New app-target unit suites** (`StepBackTests`, Swift Testing, in-memory stores per D10):
  - *Catalog suite:* production `workout-catalog.json` decodes strictly; workout count ≥ 80 (actual 92) with the exact category distribution above; the five PRD §5.4 sample workouts present; `wall-sit` absent; every starter compiles via the shared compiler with the D7 totals; every catalog key resolves in the string catalog (§5).
  - *Schema/mapping suite:* the §5 schema/mapping cases, including cascade/nullify behavior and snapshot ordering by `sortIndex`.
  - *Seeding suite:* the §5 seeding matrix over injected context + flag.
  - *Dedupe suite:* the §5 dedupe matrix, including determinism (running the sweep with the two copies in either enumeration order deletes the same one).
- `StepBackCore` tests are untouched; `make test-core` must stay green (the boundary work is all app-side per D1).
- UI test bundles untouched beyond keeping the existing launch smoke green (the app now builds a model container at launch).
- Lanes for the gate: `make test-core`, `make test-app`, `make test-ipad`, `make test-mac`, `make build-sim`, `make build-sim-ipad`, `make build-mac`.
- **Manual verification:** two-simulator (or simulator + device) CloudKit sync smoke test — seed on A, confirm routines appear on B without duplicate starters after the sweep; procedure and outcome (or infeasibility reason) recorded in the session journal (D12).

## 8. Acceptance criteria

1. All lanes in §7 pass; no test touches CloudKit, the network, or an iCloud account.
2. Fresh launch on iPhone/iPad simulator and Mac reaches the (placeholder) UI with a store containing exactly the three D7 starter routines — names, step order, timing fields, `repGuidance`, and snapshots all matching the tables; relaunching adds nothing.
3. The schema contains no unique constraints and no non-optional relationships; every attribute is optional or defaulted; both entitlements files carry the CloudKit container `iCloud.com.nags.stepback`; the iOS target has the remote-notifications background mode; `project.yml` and the regenerated project stay in sync via `make gen`.
4. The bundled catalog decodes through the strict Milestone 1 decoder with 92 workouts, the fixed eight-category order, and three starter routines; all three compile to timelines totalling 290 s / 835 s / 1180 s.
5. Every key/value pair in §6 exists in `Localizable.xcstrings`; the coverage test proves no catalog key is missing or unresolved.
6. The seeding and dedupe matrices in §5 all pass, including the deterministic tie-break case.
7. The PRD amendments in D3/D8/D9 are applied to `PRD.md` in the implementation commit.
8. Sync smoke test performed and journaled (or infeasibility journaled) per D12; no duplicate starters after two-device seeding once the sweep has run.
9. All work lands as one coherent commit on `codex/milestone-2-persistence-catalog` (plus the PLAN.md/spec status flips per the workflow rules); the tree is clean afterward.
