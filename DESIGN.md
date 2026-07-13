---
# ============================================================
# DESIGN.md — StepBack (iPadOS/iOS/macOS 26, SwiftUI)
# Machine-readable design tokens. The markdown body below
# explains how and why to apply them. Agents: read both.
# Sources: design/ui-spec.html (canonical mockups) + PRD.md v1.0
# ============================================================
name: StepBack
platform: iPadOS + iOS + macOS (iPad-first)
minimum_os: "26.0"
ui_framework: SwiftUI
design_language: "Apple Liquid Glass (OS 26) — content-first, system components; the live player is a dark stage in both appearances"

colors:
  # Every custom token is a light/dark PAIR — one asset-catalog color set
  # (Any + Dark appearances) per token. Code references the named color only.
  brand:
    pulse_azure:      { light: "#0B63E5", dark: "#3D9BFF" }            # The single browsing accent: Play, selection, active tab, links.
    pulse_azure_soft: { light: "#E8F0FD", dark: "rgba(61,155,255,0.16)" } # Selected-chip fill, onboarding icon tiles, quiet accent surfaces.
  player_states:                     # Functional hues — segment identity in the player only. Never decorative elsewhere.
    work: stage_work                 # Work segments use the appearance-invariant stage accent. One meaning: effort.
    recover_mint:     { light: "#0E9F8E", dark: "#3BD6C3" }            # Rest, set-rest, and get-ready segments. One meaning: breathe.
    recover_mint_soft: { light: "#E6F4F1", dark: "rgba(59,214,195,0.14)" }
  stage:                             # The player is ALWAYS dark — its own token set, not colorScheme-driven.
    stage_canvas:     { any: "#0B0F14" }   # Near-black blue-cast canvas; identical in light and dark system appearance.
    stage_surface:    { any: "#161C24" }   # Cards/controls on the stage.
    stage_text:       { any: "#F5F7FA" }
    stage_text_dim:   { any: "rgba(245,247,250,0.80)" }
    stage_work:       { any: "#46A2FF" }   # Appearance-invariant work accent; 7.20:1 on StageCanvas.
    stage_rest:       { any: "#3BD6C3" }   # Appearance-invariant luminous rest accent.
  category_palette:                  # Category identity hues. Symbols belong to categories, not hues. Soft-tile use only.
    full_body:       { id: full-body,       light: "#5856D6", dark: "#5E5CE6", system: systemIndigo }
    core:            { id: core,            light: "#FF9500", dark: "#FF9F0A", system: systemOrange }
    arms_shoulders:  { id: arms-shoulders,  light: "#AF52DE", dark: "#BF5AF2", system: systemPurple }
    chest_back:      { id: chest-back,      light: "#1E96D1", dark: "#4CC2FF", system: systemCyan }
    legs_glutes:     { id: legs-glutes,     light: "#96419B", dark: "#D678DB", system: systemPurple }
    cardio:          { id: cardio,          light: "#B26B00", dark: "#E5A421", system: systemYellow }
    mobility_stretch:{ id: mobility-stretch,light: "#5D6B85", dark: "#93A2C0", system: systemBlue }
    balance:         { id: balance,         light: "#A2845E", dark: "#AC8E68", system: systemBrown }
  semantic:                          # Always the SwiftUI semantic color, never hex — these adapt to dark automatically.
    background: systemGroupedBackground
    surface: secondarySystemGroupedBackground
    label: label
    secondary_label: secondaryLabel
    accessible_secondary_text: { light: "#333338", dark: "#EBEBF0" } # Small app-owned metadata; enhanced contrast on grouped surfaces.
    separator: separator
    fill: systemFill
  rules:
    no_red: "No red anywhere except the system destructive role on explicit delete actions. Effort is azure, never alarm-colored."
    accent_discipline: "Pulse Azure is the only brand accent in app chrome. Category hues mean category identity only; RecoverMint means rest only."
    dark_mode: "Token problem, not layout problem — nothing moves or reflows in dark. No raw hex and no colorScheme branches in feature code. The stage tokens are appearance-invariant by design, which is exactly why they are their own set."

