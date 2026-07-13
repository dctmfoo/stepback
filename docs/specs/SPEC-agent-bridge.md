# SPEC — Agent bridge: Claude/Codex create and edit workouts, routines, and plans

**Status:** Ready
**Owner screens:** headless feature `StepBack/AgentBridge/` (new: bridge service, manifest writer, command ingestion/validation), `StepBack/Features/Settings/` (amended: bridge toggle + folder reveal), repo `plugin/` (new: Claude Code + Codex skills, JSON schemas, fixtures); `StepBackCore` (new pure types: command payload validation)
**Docs this spec amends:** PRD.md §11 deferred list (agent access moves from unmentioned to shipped, Mac-hosted), AGENTS.md (documents the bridge as the supported programmatic write path)
**Branch:** `codex/agent-bridge`
Sequencing: after SPEC-training-plans.md (plans are part of the exposed surface). **Amended by `plans-weekly-schedule-redesign.md`: plan payloads are schema v2 weekday buckets, `activatePlan` selects My Week, and `deactivatePlan` is retired.** Prior art: Intelli-Expense `docs/specs/SPEC-agent-import-bridge.md` and its shipped `AgentImportBridge.swift` — the file-drop-through-the-app pattern, manifest read model, and validation discipline are adopted; its confirmation philosophy is deliberately not (see D3).

---

## 1. Problem

The owner wants to talk to a coding agent (Claude Code, Codex) about fitness goals — "give me a 4-week push/pull/legs plan, 40 minutes a session" — and have the agent set everything up in StepBack: custom workouts when the catalog lacks a movement, routines with correct timing, and training plans. Today the only write paths are the in-app builder UI and internal helpers (`RoutineLibrary`, `RoutineBuilderModel.save`); there is no supported programmatic surface, and an agent writing the SwiftData store directly would corrupt CloudKit sync. Intelli-Expense solved the same problem class with a file-drop bridge, but its contract is import-only and confirmation-mandatory in-app; StepBack's requirement is the opposite: the agent gets the full authoring surface, confirmation happens conversationally in chat, and only deletion is withheld.

## 2. Goals

- G1. An agent on the Mac can **read** the app's full authoring state (catalog, custom workouts, routines, plans) from a machine-readable manifest.
- G2. An agent can **create and update** custom workouts, routines, and seven-day plans, and select a plan as My Week — the full human authoring surface.
- G3. **No delete capability exists in the protocol.** Any deletion the conversation calls for is escalated: the agent asks the human to delete in the app.
- G4. Changes apply directly — no in-app pending/review step. The consent model is conversational: the packaged skills require the agent to state what it will change and get the human's go-ahead in chat before dropping commands.
- G5. Every command produces a machine-readable outcome (success with resulting IDs, or a precise failure reason) so the agent can verify and report honestly.
- G6. Ships as a repo `plugin/` with a Claude Code skill and a Codex variant sharing one instruction source.

## 3. Non-goals

Checked against PRD §2 — no prescription logic enters the app (the *agent* composes; the app stays a dumb, honest executor), no social/server features, and:

- No delete, archive, or destructive verbs of any kind in the protocol — not even behind a flag.
- No direct SwiftData/CloudKit writes by external processes, no XPC, no local network server, no URL scheme, no App Intents in this pass (the file-drop protocol is the entire surface; richer automation layers can wrap it later).
- No agent access to session history or stats beyond read-only counts in the manifest — the bridge is an authoring surface, not a telemetry export.
- No modification of the built-in catalog (bundled JSON stays read-only truth; agents add *custom* workouts).
- No in-app chat UI, no model execution inside the app — conversation happens in the agent's own harness.
- No iOS/iPadOS bridge host: the bridge runs where agents run (the Mac app); results reach the iPad via existing CloudKit sync.

## 4. Design decisions

### D1 — File-drop protocol through the Mac app, never direct store writes

Adopted verbatim from Intelli-Expense's architectural law: an external process never touches the SwiftData store; it hands files to a folder the app owns, and the app ingests through its own `ModelContext` (reusing the exact save-or-rollback transaction seam the builder uses, `Persistence/ModelContext+Save.swift`). Bridge home: `Application Support/AgentBridge/` inside the Mac app container, containing `manifest.json`, `inbox/`, `processed/`, `failed/`. The absolute path is discoverable (documented in the plugin README and revealable from Settings); tools never hardcode it. The app watches `inbox/` while running and sweeps on launch.

