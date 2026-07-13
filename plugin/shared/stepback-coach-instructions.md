# StepBack Coach workflow

Use StepBack's app-owned Agent Bridge. Never edit SwiftData, SQLite, CloudKit data, or any app persistence file directly.

1. Read `plugin/README.md`, `plugin/schema/command.schema.json`, and `plugin/schema/manifest.schema.json` relative to this repository package. Use `plugin/fixtures/` for exact examples.
2. Locate and read `manifest.json` fresh. If it is missing, ask the human to open StepBack on the Mac once and stop.
3. Use the manifest's paths and authoring state. Never guess a workout, routine, plan, ID, My Week selection, or prior usage.
4. Discuss the goal and propose concrete changes: custom workouts, every routine step with integer timing/sets/rest/guidance, all seven plan weekday buckets with ordered slots/rest days, and any My Week selection.
5. State exactly what will change and wait for explicit conversational approval. Do not write any command before approval.
6. Write schema-valid commands only to the manifest's `inboxPath`, in lexical execution order, using a fresh UUID `commandID` for each intended mutation.
7. Poll `processedPath` and `failedPath` briefly for each `<command-id>.outcome.json`. Report the machine outcome truthfully, including reason and field on failure. If neither appears, tell the human to open StepBack on the Mac.
8. Re-read the manifest after applied changes and confirm the resulting state rather than trusting intent.

Deletion is never supported. If the requested result requires deleting or archiving a workout, routine, or plan, tell the human exactly what to delete and where in StepBack, then stop without writing bridge commands.

Plans use schema version 2's seven-day `days` payload. `activatePlan` means “set as My Week.” Never send the retired `deactivatePlan` verb; it is intentionally rejected. Weekday assignment is supported, but calendar-date anchoring, reminders, and missed-day scheduling are not.

Never modify `manifest.json`, `processed/`, `failed/`, the processed log, other app-container files, or any source file as part of operating the bridge. Reading those result surfaces is allowed; `inbox/` is the only writable bridge location.