category_symbols:                    # SF Symbols validated against minimum OS; fallback figure.strengthtraining.functional
  full-body:        figure.mixed.cardio
  core:             figure.core.training
  arms-shoulders:   dumbbell.fill
  chest-back:       figure.strengthtraining.traditional
  legs-glutes:      figure.squat
  cardio:           figure.run
  mobility-stretch: figure.flexibility
  balance:          figure.yoga

typography:
  family: "SF Pro (system default). SF Pro Rounded for stat and stage numerals only. No custom fonts."
  rule: "Dynamic Type text styles only — with exactly one documented exception: stage numerals (below)."
  roles:                             # Five Dynamic Type roles + one stage exception. Do not add more.
    large_title:  { style: largeTitle, weight: bold, size_ref: 34 }
    hero_stat:    { style: title1-adjacent, weight: semibold, design: rounded, size_ref: 31, numerals: tabular }   # One per screen: routine total duration, completion minutes.
    body:         { style: body/subheadline, weight: regular–medium, size_ref: "17/15" }
    footnote:     { style: footnote, weight: regular, size_ref: 13 }
    caption_label:{ style: caption, weight: semibold, size_ref: 11, transform: uppercase }
  stage_numerals:
    definition: "The player countdown: SF Pro Rounded, heavy, monospacedDigit, scaled to the stage viewport (≥ 25% of stage height on iPad landscape), NOT Dynamic Type."
    rationale: "Across-the-room legibility is the product promise (PRD §0.4); a 3–4 m viewing distance is outside Dynamic Type's design range. This is the app's single fixed-size exception and it may only be used on the player stage."
    accessibility: "All other player text (workout name, set indicator, next-up) remains Dynamic Type; at accessibility sizes the stage stacks vertically and the countdown yields height before any label truncates."
  numerals: "All durations and counts tabular (monospacedDigit) so times align in every list."

spacing:
  grid: 4                            # base-4/8 grid
  content_margin: { compact: 16, regular: 24 }
  card_padding: "12–16"
  section_gap: 24
  ipad_columns: "Gallery and Routines use adaptive multi-column grids in regular width; never a stretched single column."

shape:
  radius_scale: { tile_small: 10, tile_medium: 16, tile_large: 20, card: 16, inset_row: 12, card_prominent: 18 }
  rule: "Custom radii resolve through the named scale; nested rounded content uses concentric corners relative to a declared container."
  containers: "Top-level custom cards and standalone workout tiles use the named fixed radius token for their surface family."
  nested: "Inset editor panels and tray tiles declare a container shape, then use ConcentricRectangle / .concentric(minimum:) for inner fills and strokes."
  never: "Hand-tuned per-view corner radii."

elevation:
  glass_budget:
    system_owned: "Tab bar, toolbars, sheets, menus — always system material, no custom bar backgrounds."
    custom_allowed: ["player control bar (on the stage)", "builder floating Add-Workouts/total bar"]
  shadows: "System defaults only; no decorative drop shadows."

across_the_room:                     # The signature ruleset. Applies to the player stage only.
  viewing_distance: "Everything needed to FOLLOW the routine must be unmistakable at 3–4 m on an 11″ iPad in landscape."
  hero: "Exactly one hero: the countdown (stage numerals above). Nothing else on the stage competes in size."
  state_identity: "Work vs rest is encoded twice — segment hue (StageWork vs StageRest) AND layout (work leads with the countdown; rest leads with the next workout name). Never hue alone."
  minimums: "Workout name ≥ title-scale; set indicator and next-up ≥ headline-scale; overall progress bar full-width, ≥ 6pt tall; stage text contrast ≥ 7:1 on StageCanvas."
  verification: "Before calling player UI done: 3 m test in a lit room and a dim room, both segment types, on iPad landscape + portrait and iPhone."

