# Korah Design Guide

How Korah should look, move, and feel. Written 2026-07 from the parts of the
app that already get it right. When styling anything new, match these files
before inventing something:

- `Views/SAT/SATRushView.swift`: setup wizard, player, celebration. The
  reference for colorful selectable cards, per-step tints, and the
  check/continue loop.
- `Views/Onboarding/OnboardingView.swift`: the reference for staged
  animations, live demos, and warm copy.
- `Views/Chat/SATChatTheme.swift`: the solid-accent recipe (tint fills,
  colored borders, no gradients on chips).
- `DesignSystem/`: all tokens. Never hardcode a value that has a token.

The three words that describe the target feel: **animated, colorful,
original**. If a screen could pass for a default SwiftUI template, it is not
done yet.

---

## 1. Color

### Base identity

Deep purple base with light/dark adaptive tokens (`DesignSystem/AppColors.swift`).
Always use semantic tokens, never raw hex for chrome:

| Token | Use |
|---|---|
| `Color.kBackground` / `.kBackgroundSecondary` | Screen backgrounds (or `.kBackground()` modifier) |
| `Color.kSurface` / `.kSurfaceElevated` | Cards on the base background |
| `Color.kTextPrimary` / `.kTextSecondary` / `.kTextTertiary` | Text hierarchy |
| `Color.kAccent` / `.kAccentLight` / `.kAccentAlt` | Purple brand accents, gradient text |
| `Color.kSuccess` / `.kGold` / `.kError` | Correct / medium-warning / wrong |
| `Color.kBorder` / `.kSeparator` / `.kGlow` | Purple-tinted strokes and glows |
| `LinearGradient.kPurpleGradient` | Reserved for the primary CTA (Continue, primary buttons) |

Custom colors go through `Color.adaptive(light:dark:)` so both modes work.
White-on-vivid-color cards (below) are the one exception: they read fine in
both modes as is.

### The vivid palette

On top of the purple base, feature content gets its own hue. This is the
core of the look. The canonical palette (from `SATRushView.cardPalette` /
`chipPalette`):

| Name | RGB | Name | RGB |
|---|---|---|---|
| indigo | 0.36, 0.42, 0.95 | purple | 0.55, 0.40, 0.88 |
| coral | 0.95, 0.45, 0.35 | rose | 0.90, 0.30, 0.45 |
| teal-green | 0.20, 0.68, 0.55 | moss | 0.40, 0.62, 0.30 |
| magenta | 0.85, 0.35, 0.62 | blue | 0.20, 0.55, 0.90 |
| amber | 0.95, 0.62, 0.20 | pink | 0.93, 0.28, 0.55 |
| cyan | 0.30, 0.70, 0.78 | | |

Plus the web-mirrored `SATAccent` set (sky, emerald, gold, violet, blue, red)
in `SATChatTheme.swift`, each with `.solid`, `.tint` (~12% fill), and
`.border` (~28% stroke) variants.

Rules for using it:

- **Rotate hues by index** so adjacent cards never repeat:
  `palette[index % palette.count]`.
- **Key the mapping by a stable id** (see `skillColors` in SATRushView) so
  colors do not shuffle on re-render.
- **Every subject or step owns a hue.** Math is green
  (0.22, 0.65, 0.45), Reading & Writing is blue (0.30, 0.51, 0.94), and each
  wizard step gets its own Next-button tint (subject color, then teal, then
  pink). Never reuse the shared purple gradient for these.

### Two fill treatments

1. **Soft gradient fill** for big selectable cards:
   `LinearGradient(colors: [tint, tint.lightened(by: 0.18)], startPoint:
   .topLeading, endPoint: .bottomTrailing)`. Used by subject cards, domain
   cards, difficulty rows, wizard footer buttons.
2. **Solid vivid fill** for compact elements: stat cards, chips, action
   buttons in the celebration screen, and everything following the
   SATChatTheme recipe (solid tint at ~12% opacity + solid colored border +
   full-strength colored icon/label). No gradients on chips, ever.

