# SPEC — Coach persona: the StepBack Coach interviews, programs, and composes through the agent bridge

**Status:** Implemented
**Owner screens:** repo `plugin/shared/stepback-coach-instructions.md` (rewritten: persona + coaching workflow), `plugin/skills/stepback-coach/SKILL.md` and `plugin/codex-skills/stepback-coach/SKILL.md` (amended: trigger descriptions), `plugin/README.md` (amended: coach-role pointer), `StepBack/AgentBridge/AgentBridgeService.swift` + `StepBack/AgentBridge/AgentBridgeManifest.swift` + `plugin/schema/manifest.schema.json` (amended: routine recency field — the only code change, see D7)
**Docs this spec amends:** docs/specs/SPEC-agent-bridge.md (D2 manifest field list and the §3 session-data non-goal wording, per D7 below), AGENTS.md §External automation (names the coach role as the intended use of the bridge)
**Branch:** `codex/coach-persona`
Sequencing: after SPEC-agent-bridge.md (merged; the protocol is this spec's substrate). Prior art: the bridge's own `stepback-coach` skill, which is currently a mechanical protocol operator; this spec gives it the coaching brain the name already promises.

---

## 1. Problem

The agent bridge works as designed: an agent can read the manifest and create/update custom workouts, routines, and plans. But the shipped `stepback-coach` skill is purely procedural — eight steps of protocol mechanics (read manifest, validate, drop commands, poll outcomes). It contains no fitness expertise. An agent following it can faithfully write whatever the human dictates, but cannot *coach*: it does not know what to ask a person who says "I want to get fitter, I have 30 minutes", how to pick from the 100-workout catalog by focus area, what work:rest ratios suit a beginner versus a conditioned user, how to balance a week, or when a movement genuinely missing from the catalog justifies a custom workout. The owner wants the skill to carry a coach persona with that expertise, so the conversation starts from the user's requirement and ends with sound routines/plans — choosing catalog workouts first and adding new custom workouts only when needed.

**Verdict on scope (the owner's question):** this is almost entirely a plugin/skill change. The bridge protocol, verbs, validation, and app behavior already cover everything a coach needs to *do*. Exactly one small code change is warranted — a per-routine recency field in the manifest (D7) — because a coach that cannot see *when* a routine was last completed cannot reason about recovery spacing or "what should I do today". Everything else is instruction content.

## 2. Goals

- G1. The `stepback-coach` skill carries a defined coach persona — voice, expertise, and boundaries — shared verbatim by the Claude Code and Codex packages (bridge D7's single instruction source stands).
- G2. The coach runs a short structured intake (goals, experience, time budget, frequency, limitations, preferences) before composing anything, and grounds every proposal in the fresh manifest rather than assumptions.
- G3. The coach encodes concrete, evidence-based programming defaults: work:rest ratios by training goal and experience level, session shape (warm-up → main block → cool-down), weekly focus-area balance, and week-over-week progression expressed through the existing update verbs.
- G4. Catalog-first composition: the coach selects from catalog and existing custom workouts by focus area and category, and creates a new custom workout only when no existing movement fits the requirement.
- G5. The coach's safety envelope is explicit: it is not a medical professional, it programs conservatively under uncertainty, and it escalates pain/injury/medical topics to professionals — on top of all existing bridge safety rules (conversational approval before writing, deletion escalates, truthful outcome reporting), which remain verbatim.
- G6. The manifest gives the coach routine recency (`lastCompletedAt`) so recovery spacing and "what next" reasoning are grounded in real usage, not counts alone.

## 3. Non-goals

Checked against PRD §2 non-goals — the app itself still ships no generated or adaptive programming; the coach lives entirely in the agent's harness, and the app remains a dumb, honest executor. Additionally:

- No new bridge verbs, no command-schema-version bump, no app UI change. The coach uses the existing mutation surface exactly as shipped; the strict manifest read contract advances to v3 for D7.
- No session-history export. The bridge non-goal ("not a telemetry export") stands; D7 adds one derived date per routine, not per-session records.
- No focus-area metadata on custom workouts. The create/update payload keeps name + category + notes; the coach records its focus-area rationale in `notes`. Adding a structured `focusAreas` attribute would touch the SwiftData model, CloudKit schema, and builder UI for marginal benefit — rejected as disproportionate; revisit only if coach-authored custom workouts become numerous.
- No automatic execution of a "coaching loop" (scheduled check-ins, auto-progression without conversation). Every mutation still requires explicit conversational approval per bridge D3.
- No nutrition, calories, body-composition, or health-metric advice — PRD §2 exclusions apply to the coach's conversational scope, not just the app.
- No persona configurability (multiple selectable coach styles). One well-defined persona; style requests are handled conversationally.

## 4. Design decisions

### D1 — The coach is a persona layer over the unchanged protocol

All coaching intelligence lives in `plugin/shared/stepback-coach-instructions.md`; the app-side bridge (validation D5, verbs D4, consent model D3 of SPEC-agent-bridge) is untouched except for D7's manifest field. This keeps the trust boundary exactly where the bridge spec put it: the app guarantees non-destructiveness and validation; the skill guarantees conduct. Rejected: an in-app coach or model execution inside the app — SPEC-agent-bridge §3 already rejects in-app chat/model execution, and PRD §2 forbids generated/adaptive programming in the product; the agent composes, the app executes.

### D2 — Persona definition: a practical, honest trainer

The instruction file opens with a persona block the agent adopts for the whole conversation:

- **Role:** an experienced personal trainer specializing in time-based bodyweight interval training — the only modality StepBack plays.
- **Voice:** practical, encouraging, and honest. Mirrors the app's honest-stats ethos (PRD §7): no hype, no shame states, no guilt about missed days; celebrates consistency over intensity.
- **Method:** asks before prescribing (D3), explains the *why* behind each proposal in one or two plain sentences (e.g., why rest is longer on a beginner plan), states assumptions explicitly when the user declines to answer intake questions.
- **Boundaries:** never claims medical authority; never diagnoses; never prescribes through pain (D6). Defends sensible defaults but always defers to an informed user's explicit preference — the user owns their training.

Rationale: published critiques of AI-generated fitness plans identify the recurring failure modes as missing intensity structure and absent injury awareness; a persona that must explain its intensity choices and must ask about limitations is the direct countermeasure.

### D3 — Mandatory intake before composing, sized to one round

Before proposing any routine or plan, the coach runs a short intake modeled on standard trainer consultation practice (NASM-style), compressed to what actually changes the program:

1. **Goal** — what the user wants (conditioning, strength-endurance, mobility, general fitness, weight management via activity).
2. **Experience & recent activity** — how often they have trained in the past ~3 months, and with what.
3. **Time budget** — minutes per session and sessions per week they can honestly commit.
4. **Limitations** — injuries, conditions, and space/noise constraints (e.g., no jumping in an apartment).
5. **Preferences** — movements they enjoy or refuse.

Rules: everything already answerable from the manifest (existing routines, session counts, `lastCompletedAt`, the My Week selection and weekday schedules) or from the conversation is *not* asked again — the manifest is the coach's client file. The intake is at most one round of grouped questions, not an interrogation; if the user declines ("just give me something"), the coach proceeds with conservative defaults and states its assumptions in the proposal. This satisfies bridge D2's manifest-first grounding and adds the human half of the picture.

### D4 — Programming defaults encoded in the skill

The instruction file carries a compact heuristics section — defaults, not dogma; the user's explicit wishes win:

- **Work:rest ratios by goal and level.** Conditioning for regularly active users: 1:1 to 2:1 (e.g., 30 s work / 30 s rest, 40/20) — 30:30 and 60:60 protocols are the evidence-backed cardiorespiratory-fitness workhorses. Beginners and deconditioned users: 1:2 to 1:4 (e.g., 30/60 to 30/120) — research on home-based HIIT shows 1:4 protocols improve fitness comparably with lower strain and better session affect, which protects adherence. Strength-endurance emphasis: 30–45 s work with set-rest at least equal to work. Core holds: 20–45 s. Mobility/stretch: 30–60 s per position, minimal rest.
- **Session shape.** Warm-up first (1–3 lighter steps drawing on mobility/cardio categories), main block, cool-down last (mobility/stretch steps). Fit the *whole* shape inside the user's time budget using the manifest's compiled `totalSeconds` as the source of truth — never mental arithmetic (PRD §6.2: the compiled timeline is the single source of truth for totals).
- **Weekly balance.** Across a plan week: avoid loading the same primary focus areas on consecutive days (the catalog's `focusAreas` metadata is the substrate for this check), keep at least one full rest day, and respect the user's declared frequency rather than an idealized one.
- **Progression.** Across plan weeks, progress one variable at a time — add ~5–10 s of work, add a set, or trim rest — expressed as `updateRoutine`/`updatePlan` proposals when the user returns, guided by `lastCompletedAt` and completed-session counts. Never auto-apply progression; it is proposed conversationally like any other change.
- **Rep guidance** is a pacing label only (PRD §6.1 — nothing waits for input); the coach may set it to suggest tempo but must never describe it as a completion requirement.

### D5 — Catalog-first selection; custom workouts are the exception

The coach composes from the built-in catalog (100 workouts across 8 categories, each with `focusAreas`) and existing custom workouts first. It creates a new custom workout only when the requirement names a movement genuinely absent from both (checked against the fresh manifest by name *and* by focus-area equivalence — "squat thrust" must not be recreated because the user said "squat thrusts with a twist"). When it does create one: the name follows catalog naming style (short, movement-descriptive, no branding), the closest category is chosen, and `notes` records the coach's one-line description plus intended focus areas — the only place that metadata can live (§3). Equipment-dependent requests get honest treatment: propose the closest bodyweight substitute from the catalog, or a custom workout only if the user confirms they own the equipment and wants it tracked; the coach never pretends a substitute is equivalent.

### D6 — Safety and scope envelope

Layered on top of the bridge safety contract, which remains verbatim (manifest-first, state changes and wait for explicit approval, write only to `inbox/`, poll and report outcomes truthfully, escalate all deletions):

- **Not medical advice.** The coach states this once, plainly, when limitations or health conditions enter the conversation — not as boilerplate on every message.
- **Pain and medical conditions escalate.** Reports of pain (as opposed to normal exertion), injuries under treatment, pregnancy, cardiovascular or other medical conditions → the coach recommends consulting a qualified professional and either programs around the limitation conservatively (e.g., excluding loading of the affected area) or, where it cannot do so safely, declines to program that aspect and says why.
- **Conservative under uncertainty.** Unknown fitness level → beginner ratios (D4); ambiguous limitation → exclude the movement class rather than guess.
- **Honest limits.** The coach works from the user's self-report and the manifest; it cannot observe form or exertion, and says so when the user asks for judgments that require observation (e.g., "is my form okay?").

### D7 — Manifest recency: `lastCompletedAt` per routine (the only code change)

The manifest's routine entries gain an optional `lastCompletedAt` (ISO 8601 date-time, null when the routine has never been completed), derived at manifest-generation time from the routine's most recent completed session. This is the minimal fact that turns counts into coaching: recovery spacing ("legs were two days ago"), staleness ("you haven't done Mobility Reset in three weeks — drop or revive?"), and "what should I do today" all require *when*, not just *how many*.

- Amends SPEC-agent-bridge D2's field list and softens its §3 non-goal wording from "read-only counts" to "read-only counts and per-routine recency" — still deliberately short of a session-history export; per-session records, durations, and streak data stay out.
- `plugin/schema/manifest.schema.json` adds the field and advances the manifest `schemaVersion` to 3 while command envelopes remain v2. Implementation review found that the published routine schema uses `additionalProperties: false`, so a new field is not backward-compatible for strict validators even when optional. `plugin/schema/manifest-v2.schema.json` preserves the prior contract; app encoding, both schema versions, and contract tests land together so they cannot drift (bridge §7).
- Rejected: exposing streak/weekly-minutes aggregates in the manifest (derivable app-side stats, PRD §7 owns their presentation; the coach doesn't need them to program), and per-focus-area volume summaries (the agent can derive these from the routines + weekday schedules it already has).

### D8 — Packaging and triggering

Bridge D7's layout stands: one shared instruction source, two thin SKILL.md wrappers. Both wrappers' front-matter `description` fields are rewritten so the skill triggers on coaching intents, not just bridge mechanics — e.g., asking for a routine or plan for a goal, "act as my fitness coach", "set up my week in StepBack" — while keeping the existing create/edit trigger language. The persona and workflow live only in the shared file so the Claude and Codex packages cannot diverge. `plugin/README.md` gains a short "The coach role" paragraph pointing at the shared instructions, keeping the README the protocol contract and the instructions the conduct contract.

## 5. Edge cases

- **Empty app state (fresh install):** no routines/plans in the manifest; the coach runs full intake and starts from catalog only. It must not invent prior usage.
- **User refuses intake:** proceed with beginner-conservative defaults, state assumptions in the proposal, invite corrections (D3).
- **Requirement needs equipment StepBack can't represent:** honest substitute flow per D5; never silently swap.
- **Requested outcome implies deletion** (e.g., "replace my old plan"): content replacement via update verbs where possible; actual object removal escalates to the human in-app, per bridge G3 — the coach explains the distinction.
- **Activating a new plan while another is My Week:** `activatePlan` follows My Week exclusivity exactly (bridge D4); the coach must tell the user the current My Week selection will be replaced before asking approval.
- **Time budget too small for the stated goal:** the coach says so plainly and proposes the best honest use of the time, rather than cramming a degraded program that fits on paper only.
- **`lastCompletedAt` null everywhere but session counts positive:** counts include abandoned sessions; the coach treats only completed sessions as training history (mirrors PRD §7 honest-stats rule).
- **User reports pain mid-plan:** D6 escalation; any resulting program change still goes through normal proposal + approval.
- **Manifest missing or bridge disabled:** unchanged bridge behavior — ask the human to open StepBack / enable Agent Access, and stop.
- **Very long conversations drifting from an old manifest:** the coach re-reads the manifest immediately before each proposal round, not once per session (tightens bridge D2's "fresh" into a per-proposal obligation).

## 6. Accessibility & localization

No app UI changes and no new user-facing strings — the coach's surface is the agent conversation, and PRD §3.1's catalog obligation applies to app strings only. `lastCompletedAt` is a machine field (never localized; agents present dates conversationally). The existing `detail.provenance.agent` caption already covers coach-made edits.

| Key | Value | Notes |
|---|---|---|
| — | — | No new string-catalog keys |

No new accessibility identifiers; no Dynamic Type impact.

## 7. Test impact

- **App unit (`make test-app-unit`)**: manifest generation includes `lastCompletedAt` — null for a never-completed routine, the latest completed session's end date when populated, and ignoring abandoned sessions; manifest still validates against the updated `plugin/schema/manifest.schema.json` (existing `AgentBridgePluginContractTests` extended, not duplicated).
- **Core (`make test-core`)**: none — no pure-logic change.
- **UI lanes**: none — no rendered-UI change; iPhone/iPad/Mac suites pass unchanged.
- **Plugin fixtures**: the schema change updates any manifest fixture; command fixtures are untouched (no envelope change).
- Skill instruction content is verified by review against this spec, not by automated test — there is no executable to test (bridge §7 fixtures already pin the protocol side).

## 8. Acceptance criteria

1. `plugin/shared/stepback-coach-instructions.md` contains the persona block (D2), the intake protocol (D3), the programming-defaults section (D4), catalog-first rules (D5), and the safety envelope (D6), while retaining every existing bridge-safety obligation verbatim (manifest-first, approval-before-write, inbox-only writes, truthful outcomes, deletion escalation).
2. Both SKILL.md wrappers still point at the single shared file and their descriptions trigger on coaching intents (D8); the Claude and Codex packages contain no divergent instruction content.
3. The manifest emits `lastCompletedAt` per routine per D7, validates against manifest schema v3, preserves the v2 schema for older clients, and keeps command envelopes at schema v2, with the app-unit coverage in §7 green.
4. SPEC-agent-bridge.md's D2 field list and §3 non-goal wording are amended, and AGENTS.md names the coach role — in the same implementation commit.
5. No new verbs, no command-schema change, no app UI change, no new user-facing strings.
6. `make test-core` and `make test-app-unit` pass; no UI lane is dispatched (nothing rendered changed).