Rejected: a local HTTP/MCP server inside the app (a listening socket in a private no-network app is a category change; PRD's privacy stance wins) and shipping a CLI that links the store (two writers, one store — the corruption class the law exists to prevent).

### D2 — The manifest is the agent's read model

`manifest.json` (schema-versioned) is regenerated on launch and after every mutation, and contains: bridge schema version and paths; catalog version with all categories and workout definitions (id, localized display name, category, focus areas); all custom workouts; all routines with full step detail (workout id + name, work seconds, sets, set-rest, rest-after, rep guidance) and compiled total duration; all plans with seven absolute weekday buckets, ordered slots, and the My Week marker; and read-only session counts per routine. Cursor, repeat, and completion fields are not exposed.

Rationale: Intelli-Expense's manifest-as-read-model proved that grounding the skill in a fresh manifest eliminates the agent's main failure mode — acting on stale or hallucinated app state. The skill's first mandatory step is re-reading the manifest.

### D3 — Direct apply with conversational consent; deletes escalate to the human

Commands validate and apply immediately — there is no pending state, no in-app confirmation card. This inverts Intelli-Expense D3 deliberately: receipts are financial records where a wrong field has real cost, so a human confirms each one in-app; workout content is freely editable, self-correcting (the human sees the result instantly and can say "make it 45 seconds"), and nothing applied is destructive. The protective boundary is placed where the actual risk is instead:

- **The protocol has no destructive verbs.** Create and update only. Update means full-replacement of a named object's content — it can empty a routine's steps but can never remove the routine, a workout, a plan, or any logged session. The worst possible agent mistake is recoverable by another edit.
- **Deletion escalates.** The packaged skills instruct: when the conversation requires deleting anything, tell the human exactly what to delete and where in the app, and stop. The app-side ingester rejects any unknown verb into `failed/` with reason `unknown-verb`, so even a misbehaving tool cannot delete.
- **Chat-level confirmation is a skill obligation, not an app gate:** the skill requires stating the intended changes and getting an explicit go-ahead in conversation before writing to `inbox/`. The app does not (and cannot) verify this — the human chose to run an agent with filesystem access; the app's own guarantees are the two bullets above.
- A Settings toggle **"Allow agent changes"** (default on) lets the owner shut the inbox off entirely; when off, drops fail fast with reason `bridge-disabled`.

### D4 — Command envelope and verbs

Each drop is one JSON file: `<uuid>.json`, an envelope with `schemaVersion`, `commandID` (UUID, the idempotency key), `verb`, and a payload that is the **complete desired object** (create supplies content without an id; update supplies the target id + full content — no patch grammar, no partial merges). Verbs:

- `createCustomWorkout` / `updateCustomWorkout` — name, category id, optional notes.
- `createRoutine` / `updateRoutine` — name plus ordered steps (workout id, work seconds, sets, set-rest seconds, rest-after seconds, optional rep guidance) — exactly the builder's editable surface.
- `createPlan` / `updatePlan` — name plus exactly seven weekday buckets, each with ordered routine refs; empty buckets are rest days.
- `activatePlan` — by id, with Set as My Week selection semantics. `deactivatePlan` is absent from the schema and fails with an explicit `invalid-field` replacement-model path.

Full-replacement updates were chosen over JSON-patch because the skill always holds a fresh manifest (D2), replacement semantics are trivially validated against the same rules as create, and merge grammars are where import protocols grow bugs. Concurrency: envelopes may include the manifest's `updatedAt` for the target object; if present and stale, the command fails with reason `stale-object` instead of silently overwriting — the agent re-reads and retries. Absent, last-writer-wins (same as CloudKit's own policy).

### D5 — Validation discipline (adopted from Intelli-Expense D5)

App-side, before any store write, per command: schema version known (newer → `failed/`, reason `unsupported-schema`); JSON decodes strictly; verb known; all referenced ids exist (workout ids against catalog + custom, routine ids against store, category ids against catalog); durations are positive integer seconds within the builder's existing bounds; sets ≥ 1; names non-empty after trimming and within the builder's length rules; seven unique weekdays are present and day-slot/step counts stay within generous hard caps; file size is capped (1 MB — commands are text); filenames are regenerated internally, never trusted; and `commandID` is checked against the persistent processed-log. Failures and successes retain the original outcome contract.

### D6 — Provenance, honestly minimal

Objects created or updated via the bridge get a lightweight provenance stamp (an optional `lastEditedVia` attribute with a default, per CloudKit rules) surfaced as a quiet caption in routine/plan detail ("Edited by agent") — enough for the owner to understand where a change came from, deliberately short of an audit log. Sessions are never stamped (agents cannot create sessions). Rejected: a full activity feed — the conversation transcript *is* the audit log in this workflow.

### D7 — Plugin packaging: one instruction source, two skills

Repo `plugin/` mirrors Intelli-Expense's proven layout: `plugin/README.md` (protocol contract + paths), `plugin/schema/` (JSON Schemas for manifest and command envelope), `plugin/fixtures/` (valid and invalid command examples used by tests and by agents as few-shot grounding), `plugin/skills/stepback-coach/SKILL.md` (Claude Code) and `plugin/codex-skills/stepback-coach/` (Codex packaging of the same instructions). The skill's contract: (1) read the manifest fresh; (2) discuss goals and propose concrete workouts/routines/plans in chat; (3) get explicit conversational go-ahead; (4) write commands; (5) read outcomes from `processed/`/`failed/` and report truthfully, including failures; (6) escalate all deletions to the human; (7) never edit bridge folders other than `inbox/`, never touch the store or app container elsewhere. Instructions and schemas only — no bundled executables.

## 5. Edge cases