media_readiness:                     # PRD §4.7 — v1 is name-only, layouts reserve media slots.
  component: "WorkoutVisual — the ONLY way any screen renders a workout's visual identity."
  placeholder: "Monogram tile: category-hue soft fill, category SF Symbol, concentric radius. Same tile family at every size."
  slots: { gallery_card: "1:1", workout_detail: "4:3", builder_row: "1:1 small", stage: "4:3 region beside/below the countdown (landscape/portrait)" }
  later: "Photos/video loops drop into the same slots via mediaKey; screens must not reflow when media arrives."

haptics:
  routine_saved: .success
  session_complete: .success
  picker_selection: .selection
  player_transitions: "None — the device is across the room; sound is the channel (PRD §6.4)."

motion:
  segment_transition: "Crossfade + slight scale settle, ≤ 300 ms; the stage never hard-cuts."
  final_countdown: "Last 3 s of every segment: numeral pulse synced to the beeps."
  completion: "One calm celebratory settle (hero minutes counting up ≤ 800 ms). No confetti, no particles."
  reduced_motion: "All of the above become opacity-only fades; the beeps carry the final-countdown emphasis."

accessibility:
  dynamic_type: "Required everywhere; stage numerals are the sole documented exception."
  dark_mode: "Required. Semantic colors adapt free; custom tokens carry Dark variants via asset catalog; the stage is appearance-invariant."
  voiceover: "Every control labeled; build → play → complete completable end-to-end. Player announces segment changes via accessibility notifications mirroring the audio cues."
  rtl: "Leading/trailing only, never left/right."
---

# StepBack — Design System

**Who reads this:** any agent or engineer generating UI for this app. `PRD.md` defines
*what* to build; this file defines *how it must look and feel*. The screen-by-screen
canonical mockups live in [design/ui-spec.html](design/ui-spec.html) — when in doubt,
that file wins on layout, this file wins on tokens and rules.

---

## 1. Visual Theme & Atmosphere

**The wall-side stage.** StepBack has two moods, deliberately distinct:

- **Browsing surfaces** (Routines, Gallery, Builder, Settings) are calm, light-filled,
  native OS 26 — inset-grouped lists and adaptive grids, semantic backgrounds, quiet
  chrome. Composing a routine should feel like arranging index cards, not programming
  a timer.
- **The player is a stage.** The moment Play is tapped the app goes full-screen onto a
  near-black canvas (`StageCanvas`) that is identical in light and dark system
  appearance — the same convention as video players and the same reasoning as
  Intelli-Expense's dark-first processing screen: the content (a giant countdown and a
  workout name read from across the room) owns the frame, and a wall-propped iPad must
  not glow like a lamp in a dim room or wash out in a bright one.

The energy comes from **one electric hue doing one job** (Pulse Azure = effort), a calm
counterpart (Recover Mint = breathe), and huge rounded numerals — not from gradients,
photography of models, or promotional noise. The inspiration screenshots' discipline
(dark stage, blue accent, oversized type) is kept; their ad-cluttered, upsell-heavy
surfaces are explicitly rejected.

## 2. Color Palette & Roles

