# AGENTS.md

Read [CLAUDE.md](CLAUDE.md) — it is the single source of agent guidance for this repository.

Follow CLAUDE.md's mandatory testing ladder. Run all non-UI tests, project generation, and builds locally. Native Mac UI tests may run locally when the machine is available, or through the manual GitHub-hosted workflow when a clean hosted receipt is useful.

Hosted Mac minutes are limited. Never trigger `.github/workflows/macos-ui.yml` from a push or pull request, never dispatch both suites for one receipt, and never use a full hosted suite as a diagnostic loop. Before manual dispatch, state the reason, choose one suite, and use an exact focused `test_filter` whenever a single method is sufficient. Retain the completed job URL and duration in the task's verification notes.

Spec drafts and implementation briefs belong in `docs/specs/`, not in the repository root.

Implement each spec on its own spec-named branch, using `codex/<spec-slug>` by default; do not implement specs directly on `main`.

For spec implementation, do not call the work complete while the spec's changes are still uncommitted. After implementation and verification, create one coherent commit per implemented spec, staging only files that belong to that spec and leaving unrelated dirty work alone.

Before writing code, read PRD.md fully, then DESIGN.md, then design/ui-spec.html, then PLAN.md. Any UI work must be verified against ui-spec.html (the `design-spec` preview server) before it is called done; player work additionally requires the DESIGN.md across-the-room verification.

External workout/routine/plan automation, including the packaged `stepback-coach` fitness-coach role, must use the Mac app's supported `AgentBridge/` file-drop protocol described in `plugin/README.md`. Read the app-written manifest, write only to its declared inbox, and never edit the SwiftData/SQLite/CloudKit store or any other app-container file. Deletion is intentionally unavailable through the bridge.