- **App not running when commands drop:** launch sweep ingests them in filename-timestamp order; outcomes appear then. The skill must not assume synchronous application — it polls outcomes briefly and otherwise tells the human "open StepBack on the Mac to apply".
- **Batch ordering:** commands referencing objects created earlier in the same batch (create routine, then a plan using it) are supported by sweeping in order and resolving ids from the just-written outcomes only if the plan command references the create command's `commandID` as a placeholder ref; otherwise the skill waits for the routine's outcome and uses the real id. (Placeholder refs: `"routineRef": {"fromCommand": "<uuid>"}` — the one convenience the envelope grants batches.)
- **Update racing a human edit:** stale `updatedAt` → `stale-object` failure (D4); no merge attempted.
- **Update targeting an object deleted in-app moments before:** `unknown-id` failure; the agent re-reads the manifest.
- **Plan referencing a custom workout's routine whose workout was deleted by the human:** allowed — mirrors SPEC-training-plans D7 (slots degrade to name-snapshot state); the manifest marks the broken reference so the agent can offer a repair edit.
- **Bridge disabled mid-sweep:** in-flight command finishes; remaining inbox files fail `bridge-disabled`.
- **Duplicate `commandID` with different content:** treated as a replay — original outcome returned, new content ignored, outcome notes `duplicate-command`.
- **Malformed/oversized/binary file in inbox:** straight to `failed/` with reason; never crashes ingestion; remaining files unaffected.
- **iCloud sync off or unavailable:** bridge still works locally on the Mac (SwiftData is local-first); iPad convergence follows whenever sync resumes — no bridge-specific handling.
- **Manifest read while a write is in progress:** manifest writes are atomic (temp file + rename), so readers never see a torn file.

## 6. Accessibility & localization

The bridge is headless; user-facing surface is Settings plus the provenance caption.

| Key | Value | Notes |
|---|---|---|
| `settings.agentBridge.title` | `Agent Access` | Settings section header |
| `settings.agentBridge.toggle` | `Allow agent changes` | Default on |
| `settings.agentBridge.footer` | `Coding agents on this Mac can create and edit workouts, routines, and plans. They can never delete anything.` | Section footer, states the guarantee |
| `settings.agentBridge.reveal` | `Show Bridge Folder in Finder` | Mac only |
| `detail.provenance.agent` | `Edited by agent` | Caption on routine/plan detail (D6) |

Manifest display names for catalog workouts are resolved through the existing localization path before writing (agents read final display strings, not keys). Protocol reasons/verbs are machine identifiers, not user-facing strings — never in the catalog.

Accessibility identifiers: `settings.agentBridge.toggle`, `settings.agentBridge.reveal`, `detail.provenance.agent`. VoiceOver: the Settings section reads header, toggle state, then footer as standard form elements; the provenance caption is part of the detail summary group. No Dynamic Type concerns beyond standard form behavior.

## 7. Test impact

- **Core (`make test-core`)**: envelope/payload validation rules as pure functions — bounds, id-reference shapes, full-replacement semantics, placeholder-ref resolution — against fixture JSON (valid + each invalid class).
- **App unit (`make test-app-unit`)**: end-to-end ingestion against an in-memory container and temp bridge directory: create/update each object type; verb rejection (any delete-shaped verb → `unknown-verb`); idempotent replay; stale-object; bridge-disabled; oversized file; ordering with placeholder refs; manifest regeneration correctness after each mutation; atomic manifest write.
- **Mac UI (`make test-mac`)**: Settings section renders, toggle persists, reveal button exists; provenance caption appears on an agent-edited routine.
- **Fixtures double as contract tests:** `plugin/fixtures/` files are consumed by the unit suite, so skill examples and app behavior cannot drift apart.
- iOS/iPad lanes: no bridge host; full suites pass unchanged (provenance caption renders on all platforms).

## 8. Acceptance criteria

1. With the toggle on, dropping valid create/update commands for custom workouts, routines, and plans into `inbox/` results in the objects existing in the app (visible in UI, synced via CloudKit) with correct content, and `processed/` outcomes carrying their ids.
2. No protocol input can delete or archive anything: unknown and delete-shaped verbs land in `failed/` with `unknown-verb`; update payloads cannot remove objects, only rewrite their content.
3. `activatePlan` obeys My Week exclusivity exactly as Set as My Week; `deactivatePlan` is rejected with the documented replacement-model field.
4. Every failure class in D5/§5 produces the specified machine-readable outcome file and never interrupts ingestion of subsequent commands; duplicate `commandID`s replay without double-apply.
5. The manifest always reflects post-mutation state, is schema-valid against `plugin/schema/manifest.schema.json`, and is written atomically.
6. The Claude and Codex skills in `plugin/` share one instruction source, mandate manifest-first grounding, conversational go-ahead before writing, truthful outcome reporting, and deletion escalation; fixtures validate against the schemas and are exercised by the unit suite.
7. Settings strings/identifiers from §6 exist in the catalog; the toggle gates ingestion (`bridge-disabled` when off); the provenance caption appears for agent-edited objects.
8. `make test-core`, `make test-app-unit`, and `make test-mac` pass; iOS/iPad suites pass unchanged.
