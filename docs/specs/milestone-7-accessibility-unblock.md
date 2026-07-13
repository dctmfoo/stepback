# Spec: Milestone 7 accessibility unblock

**Status:** Implemented — iPhone/iPad strict lanes green; Mac closeout blocked before execution by UI-automation initialization
**Owner screens:** `StepBack/Features/Builder/`, `Gallery/`, `Onboarding/`, `Player/`, `Routines/`, `Settings/`, and `Shared/`; `StepBackUITests/StepBackAccessibilityAuditTests.swift`; `StepBackMacUITests/StepBackMacAccessibilityAuditTests.swift`
**Docs this spec amends:** `DESIGN.md`, `design/ui-spec.html`, `CLAUDE.md`, and `docs/verification/v1-acceptance.md`

**Branch:** `codex/milestone-7-accessibility-unblock`
**Parent evidence:** `docs/verification/v1-acceptance.md` on `0274817`

## 1. Problem

Milestone 7's automated accessibility audits execute, but the first evidence run found a mixture of real StepBack defects and XCTest findings produced by system-owned controls. The audit suite is quarantined with non-strict `XCTExpectFailure`, so acceptance criterion 11 cannot pass.

Structured reruns on 2026-07-10 established four causes:

1. Routine titles are forcibly single-line and several accessibility-size surfaces retain compact geometry.
2. Category hues, Recover Mint, and `secondaryLabel` are used as small text foregrounds even where XCTest measures insufficient contrast.
3. The always-dark stage reuses appearance-adaptive Pulse Azure/Recover Mint, receiving deep light variants instead of luminous stage variants in system light mode.
4. Native Mac audits mix system `NavigationSplitView`, `ContentUnavailableView`, sidebar-selection, Touch Bar, and empty framework containers with app-created rows and stage semantics.

## 2. Goals

- Remove every app-owned contrast, clipping, role, and description failure from the strict iPhone, iPad, and Mac audits.
- Replace the broad expected-failure quarantine with narrowly named, evidence-backed filters.
- Prove primary flows at AX-XXL independently of XCTest's predictive Dynamic Type warnings.
- Preserve the existing product behavior, hierarchy, and platform-native layout.

## 3. Non-goals

- No new product feature, user flow, workout content, or user-facing copy.
- No new Dynamic Type exception beyond the documented stage countdown.
- No blanket exemption for app-owned Mac findings; system-owned false positives require structured evidence.
- No redesign outside the minimum changes needed to satisfy the governing PRD, DESIGN, and UI specification.

## 4. Design decisions

- **D1 — Text contrast:** category and rest hues remain identity accents on symbols, progress, and soft fills; readable text on those surfaces uses the semantic primary label. Small secondary metadata uses appearance-paired `SecondaryText` values (`#333338` light, `#EBEBF0` dark) with enhanced contrast on grouped backgrounds; font size and weight preserve hierarchy. `StageTextDim` uses 80% opacity and also remains at least 7:1 on StageCanvas. Rejected: flattening all text to primary, which would erase the established hierarchy.
- **D2 — Stage accents:** add appearance-invariant `StageWork` (`#46A2FF`, 7.20:1 on StageCanvas) and `StageRest` (`#3BD6C3`) assets and use them for stage kickers, progress, and controls. Browsing surfaces continue using adaptive Pulse Azure/Recover Mint. Rejected: forcing a color-scheme branch in feature code.
- **D3 — Flexible layouts:** routine names wrap; accessibility Dynamic Type uses the single-column/large-sheet builder picker; fixed or minimum-scale text is removed outside the documented countdown exception. Rejected: device-type branches or truncation to preserve compact geometry.
- **D4 — Semantics:** combined routine/rest rows receive the static-text trait. The real player-stage container owns `player.stage`; the synthetic 1×1 accessibility element is removed. Rejected: test-only sentinel elements that can pass while the real stage lacks semantics.
- **D5 — Evidence-backed audit policy:** remove the broad expected-failure quarantine. Keep only the `player.countdown` design exception. Additional filters may cover only findings proven non-actionable: exact disabled Save/Add contrast; predictive clipping warnings and exact logged SwiftUI semantic-font Dynamic Type signatures paired with actual visible-text clipping audits at AX-XXL on every required surface; the native searchable field's AX-XXL crop report, constrained to `.searchField`; issues for which XCTest supplies no element; pixel audits wholly outside the app window or wholly contained by identified native chrome; labels outside their identified picker viewport; exact semantic-child crops contained by identified controls/cards/section headers; exact native tab/sidebar controls; SwiftUI's full-width combined iCloud Form node after its rendered text and icon are explicitly primary; noninteractive native-Mac framework containers constrained by element type plus empty metadata; Touch Bar; and the native Mac get-ready pop-up's missing-action report only when the same test directly opens its menu. Arbitrary overlap with chrome/trays, all-disabled-control filtering, blanket Dynamic Type filtering, and empty-label-only Mac filtering are prohibited.
- **D6 — Independent Dynamic Type proof:** add an AX-XXL UI walk covering Routines, detail, Gallery, builder/picker, Settings, welcome, and player work/rest. Assert representative labels remain present at accessibility size and primary actions stay reachable and hittable.