| Token | Light | Dark | Role |
|---|---|---|---|
| Pulse Azure | `#0B63E5` | `#3D9BFF` | The single browsing accent: Play, selection, active tab, and links. |
| Pulse Azure Soft | `#E8F0FD` | `rgba(61,155,255,.16)` | Selected-chip fill, icon tiles, quiet accent surfaces. |
| Recover Mint | `#0E9F8E` | `#3BD6C3` | Rest / set-rest / get-ready segments only. The exhale to Azure's inhale. |
| Recover Mint Soft | `#E6F4F1` | `rgba(59,214,195,.14)` | Rest-adjacent soft fills (builder rest rows, rest chips). |
| Stage Canvas | `#0B0F14` | (same) | Player background in both appearances. |
| Stage Surface | `#161C24` | (same) | Player control bar and cards on the stage. |
| Stage Text / Dim | `#F5F7FA` / 80% | (same) | Player text hierarchy; at least 7:1 on Stage Canvas. |
| Stage Work | `#46A2FF` | (same) | Appearance-invariant work kicker, progress, and controls on Stage Canvas. |
| Stage Rest | `#3BD6C3` | (same) | Appearance-invariant rest kicker, progress, and controls on Stage Canvas. |
| Category: Full Body | `#5856D6` | `#5E5CE6` | Category identity (indigo). |
| Category: Core | `#FF9500` | `#FF9F0A` | Category identity (orange). |
| Category: Arms & Shoulders | `#AF52DE` | `#BF5AF2` | Category identity (purple). |
| Category: Chest & Back | `#1E96D1` | `#4CC2FF` | Category identity (cyan). |
| Category: Legs & Glutes | `#96419B` | `#D678DB` | Category identity (plum — purple-side, never pink/red). |
| Category: Cardio | `#B26B00` | `#E5A421` | Category identity (amber). |
| Category: Mobility & Stretch | `#5D6B85` | `#93A2C0` | Category identity (slate). |
| Category: Balance | `#A2845E` | `#AC8E68` | Category identity (brown). |
| Secondary Text | `#333338` | `#EBEBF0` | Small app-owned metadata; enhanced contrast on grouped surfaces while size and weight preserve hierarchy. |
| Everything else | Semantic system colors | (adapt automatically) | `systemGroupedBackground`, `label`, `separator`, `systemFill`; app-owned small metadata uses `SecondaryText` when `secondaryLabel` misses 7:1. |

**Hard rules:**

- **One accent.** Pulse Azure is the only brand accent in app chrome — tint, Play
  buttons, selection, active tab. `AccentColor` in the asset catalog byte-matches
  `PulseAzure`; it is an alias, not a second token.
- **Functional hues are contracts.** Recover Mint appears only where the meaning is
  "rest/breathe"; category hues appear only as category identity on soft fills,
  borders, and glyphs — readable text on those surfaces remains `label`. Users
  never pick colors; there is no color picker.
- **Mint is not a category.** Recover Mint was deliberately removed from the category
  palette so rest can own it unambiguously.
- **No red.** Effort, urgency, and the final countdown are azure + motion + sound —
  never red. The only red in the app is the system destructive role on explicit
  Delete actions. This is a fitness app that never alarms.
- **Semantic colors are the default, not a contrast waiver.** System-owned controls
  keep semantic colors. App-owned small metadata uses the named `SecondaryText`
  pair when `secondaryLabel` measures below 7:1; raw feature-code hex remains a defect.

### Dark mode

Dark mode is a **token problem, not a layout problem** — nothing moves or reflows.

- **Semantic first.** Browsing surfaces adapt automatically: true-black grouped
  canvas, `#1C1C1E` cards, elevation through surface.
- **Every custom pair defined once** as an asset-catalog color set with Any + Dark
  appearances. Feature code references the named color; `colorScheme` branches and
  raw hex are both defects.
- **The stage does not participate.** Stage tokens are appearance-invariant single
  values — the player looks identical at noon and midnight, which is the point. This
  is implemented as its own token set, *not* as a forced-dark color scheme override
  hack on system colors.
- Custom hues brighten the way Apple's do: deep pigment on white, luminous on black.
  Identity never changes.

## 3. Typography

SF Pro via Dynamic Type text styles — **never fixed point sizes in code** — with
exactly one documented exception. Five roles plus the exception:

| Role | Ref size / weight | Used for |
|---|---|---|
| Large title | 34 bold | Tab root titles (Routines, Gallery, Settings) |
| Hero stat | ~31 semibold **rounded**, tabular | The one big number per screen: routine total duration, completion minutes |
| Body | 17/15 regular–medium | Row titles, step summaries, field values |
| Footnote | 13 | Row subtitles, stats lines ("Last done 2 days ago · 14×") |
| Caption label | 11 semibold UPPERCASE | Form labels, section kickers, set indicators in lists |
| **Stage numerals** | viewport-scaled, SF Pro Rounded heavy, tabular | **Player countdown only.** ≥ 25% of stage height on iPad landscape. The single Dynamic Type exception — rationale and AX behavior in the frontmatter. |

