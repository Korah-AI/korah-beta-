# Korah iOS — Implementation Plan

This plan prioritizes making the iOS app feel like a genuinely great, opinionated study tool — not a checklist of ported web features. Items are ordered by impact relative to effort. Each phase can ship independently.

---

## Current State Snapshot

**Navigation:** 5-tab layout — Home, Tasks, Scanner, Focus Timer, Study Tools  
**Backend:** GPT-4o via Vercel proxy (`korah-beta.vercel.app`), Firebase Auth + Firestore  
**Design System:** `AppColors`, `AppSpacing`, `AppTypography`, `AppTheme` — design tokens in place, iOS 18 Liquid Glass with iOS 17 fallback  
**Already built (but underused):** spaced repetition fields on `Flashcard`, `nextReviewDate`/`isDueForReview` exist but nothing surfaces them; mood system only touches task sorting

---

## Phase 1 — Activate What Already Exists

These are high-value changes that require almost no new code — the model layer already supports them.

### 1.1 Spaced Repetition Surface

`Flashcard` already has `nextReviewDate`, `isDueForReview`, and `difficultyLevel`. Nothing currently uses them in the UI.

**Changes:**
- `StudySessionView` — after each card, show three buttons instead of just a swipe: **Easy** / **Hard** / **Again**. Map to `DifficultyLevel` and call `markStudied(difficulty:)`.
- `HomePageView` — add a "Due for Review" row above the recommended tasks grid. Pull all `FlashcardSet.cards` where `isDueForReview == true`, group by set, show as a horizontal scroll of cards with count badge.
- `FlashcardsView` — badge each set with how many cards are due (`cards.filter(\.isDueForReview).count`).

**Files:** `StudySessionView.swift`, `FlashcardsView.swift`, `HomePageView.swift`

---

### 1.2 Mood System → Study Session Routing

The mood check-in exists and sets `@AppStorage("UserMood")`. It currently only sorts the task list. Route it to study behavior:

- **Green mood** → when opening Study Tools, show a banner: "You're focused — want a practice test?" with a one-tap shortcut to the last practice test.
- **Yellow mood** → suggest flashcard review of due cards.
- **Red mood** → surface study guides (passive reading, no pressure).

This is a `switch userMood` block in `StudyHomeView` that injects a contextual recommendation card at the top of the list. No new state needed.

**Files:** `Views/Study/StudyViews.swift` (or `StudyHomeView` equivalent), `MoodHelpers.swift`

---

### 1.3 Focus Timer → Content Suggestion

When a Pomodoro session ends, `FocusTimerView` shows a celebration. Add a secondary action: **"Start a quick review"** that deep-links to `StudySessionView` with cards that are due. This closes the loop between time-boxing and actual study content.

**Files:** `FocusTimerView.swift`, `FloatingTimerIndicator.swift`

---

## Phase 2 — Home Dashboard Redesign

The current home tab is a stat grid + task list. Make it tell the user's story at a glance.

### 2.1 Study Sparkline

A 7-day horizontal bar chart of study minutes. `StreakManager` already records daily opens; extend it to also persist `studyMinutesToday` from `FocusTimerManager`. Render with `Chart` (Swift Charts, iOS 16+, already in the deployment target).

```swift
// New field on StreakManager
var weeklyStudyMinutes: [Date: Int] = [:]  // keyed to start of day

// Called when FocusTimer completes a session
func recordStudySession(minutes: Int)
```

**Files:** `StreakManager.swift`, `HomeDataManager.swift`, `HomePageView.swift`

---

### 2.2 Inline Mood Picker on Home

Remove the mood from a separate modal trigger. Replace the "Set Mood" quick action button with three tappable circles (green / yellow / red) directly in the hero card — 3 taps, done. The full `MoodSettingsView` sheet stays for editing preferences, but the daily check-in happens inline.

**Files:** `HomePageView.swift`, `MoodSettingsView.swift`

---

### 2.3 "Today's Challenge" Card

One SAT-style question a day, shown as a card on Home. Rotates daily (keyed to `Calendar.current.startOfDay(for: Date())`). Tap → full question view with answer reveal. Seeded from a local JSON bundle (Phase 3 adds the full question bank).

