# StepBack Agent Bridge Protocol

Command schema version: `2`
Manifest schema version: `3` (`schema/manifest-v2.schema.json` preserves the prior strict contract)

This plugin contains instructions and JSON contracts only. It ships no executable and never writes StepBack's SwiftData, SQLite, CloudKit, or app-container database files. Agents write command data to the Mac app's inbox; the running StepBack app validates, persists, and syncs changes through its own model container.

## The coach role

The packaged `stepback-coach` skill is a practical fitness coach as well as a protocol operator. Its shared conduct contract lives in [shared/stepback-coach-instructions.md](shared/stepback-coach-instructions.md): it performs a short intake, uses conservative programming defaults, composes from the catalog first, and keeps medical and bridge-safety boundaries explicit. The Claude and Codex wrappers both delegate to that one file.

## Locate the manifest

Open StepBack on the Mac once, then use **Settings → Agent Access → Show Bridge Folder in Finder**. Read `manifest.json` there. The common sandbox location is:

```text
~/Library/Containers/com.nags.stepback/Data/Library/Application Support/AgentBridge/manifest.json
```

Do not assume that path. Once found, treat the manifest's absolute `inboxPath`, `processedPath`, and `failedPath` as authoritative.

## Folder layout

```text
AgentBridge/
  manifest.json
  inbox/
    <timestamp>-<uuid>.json
  processed/
    <command-id>.command-<uuid>.json
    <command-id>.outcome.json
  failed/
    <command-id>.command-<uuid>.json
    <command-id>.outcome.json
```

The app creates and owns every directory except individual command files placed in `inbox/`. Agents may read the whole bridge folder but may write only new files inside `inbox/`.

## Command envelope

Every command is one JSON object conforming to [command.schema.json](schema/command.schema.json):

```json
{
  "schemaVersion": 2,
  "commandID": "5d39f61b-3c2e-4be7-a264-b4b75d20c7ee",
  "verb": "createRoutine",
  "payload": {
    "name": "Morning Core",
    "steps": [
      {
        "workoutID": "bridge",
        "workSeconds": 30,
        "sets": 3,
        "setRestSeconds": 10,
        "restAfterSeconds": 15
      }
    ]
  }
}
```

Updates are full replacements. Include `expectedUpdatedAt` from the latest manifest to reject a racing human edit with `stale-object`; omit it only when deliberate last-writer-wins behavior is acceptable.

Supported verbs:

- `createCustomWorkout`, `updateCustomWorkout`
- `createRoutine`, `updateRoutine`
- `createPlan`, `updatePlan`
- `activatePlan` (sets that plan as **My Week**)

There is no delete or archive verb. Delete-shaped or unknown verbs fail with `unknown-verb`.
The retired `deactivatePlan` verb fails with `invalid-field`; select another plan with
`activatePlan`, or delete the current plan in the app if the intended result is to have no My Week.

Plans are repeating weekday schedules. `createPlan` and `updatePlan` provide exactly seven
absolute weekday buckets (`1` = Sunday through `7` = Saturday); each bucket contains an ordered
slot list, and an empty list is a rest day:

```json
{
  "schemaVersion": 2,
  "commandID": "5d39f61b-3c2e-4be7-a264-b4b75d20c7ef",
  "verb": "createPlan",
  "payload": {
    "name": "Normal Week",
    "days": [
      { "weekday": 1, "slots": [] },
      { "weekday": 2, "slots": [{ "routineRef": { "id": "routine-id" } }] },
      { "weekday": 3, "slots": [] },
      { "weekday": 4, "slots": [] },
      { "weekday": 5, "slots": [] },
      { "weekday": 6, "slots": [] },
      { "weekday": 7, "slots": [] }
    ]
  }
}
```

## Ordered batches

Name command files so lexical order is execution order, for example `20260711T170000Z-01-<uuid>.json`. A plan slot can refer to a routine created earlier in the same sweep:

```json
{"routineRef":{"fromCommand":"a1111111-1111-4111-8111-111111111111"}}
```

The earlier command must already have a successful outcome. The safer interactive flow is to wait for that outcome and then use its real routine ID.

## Outcomes

Every input moves to `processed/` or `failed/` beside `<command-id>.outcome.json`. Success outcomes contain `resultingIDs` and the new `updatedAt`. Failures contain a machine reason and, when applicable, an exact `field` path.

Reasons include `unsupported-schema`, `invalid-json`, `unknown-verb`, `invalid-field`, `unknown-id`, `stale-object`, `bridge-disabled`, `file-too-large`, `unsupported-file-type`, and `ingestion-failed`.

`commandID` is the idempotency key. The app normalizes UUIDs to lowercase, including outcome filenames and `routineRef.fromCommand` lookups. Reusing the UUID in any letter case replays the original outcome with `duplicateCommand: true`; new content is ignored and is never applied twice.

## Safety contract

- Read `manifest.json` immediately before proposing changes.
- State the exact custom workouts, routines, weekday schedule, and My Week selection changes in chat.
- Wait for explicit human approval before writing commands.
- Never write outside `inbox/` and never touch the app's persistence files.
- Never request deletion through the bridge. Tell the human exactly what to delete in StepBack and stop.
- Poll both outcome folders briefly and report actual success or failure. If no outcome appears, ask the human to open StepBack on the Mac.