Rounded numerals give the app its athletic voice; weight and color carry hierarchy,
size stays disciplined. All numerals tabular so durations align down every list.

## 4. Components

- **Routine card (home):** name, hero-stat duration, workout count + category-mix
  glyph row (small hue dots/symbols, non-interactive), stats footnote ("Last done
  2 days ago · 14×"), and an inline circular **Play** button in Pulse Azure — the
  one-tap-from-launch promise. Most recently played first. A routine with no
  sessions uses the same footnote slot for the honest line **"Not played yet"**.
  When a Today card is present, routine-card durations step down to title2 bold so
  the Today duration remains the screen's one hero number.
- **Motivation strip:** one compact row above the routine list — day streak and this
  week's active minutes as two quiet stat pairs. It appears only after the first
  session exists; before then, it is omitted rather than showing zeroes. Not a card,
  not a chart, no rings.
- **Today plan card (home):** one prominent 18 pt-radius grouped-surface card above
  the motivation strip. Caption-level Pulse Azure "TODAY · WEDNESDAY", routine name,
  compiled hero duration, and a seven-day schedule strip form one descriptive group;
  Play is the sole action. Done goes quiet with a check and the completed routine name.
  Rest uses a Recover Mint Soft icon tile and the next planned day as a footnote.
  Removed routines replace Play with Fix in Editor. At AX3+ the strip becomes its
  summary text. This is a standard surface, never a third custom glass element.
- **Plan overview and picker:** the overview is an inset-grouped list of seven
  locale-ordered day rows. Today's row uses Pulse Azure; completed planned days use
  checks; empty days read Rest; removed routines retain their snapshot with a
  secondary "Routine removed" label. The plain multi-plan picker shows name, a quiet
  week summary, and a My Week badge; selection happens on overview via Set as My Week.
- **Plan editor:** a system List/Form sheet with seven fixed weekday sections in
  locale order. Each section contains reorderable routine rows, replace/delete
  actions, Add Routine, and a visible quiet Rest state when empty. There are no week,
  repeat, cursor, weekday-label-menu, Skip, or completion controls.
- **Gallery card:** the `WorkoutVisual` monogram tile (1:1, category-hue soft fill,
  category SF Symbol) + workout name + optional focus-area caption. Custom workouts
  carry a small "Yours" caption, never a different card shape.
- **WorkoutVisual (media-ready contract):** the *only* component that renders a
  workout's visual identity, at every size (gallery card, detail header, builder row,
  player stage region). Today it renders the monogram tile; when media ships it
  renders the photo/video in the same slot. Screens never reflow when media arrives
  (PRD §4.7).
- **Builder step row:** drag handle · `WorkoutVisual` small tile · workout name ·
  timing summary in footnote ("30 s × 3 · 10 s between sets" + optional "~20 reps") ·
  disclosure to expand inline duration/sets/rest controls (steppers and wheels in 5 s
  increments — never free-text seconds).
- **Rest row (builder):** rest-after renders *between* step rows as its own quiet
  Recover-Mint-soft row ("Rest · 15 s") so the list reads exactly like the routine
  will play. Tappable to adjust; travels with the step above it on reorder.
- **Builder floating bar:** one of the two custom glass elements — **Add Workouts**
  plus the live computed total duration, always visible while composing.
- **Gallery picker (from builder):** sheet with category chips + search + multi-select;
  selected workouts collect into a visible tray; one Add button commits them all with
  smart defaults (PRD §5.4).
- **Stage — work segment:** countdown as the single hero, workout name below it,
  set indicator ("Set 2 of 3") and optional rep guidance in stage-dim text, the
  `WorkoutVisual` region beside (landscape) or below (portrait) the countdown, and a
  full-width thin progress bar with elapsed/remaining at the stage foot. Segment hue:
  Stage Work (progress ring/bar, accents — never a full-canvas flood).