### Content on colored fills

- Icons: white, inside a rounded square filled `Color.white.opacity(0.22)`
  (68pt tile, radius 18 for hero cards; 44pt, radius 12 for rows).
- Primary text: `.white`. Secondary text: `.white.opacity(0.85...0.9)`.
- Selection ring: `.stroke(.white.opacity(0.9), lineWidth: 2...2.5)` that
  animates in, plus `checkmark.circle.fill` swapping in for `circle`.

### Semantic color logic

- Correct / Easy: `kSuccess`. Medium: `kGold`. Wrong / Hard: `kError`.
- Timers and countdowns: orange. Progress and totals: teal.
- Difficulty icons: leaf.fill (E), flame.fill (M), bolt.fill (H).

---

## 2. Typography

Plus Jakarta Sans everywhere via `Font.k*` (`DesignSystem/AppTypography.swift`).
Never `.font(.system(...))` for text; system sizes are fine for SF Symbols.

| Style | Use |
|---|---|
| `.kLargeTitle` | Celebration headlines ("Rush complete!") |
| `.kTitle` / `.kTitle2` | Card titles, wizard step questions |
| `.kHeadline` | Row titles, option letters, section labels |
| `.kBody` / `.kBodyBold` | Body copy, button labels |
| `.kSubheadline` | Blurbs, secondary lines |
| `.kCaption` / `.kCaption2` | Chips, meta labels, tick labels |

Details that make numbers feel alive:

- Timers: `.monospacedDigit()` so digits do not jitter.
- Changing values: `.contentTransition(.numericText())` plus a snappy
  animation (see SnapSlider's read-out).
- Stat values that might overflow: `.lineLimit(1).minimumScaleFactor(0.7)`.
- Tiny ALL CAPS eyebrows on demo cards ("TEST DAY COUNTDOWN") in caption
  sizes are part of the look; body copy is always sentence case.

---

## 3. Shape, spacing, sizing

All from `DesignSystem/AppSpacing.swift`. 4pt grid via `Spacing.*`.

- **Corners are always `.continuous`** (`RoundedRectangle(cornerRadius:,
  style: .continuous)`), never default circular.
- Chips: `Capsule()`. Answer options and inputs: `CornerRadius.md` (12).
  Cards: `CornerRadius.lg` (16). Hero cards and modals: `CornerRadius.xl`
  (20). Full-width action buttons: 14.
- Hero selectable cards: `minHeight: 180`, `Spacing.lg` padding,
  `kShadowMedium()`.
- Progress bars: capsules, 6 to 8pt tall.
- Full-width action buttons: 15 to 16pt vertical padding, white bold label.
- Touch targets never below `HitTarget.minimum` (44pt).
- Screens: content in a `ScrollView` with `Spacing.md` padding, pinned
  footer button outside the scroll.

---

## 4. Motion

Everything that changes state animates. A value that snaps with no
transition is a bug in the feel.

### Presets (`KAnimation` in AppTheme.swift)

| Preset | Spring | Use |
|---|---|---|
| `.quick` | response 0.3, damping 0.7 | Selections, toggles, tint changes |
| `.standard` | response 0.4, damping 0.75 | Step/page changes, progress fills |
| `.smooth` | response 0.5, damping 0.8 | Large movements, page advance |
| `.bouncy` | response 0.35, damping 0.6 | Playful pop-ins (XP badges, reveals) |

Also in the vocabulary:

- `.snappy(duration: 0.2...0.3)` for numeric read-outs.
- `.linear` only when representing time itself (the countdown bar uses
  `.linear(duration: 0.9)` on a 1s tick so it glides).
- `.repeatForever(autoreverses: true)` easeInOut for ambient life: floating
  hero elements, typing dots, twinkling stars. Slow (1.6s+) and subtle.

### Choreography

Onboarding demos are the reference for staged sequences: a `Task` with
`try? await Task.sleep` between `withAnimation` calls, each stage using a
different spring (see `RushDemo`, `ChatDemo`, `BankDemo`). Use this for any
self-playing or celebratory moment rather than one monolithic animation.

Transitions: combine, do not use bare `.opacity`:

- Chat-style entries: `.move(edge:).combined(with: .opacity)`
- Pop-ins: `.scale.combined(with: .opacity)`
- Wizard pages: shared `pageTransition` with a `.spring(response: 0.4,
  dampingFraction: 0.85)` on the page index.

### Micro-interactions

- Pressed: `scaleEffect(0.98)` with `.spring(response: 0.3, dampingFraction:
  0.7)` (all K button styles do this).
- Selected cards: `scaleEffect(1.01)` + white ring, animated with `.quick`.
- Step dots: active dot grows to a 24x8 capsule in the step's tint, idle
  dots stay 8x8 in `kBorder`.

### Haptics (always paired with the animation)

| Call | When |
|---|---|
| `Haptics.selection()` | Picking an option, choosing an answer |
| `Haptics.light()` | Small chip toggles, select all / clear |
| `Haptics.medium()` | Advancing a step, primary CTA |
| `Haptics.success()` / `.error()` | Answer check result |

---

## 5. States

- **Disabled**: `.opacity(0.4)`, still visible, never hidden.
- **Loading**: skeletons (`SkeletonBox`, `SATQuestionSkeleton`,
  `SATProfileSkeleton` in `DesignSystem/SkeletonView.swift`), not spinners.
- **Empty**: friendly SF Symbol + one short line + one action button
  ("No questions matched those filters." + Back to setup).
- **Error**: same shape as empty, with a Retry action. Message comes from
  the error, tone stays calm.
- **Wrong answer**: reveal, never scold. Green ring on the correct option,
  red on the picked one, explanation card tinted at 8% opacity.

---

## 6. Reusable components (use these before building new ones)

| Component | Lives in | What it is |
|---|---|---|
| `SnapSlider` | SATRushView.swift | Slider snapping to fixed options, big tinted read-out |
| `FlowLayoutChips` / `FlexibleChipLayout` | SATRushView.swift | Wrapping colored chip rows |
| `SATGradientCard`, `SATCardButton`, `.satCard()` | DesignSystem/SATCard.swift | Tinted feature cards with the logo watermark |
| `.satGlassBar()` | Views/Chat/SATChatTheme.swift | Liquid Glass toolbar with fallback |
| `SATAccent` | Views/Chat/SATChatTheme.swift | Solid accent recipe (solid/tint/border) |
| `.kGlassEffect()`, `.kCard()` | DesignSystem/AppTheme.swift | Glass surfaces |
| `.kGradientText()` | DesignSystem/AppColors.swift | Accent-to-pink headline text with glow |
| `TwinklingStarsBackground` | DesignSystem/ | Ambient star background (launch, auth) |
| `KConfirmationPopup` | DesignSystem/ | Confirmation dialog |
| `.buttonStyle(.kPink)` | SATPlayerView.swift | Pink CTA style |
| `.kPrimary` / `.kSecondary` button styles | DesignSystem/AppTheme.swift | Standard purple CTA / tinted secondary |

Note: `SnapSlider`, `FlexibleChipLayout`, and `.kPink` are slated to move
into `DesignSystem/` (see ARCHIVE_CANDIDATES.md, Maintenance item 3). Update
this table when that happens.

---

## 7. Don't

- Don't leave anything on default system blue or default gray lists.
- Don't give two adjacent cards the same hue.
- Don't use gradients on chips or compact accents (solid recipe only).
- Don't change state without an animation and, for taps, a haptic.
- Don't use spinners where a skeleton fits.
- Don't hardcode a light-only or dark-only color; use tokens or
  `Color.adaptive`.
- Don't use `.font(.system(...))` for text.
- Don't use em dashes in any user-facing string (see COPY_GUIDE.md).
- Don't build a new component before checking the table in section 6.