This establishes the habit loop before the full SAT tab exists.

**Files:** New `DailyQuestionCard.swift`, `HomePageView.swift`, new `Resources/daily_questions.json`

---

## Phase 3 — SAT Prep Tab (Biggest New Feature)

The web app has a full SAT module (question bank, math chat with Desmos, difficulty filtering). This is the largest web-to-iOS gap.

### 3.1 Navigation Change

Replace the **Scanner tab** (tab index 2) with a **SAT tab**. The scanner functionality moves inside Study Tools as a section — it already exists there (`ScanFlashcardsView`, `ScanStudyGuideView`, `ScanPracticeTestView`). The dedicated tab was redundant.

```
Tab 0: Home
Tab 1: Tasks
Tab 2: SAT Prep          ← new
Tab 3: Focus Timer
Tab 4: Study Tools
```

**Files:** `HomePageView.swift` (TabView), remove `ScanView` from tab bar

---

### 3.2 SAT Data Model

```swift
// New file: Views/SAT/SATModels.swift

struct SATQuestion: Identifiable, Codable {
    var id: UUID
    var section: SATSection          // .math, .readingWriting
    var difficulty: Difficulty       // .easy, .medium, .hard
    var prompt: String
    var options: [String]            // 4 options for MCQ
    var correctIndex: Int
    var explanation: String
    var domain: String               // e.g. "Algebra", "Geometry", "Craft and Structure"
    
    // User performance tracking
    var lastAttemptedAt: Date?
    var wasCorrect: Bool?
    var attemptCount: Int = 0
}

enum SATSection: String, Codable { case math, readingWriting }
enum Difficulty: String, Codable { case easy, medium, hard }
```

Store user performance per question in Firestore under `users/{uid}/satProgress/{questionId}`.

---

### 3.3 SAT Question Bank

Bundle ~200 curated SAT questions as `Resources/sat_questions.json`. Questions already exist in the web repo under `korah-web/` — port and format them. This gives the app offline-capable content from day one.

`SATDataManager` loads from bundle on first launch and merges user performance from Firestore.

---

### 3.4 SAT Home View

```
SATHomeView
├── Progress header — "Math: 34% correct · Reading: 51% correct"
├── Swipe-to-answer deck (reuse DeckKit, same as flashcards)
│   └── SATQuestionCard — question, 4 options, tap to answer
├── Filter bar — All / Math / Reading · Easy / Medium / Hard
└── "Math Lab" button → SATMathChatView
```

The swipe deck is the core loop: answer, see explanation, next card. Correct = green glow + success haptic. Wrong = red flash + explanation shown inline.

---

### 3.5 SAT Math Chat (Desmos Integration)

A dedicated chat view where the AI tutor has access to math context, plus an embedded `WKWebView` loading the Desmos API.

```swift
// New file: Views/SAT/SATMathChatView.swift

struct SATMathChatView: View {
    // Top half: DesmosView (WKWebView wrapping https://www.desmos.com/api/v1.9/calculator.js)
    // Bottom half: ChatView with a math-specialist system prompt
    // "Graph this" button in composer → sends expression to Desmos via JS bridge
}
```

The Desmos API is free and loads via CDN. JS bridge sends expressions: `calculator.setExpression({ id: 'graph1', latex: expr })`.

System prompt for this view specifically: *"You are a math tutor helping with SAT math. When you produce an equation or function, also output it in a `<graph>` tag so it can be plotted. Keep explanations concise."*

**Files:** New `Views/SAT/SATMathChatView.swift`, `Views/SAT/DesmosWebView.swift`

---

## Phase 4 — Study Library View

Right now `StudyHomeView` segments content by type (flashcards in one section, guides in another, tests in another). Add a **Library tab/sheet** that is a single unified list of all study items, sorted by `lastOpenedAt`, with a search bar and type filter chips.

This mirrors the web's `study/feed.html` but feels native: pull-to-refresh, swipe-to-delete, long-press context menu (duplicate, share, delete).