- **Stage — rest segment:** layout inverts — "Next: Squats" leads at title scale with
  its `WorkoutVisual`, the rest countdown is large but secondary, hue shifts to
  Stage Rest. Work and rest are distinguishable by layout *and* hue, never hue alone.
- **Stage control bar:** the other custom glass element (on StageSurface): back ·
  pause/resume (largest) · skip · end. Oversized targets (≥ 64 pt) — operated at
  arm's length in motion. On Mac, keyboard: space pause, arrows skip/back, ⎋ end.
- **Completion view:** hero-stat active minutes counting up once, routine name,
  workouts completed, updated streak/times-completed line, **Done** + **Go again**.
  Partial sessions get a smaller honest acknowledgment — never a guilt trip.
- **Empty states:** `ContentUnavailableView`-shaped — icon tile, one-line title,
  short guidance, one primary action. Never a blank list.
- **Agent Access (Mac Settings):** one standard grouped section after iCloud with
  a system Toggle for allowing agent changes, a system folder-reveal Button, and a
  factual footer that states the create/edit-only guarantee. This is ordinary Form
  content, never custom glass. Agent-edited routine and plan detail summaries add one
  quiet footnote, “Edited by agent.”
- **Segmented/steppers/pickers:** system controls, system styles, always.

## 5. Layout Principles

- Base-4/8 grid: 16 pt content margins compact / 24 pt regular, 12–16 pt card
  padding, 24 pt between sections.
- Shape uses the named radius scale in `ShapeRadius`: 10 pt small icon tiles,
  16 pt cards and gallery tiles, 20 pt large workout visuals, 12 pt inset rows,
  and 18 pt prominent routine cards. Nested builder editor and picker tray
  content uses concentric corners against an explicit container shape.
- **One hero number per screen:** the countdown on the stage, total duration on
  routine detail, active minutes on completion. Everything else steps down through
  weight and color, not size.
- **iPad-first means multi-column, not magnified:** Gallery and Routines use adaptive
  grids in regular width; the builder pairs the step list with the picker in a
  side-by-side arrangement when width allows; the stage uses landscape as its primary
  composition. iPhone gets the same hierarchy in one column. No device-type branches —
  size classes only.
- Plan surfaces keep the same hierarchy across size classes: the Today name/duration
  use `ViewThatFits`, the week strip collapses to summary text at accessibility sizes,
  and overview/editor/picker use standard list adaptation rather than device branches.
- Standard navigation: three tabs, large titles at roots, inline when pushed; search
  lives in `.searchable` on Gallery.
- Destructive delete never rides a reflex gesture on a routine card; it lives in
  routine detail / context menus with the system destructive role and confirmation.
- RTL-safe by construction: leading/trailing only, SF Symbols, standard stacks.

## 6. Depth, Elevation & Glass

Liquid Glass is rationed (Apple guidance):

- System-owned glass only for bars, sheets, menus — no custom bar backgrounds.
- Exactly **two custom glass elements** in the whole app: the builder's floating
  Add-Workouts/total bar and the stage control bar. Adding a third requires a design
  decision recorded in a spec, not a whim.
- Sheets are system: detents, grabber, content peeking beneath.
- No decorative shadows or gradients anywhere. The stage's drama is type and color,
  not vignettes.

## 7. Motion, Sound & Haptics

- **Sound is the primary feedback channel during play** (the user is across the
  room): voice announcements + 3-2-1 beeps per PRD §6.4. Haptics only where the
  device is in hand: `.success` on save/complete, `.selection` in pickers. No haptics
  on stage transitions.
- Segment transitions crossfade ≤ 300 ms; the final 3 s pulse the numeral in sync
  with the beeps; completion settles once (count-up ≤ 800 ms). Reduce Motion turns
  every one of these into opacity-only fades — the beeps carry the emphasis alone.
