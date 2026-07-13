# StepBack testing strategy

This document expands the mandatory testing ladder in `CLAUDE.md`. Its purpose is to keep feedback fast, make evidence proportional to the change, and prevent UI automation—especially the native Mac suite—from becoming the default debugging tool.

## Choose the lowest sufficient layer

| Change or question | First proof | Escalate only when |
|---|---|---|
| Timeline, catalog decoding, formatting, derived stats | `make test-core` | App integration is involved |
| SwiftData models, builder save logic, routing state, source/catalog scans | `make test-app-unit` | Rendering or lifecycle behavior is involved |
| One iPhone interaction or accessibility finding | `make test-focus-iphone TEST=<target/class[/method]>` | The focused test is green and the branch is ready to close |
| One iPad interaction or accessibility finding | `make test-focus-ipad TEST=<target/class[/method]>` | The focused test is green and the branch is ready to close |
| One native Mac window, sheet, menu, keyboard, or accessibility behavior | Manual hosted workflow with an exact `test_filter` | The focused hosted method is green and the branch is ready to close |
| Release/milestone closeout | Full affected lanes once | Production code changes after the receipt |

For iPhone/iPad, `TEST` accepts an XCTest target, class, or method path. For Mac, pass the same exact path as the manual workflow's `test_filter`; do not occupy the owner's desktop unless they explicitly request the local fallback.

## Failure protocol

1. Record the failing class/method and exact assertion from the full-lane receipt.
2. Stop running the full lane.
3. Reproduce with a headless/unit target locally when possible. If rendered Mac interaction is irreducible, dispatch only the failing Mac UI method on the hosted runner.
4. Move the defect into headless core/app unit coverage whenever the behavior can be represented without UI. Saving, selection IDs, route decisions, formatting, and persistence transformations belong here.
5. Keep focused UI coverage only for behavior that cannot be proven headlessly: rendered pixels, accessibility audits, focus/hit-testing, lifecycle transitions, sheets, menus, keyboard input, and native windows.
6. After the focused failure passes and implementation is otherwise complete, run the full affected lane once as the closing receipt. For Mac, this is a separate manual hosted functional dispatch.

Do not rerun unaffected platforms merely because one lane failed. Do not run full iPhone, iPad, and Mac UI suites in parallel on the owner's workstation.

## Native Mac boundary

Native window restoration, activation, sheets, and XCUI accessibility snapshots make Mac UI automation the slowest and most disruptive lane. It runs on GitHub-hosted Macs by default so it does not take over the owner's desktop.

During diagnosis:

- Run project generation, builds, core tests, app unit tests, and all other non-UI checks locally.
- Use the manual hosted workflow with an exact method filter for one irreducible native interaction.
- If a full Mac run exposes one failure, do not rerun all Mac tests. Diagnose locally, change code/configuration, then run only that hosted method.
- Run the full hosted functional lane no more than once per closeout attempt. A rerun requires a relevant change or the one permitted fresh-runner initialization retry.
- `make test-focus-mac` and `make test-mac` are local closing gates when the machine is available; do not use them as repeated diagnostic loops.

## GitHub-hosted native Mac lane

`.github/workflows/macos-ui.yml` is manual-only. It runs on GitHub's `macos-26` image with Xcode 26.5 selected explicitly, regenerates the project, rejects drift, disables signing only for the CI invocation, and relies on the existing XCTest in-memory SwiftData/CloudKit-off seam. Push and pull-request triggers are forbidden because hosted Mac minutes are limited.

Each dispatch selects exactly one check; there is intentionally no “both” option:

- **macOS Functional UI** runs `StepBackMacUITests/StepBackMacUITests`. Because the workflow is manual-only, dispatch it intentionally on the exact PR head only when the change is ready for its merge receipt.
- **macOS Accessibility Diagnostic** runs `StepBackMacUITests/StepBackMacAccessibilityAuditTests` with non-blocking job failure while the repository's known accessibility baseline is open.

Every attempt uploads its raw `xcodebuild` log, `.xcresult` bundle, result summary, and step-observed usage estimate for 14 days. A failed assertion returns to local non-UI diagnosis, followed by at most one exact hosted method when interaction is irreducible. A pre-assertion automation-initialization failure gets one manual retry on a fresh hosted runner; two matching failures are recorded as a hosted-runner blocker rather than triggering repeated CI runs or a self-hosted fallback.

Before dispatch, confirm the run is necessary, choose one suite, and provide a reason. After the workflow lands on the default branch:

```sh
gh workflow run macos-ui.yml --ref <branch> \
  -f suite=functional \
  -f reason='<why native Mac UI automation is required>' \
  -f test_filter=StepBackMacUITests/StepBackMacUITests/<method>
```

Omit `test_filter` only for an intentional full-suite closing receipt. Use `suite=accessibility` only when collecting or verifying accessibility evidence. Find runs with `gh run list --workflow macos-ui.yml` and retrieve evidence with `gh run download <run-id>`.

After every run, retain the job URL and use GitHub's `started_at` and `completed_at` timestamps in the task's verification notes. Round each job up to the next minute and sum jobs separately even if they ran concurrently. Do not trust a zero from the billing timing API as proof that no quota was consumed.

## Process ownership

Before UI automation, state which focused or full lane is being started and why. Keep the run attached to the active task. When work is paused, handed off, or the owner asks to stop, terminate the active test/build/app processes and verify no matching process remains.
