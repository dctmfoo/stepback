# Contributing

Thanks for taking an interest in StepBack. The project is pre-1.0 and maintainer-reviewed; opening an issue or pull request does not imply a response time, roadmap commitment, or automatic merge.

## Prerequisites

- macOS with Xcode 26 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.43+
- Your own Apple Developer team for personal-device signing

Simulator builds and deterministic tests do not require a paid Apple Developer account.

## Before changing code

Read `AGENTS.md` and `CLAUDE.md`, then follow the binding product and design contracts in `PRD.md`, `DESIGN.md`, and `design/ui-spec.html`. Feature briefs live in `docs/specs/`. Keep changes within the explicit non-goals and preserve the central product promise: once a routine starts, nothing should require touching the device.

Preserve the privacy and agent-write boundaries: no accounts, analytics, third-party backend, direct external database writes, or delete commands in the Agent Bridge.

## Build and test

Start with the smallest relevant gate and finish with the affected full lane:

```sh
make gen
make test-core
make test-app-unit
make test-app
```

Use `make test-ipad` for iPad UI changes and `make test-mac` for native Mac UI changes. `project.yml` is authoritative; never hand-edit the generated Xcode project.

For a third-party physical-device build, first replace the maintainer's bundle and private CloudKit container identifiers as described in `README.md`. Then copy `Makefile.local.example` to `Makefile.local` and add only your own signing and device values. Never commit that file, provisioning profiles, device identifiers, local filesystem paths, or App Store Connect details.

## Local-only files & guardrails

Some files stay on the maintainer's disk and are never committed: `Makefile.local`
(signing and device identifiers), anything under `private/` (a scratch area for
local notes and fixtures), the local session journals under `sessions/`, and a few
maintainer-only planning documents. They are all listed in `.gitignore`.

After cloning, run:

```sh
scripts/install-guardrails.sh
```

This sets your local commit identity from `~/.config/oss-guard/git-identity` when
that file exists and installs `pre-commit` / `pre-push` hooks that run
[gitleaks](https://github.com/gitleaks/gitleaks) over your changes, block any
force-added ignored file, and refuse commits made under a disallowed identity.
Contributors without the optional config still get gitleaks secret scanning. Please
commit with a GitHub noreply email address, and never commit real signing values,
device identifiers, local filesystem paths, or personal data.

## Pull requests

- Keep each change focused and explain the user-visible value.
- Add or update deterministic tests for behavior changes. Pure timeline, plan, catalog, and stats logic belongs in `StepBackCore` whenever practical.
- Keep durations as integer seconds end to end.
- Put every user-facing and spoken string in the String Catalog; preserve Dynamic Type, VoiceOver, dark mode, and Reduce Motion behavior.
- Route every workout visual through the shared `WorkoutVisual` contract.
- Use synthetic workout and bridge fixtures only; do not submit personal activity history, device identifiers, or health information.
- Update the PRD, design system, canonical UI specification, or feature spec when a product contract changes.
- Confirm the affected test lanes are green and include the verification result.

The maintainer may decline work that expands scope, weakens privacy or accessibility, breaks the hands-free promise, or adds long-term governance cost before 1.0.