- Nothing loops, nothing bounces, nothing celebrates longer than a second.

## 8. Voice & Copy

- Calm, second-person, zero hype: "Next: Squats", "Rest", "Nice work — 24 minutes."
  Never "CRUSH IT", never shame ("You broke your streak" is just a new number).
- Every button says exactly what it does ("Add 4 Workouts", not "Continue").
- Stats copy is factual and relative: "Last done 2 days ago · 14×".
- All strings in the String Catalog, including spoken announcement templates —
  the voice cues are UI (PRD §3.1).

## 9. Do's and Don'ts

**Do**
- Use semantic system colors and Dynamic Type styles by default; use the named
  `SecondaryText` pair for small app-owned metadata and stage tokens for the
  appearance-invariant player. Custom tokens exist only as asset-catalog sets.
- Check every new screen in both appearances — and the stage at 3 m in a lit and a
  dim room — before calling it done.
- Keep durations in integer seconds end-to-end; format with `Duration`/Foundation
  formatters; render tabular.
- Route every workout visual through `WorkoutVisual` (the media-ready contract).
- Design every state: empty, syncing, degraded, interrupted, partial-completion.

**Don't**
- ❌ No charts, rings, dashboards, or badge cabinets — the motivation strip and stats
  lines are the whole surface (PRD non-goal).
- ❌ No red anywhere except the system destructive role on explicit deletes.
- ❌ No custom fonts, no gradients, no photography-of-athletes decoration, no emoji
  in UI, no "AI-slop" layouts.
- ❌ No custom tab/nav bar backgrounds; never fake glass with blur views.
- ❌ No fixed font sizes outside the documented stage-numerals exception; no
  left/right (use leading/trailing); no `colorScheme` branches in feature code.
- ❌ Never let any element on the stage compete with the countdown for hero status.
- ❌ Never require a tap to keep a routine running (PRD §6.1).

## 10. Platform Adaptation (iPhone & Mac)

The iPhone and Mac apps are the same product, not ports.

- **iPhone:** single-column versions of the same hierarchies; the stage in portrait
  leads with the countdown above the `WorkoutVisual` region; controls stay oversized.
- **Mac:** `NavigationSplitView` — sidebar (Routines / Gallery / Settings), content
  column (routine and plan list / gallery grid), detail (routine, plan, or workout detail).
  The stage opens as a full-window scene, resizable, with the same composition rules;
  keyboard controls (space / arrows / ⎋) mirror the stage control bar. Toolbar and
  menu commands for New Routine, Add Workout, Play. Mac-only state stays out of the
  synced data model.
- Size classes and platform idioms drive every difference; there are no
  device-type branches in feature code.

## 11. Agent Prompt Guide

Quick reference when generating any screen:

- Accent = **Pulse Azure** (`#0B63E5` light / `#3D9BFF` dark) for browsing tint,
  Play, and selection. Browsing rest = **Recover Mint**. Stage state accents =
  **Stage Work** / **Stage Rest**, alongside the appearance-invariant dark tokens.
  Category palette = indigo, orange, purple, cyan, plum, amber, slate, brown —
  each category owns one permanent hue + SF Symbol (frontmatter table); every custom
  color is a light/dark asset-catalog pair referenced by name.
- One hero number per screen; hero stats in rounded semibold tabular; stage countdown
  is the single fixed-size exception.
- Inset-grouped lists and adaptive grids, 16/24 pt margins, system radii, glass only
  where §6 allows.
- Work = azure + countdown-led layout; Rest = mint + next-up-led layout. Never hue
  alone. Sound over haptics on the stage.
- Canonical layouts, per screen, are in `design/ui-spec.html`. Match them.

**Example prompt:** *"Build the Routine Detail screen per DESIGN.md: hero-stat total
duration in rounded semibold tabular, step list with rest rows exactly as the routine
plays, stats footnote, one Pulse Azure Play as the primary action, Edit/Duplicate in
the toolbar, per ui-spec.html §Routine detail."*