## 5. Edge cases

- Partially visible horizontal chips and rows under the fixed picker tray remain in the accessibility tree; ignore pixel findings only when their frames are outside their identified scroll viewport.
- Disabled Save/Add controls may legitimately fail pixel contrast; the same identifiers must not be exempt once enabled.
- Offscreen semantic findings such as missing roles or actions remain actionable; only pixel-dependent contrast/clipping findings depend on rendered visibility.
- Native Mac window restoration can launch without a visible window; focused tests may recover through File > New Window, but recovery must not hide app termination or assertion failures.
- App-owned Mac nodes must not be classified as unnamed framework containers solely because their identifier is empty.

## 6. Accessibility & localization

- New color assets: `SecondaryText`, `StageWork`, and `StageRest`; no new localized strings. Contrast regression tests lock the `SecondaryText` pair and `StageTextDim` to at least 7:1 on their governing surfaces.
- Restored identifier: `player.stage` belongs to the real stage container and must not hide its child controls.
- Audit-scoping identifiers: `builder.name.label`, `builder.empty`, `welcome.tagline`, `welcome.compose`, `welcome.play`, `welcome.follow`, and `welcome.privacy`. These identify app-owned semantic nodes without changing visible copy.
- New test-only identifiers may name picker scroll viewports and their labels so clipped-pixel evidence is scoped to the correct container.
- VoiceOver grouping remains unchanged except for adding the static-text trait to combined routine and rest rows.
- AX-XXL must keep Routines, detail, Gallery, builder/picker, Settings, welcome, and player work/rest usable.

## 7. Test impact

- Remove `XCTExpectFailure` from iPhone/iPad and Mac accessibility audits.
- Add strict screen coverage and an AX-XXL functional walk to `StepBackAccessibilityAuditTests`.
- Keep Mac system-control exemptions narrow and preserve structured `AX_AUDIT` diagnostics.
- Run focused strict accessibility classes while repairing findings, then the full iPhone, iPad, and Mac regression lanes once at closeout.
- Physical iPhone/iPad dark-mode and VoiceOver checks remain acceptance evidence, not substitutes for automated audits.

## 8. Acceptance criteria

1. No app-owned contrast, clipping, missing-role, or missing-description finding remains.
2. Every audit filter is named, narrowly coded, and justified by structured issue evidence.
3. The real player stage exposes `player.stage` without hiding `player.playPause` or other child controls.
4. The AX-XXL walk covers Routines, detail, Gallery, builder/picker, Settings, welcome, and player work/rest.
5. Strict iPhone, iPad, and Mac accessibility tests pass without `XCTExpectFailure`; existing regression lanes remain green.
6. `docs/verification/v1-acceptance.md` records the new build and moves criterion 11 only as far as automated and owner-visible evidence supports.