**Files:** New `Views/Study/StudyLibraryView.swift`, `StudyDataManager.swift`

---

## Phase 5 — Voice-First Chat

Voice chat exists but is a secondary input. Make it the primary entry point in `ChatView`.

### 5.1 Layout Change

Large centered mic button at rest. Tap → recording starts, waveform animation plays (use `AVAudioRecorder` meter levels to animate bars). Release → transcription fires → response streams back as audio via `/api/speak`.

### 5.2 Eyes-Free Mode

A new "Study Session Mode" button in the chat nav bar. Activates: screen dims, only the mic button remains visible, audio is the entire interface. Good for commuting, walking, lying in bed reviewing before sleep.

This is a `fullScreenCover` with a minimal dark view, `AVAudioSession` set to `.playAndRecord` with `.allowBluetooth`.

**Files:** `ChatView.swift`, `ChatViewModel.swift`, `ComposerView.swift`

---

## Phase 6 — Polish & Delight

Small changes, outsized feel improvement.

### 6.1 Haptics Throughout

| Interaction | Haptic |
|---|---|
| Flashcard swipe — correct | `.success` (UINotificationFeedbackGenerator) |
| Flashcard swipe — incorrect | `.warning` |
| SAT question — correct | `.success` |
| Task completed | `.success` |
| Focus timer session end | `.notification(.success)` |
| Mood selection | `.selection` (UISelectionFeedbackGenerator) |

**Files:** Add `HapticManager.swift` with a static wrapper, call from relevant views.

---

### 6.2 PDF Export for Study Guides

`StudyGuidesView` — add a share button that renders the guide's markdown content to a `PDFDocument` via `UIGraphicsPDFRenderer`. Students share notes; this is organic distribution.

```swift
// New file: Helpers/PDFExporter.swift
func exportStudyGuide(_ guide: StudyGuide) -> Data
```

**Files:** New `Helpers/PDFExporter.swift`, `StudyGuidesView.swift`

---

### 6.3 Weekly Mood × Streak Correlation

In a new "Insights" section on Home (or a sheet accessible from the streak badge): a simple chart showing mood level per day alongside study minutes. `Chart` framework, two overlaid series. The message: consistent study → consistent mood. Nobody else shows this.

---

## File Creation Summary

```
Korah (Beta)/
├── Views/
│   ├── SAT/
│   │   ├── SATModels.swift          ← Phase 3
│   │   ├── SATHomeView.swift        ← Phase 3
│   │   ├── SATQuestionCard.swift    ← Phase 3
│   │   ├── SATDataManager.swift     ← Phase 3
│   │   ├── SATMathChatView.swift    ← Phase 3.5
│   │   └── DesmosWebView.swift      ← Phase 3.5
│   ├── Study/
│   │   └── StudyLibraryView.swift   ← Phase 4
│   └── Home/
│       └── DailyQuestionCard.swift  ← Phase 2.3
├── Helpers/
│   ├── HapticManager.swift          ← Phase 6.1
│   └── PDFExporter.swift            ← Phase 6.2
└── Resources/
    ├── sat_questions.json           ← Phase 3.3
    └── daily_questions.json         ← Phase 2.3
```

---

## What Not to Build

- Landing/marketing pages — web-only concern
- Email-only auth — Apple/Google are better on iOS
- Gemini backend — GPT-4o is already integrated and working
- Opportunities / Productivity Tips pages — no mobile equivalent needed

---

## Priority Order

| # | Feature | Effort | Impact |
|---|---|---|---|
| 1 | Activate spaced repetition UI (1.1) | Low | High |
| 2 | Mood → study routing (1.2) | Low | High |
| 3 | Home dashboard redesign (Phase 2) | Medium | High |
| 4 | SAT prep tab (Phase 3) | High | Very High |
| 5 | Study Library view (Phase 4) | Low | Medium |
| 6 | Voice-first chat UX (Phase 5) | Medium | Medium |
| 7 | Haptics (6.1) | Very Low | Medium |
| 8 | PDF export (6.2) | Low | Medium |
| 9 | Insights chart (6.3) | Medium | Medium |
