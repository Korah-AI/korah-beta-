# Korah iOS App (korah-beta 2) — Agent Context

## Mission
Korah is a **100% free, open-source AI study app** built as a nonprofit passion project. The iOS app is the primary product — a SwiftUI study companion backed by Firebase and an OpenAI-powered Vercel proxy. No paywalls, no subscriptions, ever.

**Web companion:** `korah-web` (see its own AGENT.md)
**Shared backend:** Vercel serverless proxy at `https://korah-beta.vercel.app`

---

## Platform Requirements

| Requirement | Value |
|---|---|
| iOS Deployment Target | iOS 26.0+ |
| Swift | 6.2+ (strict concurrency) |
| Xcode | Latest stable |
| UI Framework | SwiftUI only (no UIKit unless unavoidable) |
| State Management | `@Observable` classes (`@MainActor`) |
| Concurrency | Swift structured concurrency (`async/await`, `Task`) |
| Database | Firebase Firestore (cloud) + UserDefaults (local, being migrated) |
| Auth | Firebase Auth (Email/Password, Google Sign-In, Apple Sign-In) |

---

## Repository Structure

```
Korah (Beta)/
├── KorahApp.swift                  # App entry point, Firebase init, auth routing
├── LauncherView.swift              # Post-auth routing: onboarding → mood check-in → HomePageView
├── OpeningView.swift               # Pre-auth splash
├── MainAppView.swift               # Stub (not the real main content)
├── Theme.swift                     # Legacy theme helpers (prefer DesignSystem/)
│
├── DesignSystem/                   # Design tokens — USE THESE, not hard-coded values
│   ├── AppColors.swift             # Color.kBackground, Color.kAccent, .Dark/Light palettes, gradients, shadow modifiers
│   ├── AppSpacing.swift            # Spacing.md, CornerRadius.card, ComponentSize, HitTarget
│   ├── AppTypography.swift         # Font.kTitle, Font.kBody, .kTitleStyle() modifiers
│   └── AppTheme.swift              # ThemeManager, KPrimaryButtonStyle, kCard(), kGlassEffect(), KAnimation, Haptics
│       └── TwinklingStarsBackground.swift  # Canvas-based animated star background
│
├── Models/
│   ├── User.swift                  # Firestore User model (id, firstName, lastName, email, createdAt)
│   └── RateLimitError.swift        # Rate limit error type
│
├── Managers/
│   ├── AuthManager.swift           # @Observable Firebase Auth manager (email, Google, Apple sign-in)
│   ├── StudyDataManager.swift      # UserDefaults-based study data (BEING MIGRATED to Firestore)
│   ├── AppStateManager.swift       # Onboarding, launch animation state
│   ├── StreakManager.swift         # Daily study streak tracking
│   ├── NotificationManager.swift   # Local push notifications
│   ├── DeviceIDManager.swift       # Device ID for rate limiting
│   └── NetworkMonitor.swift        # Network connectivity monitoring
│
├── Helpers/
│   ├── APIErrorHandler.swift       # Centralized API error handling
│   └── URLRequest+DeviceID.swift   # Adds X-Device-ID header to requests
│
└── Views/                          # ALL main feature UI lives here
    ├── Auth/
    │   ├── LoginView.swift
    │   └── SignupView.swift
    ├── Authentication/             # Post-login flows
    │   ├── MoodCheckInView.swift
    │   └── MoodSettingsView.swift
    ├── Chat/
    │   ├── ChatView.swift
    │   ├── ChatViewModel.swift     # @Observable, streaming SSE, JSON response parsing
    │   ├── Models/ChatMessage.swift
    │   └── Components/
    │       ├── MessageBubbleView.swift
    │       └── ComposerView.swift
    ├── Config/
    │   └── OpenAIConfig.swift      # Vercel proxy URL constants
    ├── Conversation/               # Chat history management
    │   ├── ConversationHistoryView.swift
    │   ├── ConversationManager.swift
    │   └── ConversationModels.swift
    ├── Feedback/
    │   └── FeedbackView.swift
    ├── homepage/
    │   ├── HomePageView.swift      # Main TabView: Home, Tasks, Scan, Focus, Study tabs
    │   └── HomeDataManager.swift
    ├── LaunchAnimationView.swift
    ├── Onboarding/
    │   └── OnboardingView.swift
    ├── Scanner/
    │   ├── ScanView.swift          # Camera scan → AI content generation
    │   ├── CustomCameraView.swift
    │   ├── LatexMarkdownView.swift
    │   └── KorahMarkdownTheme.swift
    ├── Study/                      # Core study feature set
    │   ├── StudyModels.swift       # FlashcardSet, StudyGuide, PracticeTest, PracticeTestQuestion
    │   ├── StudyViews.swift        # StudyHomeView, StudyGuideDetailView, PracticeTestDetailLoaderView
    │   ├── StudyUtilities.swift
    │   ├── DateFormatting.swift
    │   ├── ModernLoadingOverlay.swift
    │   ├── Flashcards/
    │   │   ├── FlashcardsView.swift
    │   │   ├── FlashcardModels.swift   # FlashcardSet, Flashcard (front/back)
    │   │   ├── FlashcardComponents.swift
    │   │   ├── FlashcardSheets.swift
    │   │   └── StudySessionView.swift
    │   ├── StudyGuides/
    │   │   └── StudyGuidesView.swift
    │   ├── PracticeTests/
    │   │   └── PracticeTestsView.swift
    │   ├── AIGenerators/           # AI-powered content creation from prompts
    │   │   ├── AIFlashcardPromptGeneratorView.swift
    │   │   ├── AIPracticeTestGeneratorView.swift
    │   │   ├── AIStudyGuidePromptGeneratorView.swift
    │   │   ├── AIGenerateFlashcardsFromGuideView.swift
    │   │   ├── AIGenerateStudyGuideFromFlashcardsView.swift
    │   │   └── AIGeneratePracticeTestFromGuideView.swift
    │   ├── ManualCreators/         # Manual content creation
    │   │   ├── ManualFlashcardSetCreateView.swift
    │   │   ├── ManualStudyGuideCreateView.swift
    │   │   └── ManualPracticeTestCreateView.swift
    │   └── Scanners/               # Scan-to-study-item
    │       ├── ScanFlashcardsView.swift
    │       ├── ScanStudyGuideView.swift
    │       └── ScanPracticeTestView.swift
    ├── Tasks/
    │   ├── Task.swift              # StudyTask model
    │   ├── AddTaskView.swift
    │   ├── EditTaskView.swift
    │   └── MoodHelpers.swift       # Mood-based task sorting/recommendations
    └── ToDo/
        ├── ToDoListView.swift
        └── Timer/
            ├── FocusTimerView.swift
            ├── CompactStudyTimerView.swift
            └── FloatingTimerIndicator.swift

FocusTimerWidget/                   # iOS Widget target
├── FocusTimerWidget.swift
├── FocusTimerWidgetBundle.swift
└── FocusTimerWidgetControl.swift
```

---

## App Flow

```
KorahApp → Firebase.configure()
         → AuthManager.checkAuthenticationState()
         → [not authenticated] → LoginView / SignupView
         → [authenticated]     → LauncherView
                                  → LaunchAnimationView (first launch)
                                  → OnboardingView (first time)
                                  → MoodCheckInView (every 24h)
                                  → HomePageView (main TabView)
                                       Tab 0: Home dashboard
                                       Tab 1: ToDoListView (Tasks)
                                       Tab 2: ScanView (Camera → AI)
                                       Tab 3: FocusTimerView
                                       Tab 4: StudyHomeView (Flashcards/Guides/Tests)
```

---

## Firebase Integration

### Current State
- **Firebase Auth** — fully implemented. Supports email/password, Google Sign-In, Apple Sign-In
- **Firestore** — User profiles stored at `users/{uid}`
- **StudyDataManager** — still uses `UserDefaults` for flashcard sets, study guides, and practice tests. **This is actively being migrated to Firestore**

### Migration Target (Firestore Schema)
When migrating study data to Firestore, use this structure:
```
users/{uid}/
  flashcardSets/{setId}    — FlashcardSet documents
  studyGuides/{guideId}    — StudyGuide documents
  practiceTests/{testId}   — PracticeTest documents
  conversations/{convId}   — Chat sessions
```

### CloudKit is NOT used — Firestore is the cloud backend.
Since Firestore is used (not CloudKit), `@Attribute(.unique)` restrictions do not apply here. However, keep model properties as optional or with default values for future flexibility.

---

## Shared Backend (Vercel Proxy)

Defined in `Views/Config/OpenAIConfig.swift`:

| Endpoint | Purpose |
|---|---|
| `POST /api/proxy` | OpenAI chat completions (gpt-4o, streaming SSE) |
| `POST /api/proxy-stream` | Dedicated streaming completions |
| `POST /api/transcribe` | Whisper audio transcription |
| `POST /api/speak` | Text-to-speech (TTS) |
| `POST /api/generate-study-item` | Generate flashcards/guides/tests from prompt |

All requests include `X-Device-ID` header (via `URLRequest.addDeviceIDHeader()`) for rate limiting via Upstash Redis. **No API key in the app** — keys live on Vercel.

---

## Design System

Always use design system tokens. Never use hard-coded colors, font sizes, or spacing values.

### Colors (`DesignSystem/AppColors.swift`)
```swift
// Semantic tokens (adapt to light/dark automatically via Asset Catalog)
Color.kBackground       // Page background
Color.kSurface          // Card background
Color.kAccent           // Primary purple (#8b5cf6 dark, #7c3aed light)
Color.kTextPrimary      // Primary text
Color.kTextSecondary    // Muted text
Color.kError            // Destructive red

// Programmatic light/dark palette
Color.Dark.accent       // #8b5cf6
Color.Light.accent      // #7c3aed
Color.adaptive(light:dark:)  // Adaptive helper

// Gradients
LinearGradient.kAccentGradient    // Purple gradient for buttons
LinearGradient.kPurpleGradient    // Same; use for user message bubbles
LinearGradient.kBackgroundGradient
```

### Spacing (`DesignSystem/AppSpacing.swift`)
```swift
Spacing.xs   // 8pt
Spacing.sm   // 12pt
Spacing.md   // 16pt (default)
Spacing.lg   // 20pt
Spacing.xl   // 24pt
Spacing.xxl  // 32pt

CornerRadius.card     // 16pt
CornerRadius.button   // 12pt
CornerRadius.modal    // 20pt
```

### Typography (`DesignSystem/AppTypography.swift`)
```swift
Font.kTitle        // .title.bold
Font.kHeadline     // .headline.semibold
Font.kBody         // .body
Font.kCaption      // .caption

// View modifiers (apply font + color together)
.kTitleStyle()
.kBodyStyle()
.kSecondaryStyle()
.kCaptionStyle()
```

### Components (`DesignSystem/AppTheme.swift`)
```swift
// Button styles
Button("Label", action: {}).buttonStyle(.kPrimary)    // Purple gradient, glow
Button("Label", action: {}).buttonStyle(.kSecondary)  // Outlined purple
Button("Label", action: {}).buttonStyle(.kGhost)      // Text only
Button("Label", action: {}).buttonStyle(.kGlass)      // iOS 18 glass

// View modifiers
.kCard()               // Glass card with padding + shadow
.kGlassEffect()        // iOS 18+ Liquid Glass, falls back to ultraThinMaterial
.kBackground()         // App background gradient
.kBackground(withStars: true)  // Twinkling stars canvas background
.kShadowGlow()         // Purple glow shadow
.kShadowSubtle()       // Subtle card shadow

// Animations
KAnimation.quick    // .spring(response: 0.3, dampingFraction: 0.7)
KAnimation.bouncy   // .spring(response: 0.35, dampingFraction: 0.6)

// Haptics
Haptics.light()
Haptics.success()
Haptics.error()
```

### Glass Effect Notes
- iOS 26 uses **Apple Liquid Glass** (`glassEffect(.regular.tint(...))`) — this is the default for cards and buttons in the app
- iOS 17 and below fallback: `.ultraThinMaterial` + border overlay
- Use `.kGlassEffect()` modifier — it handles version detection automatically
- Use `KGlassEffectContainer` to group adjacent glass elements

---

## Swift & SwiftUI Coding Standards

- **`@Observable` + `@MainActor`** on all observable classes (never `ObservableObject`)
- **`NavigationStack`** only — never `NavigationView`
- **`Tab` API** for tab bars — never `tabItem()`
- **`foregroundStyle()`** — never `foregroundColor()`
- **`clipShape(.rect(cornerRadius:))`** — never `.cornerRadius()`
- **`localizedStandardContains()`** for user-input text filtering
- **No force unwraps** (`!`) — use `guard let`, `if let`, or `??`
- **No `DispatchQueue.main.async`** — use `await MainActor.run { }` or `@MainActor` functions
- **No `UIScreen.main.bounds`** — use `containerRelativeFrame()` or `GeometryReader` as a last resort
- **No `ObservableObject`/`@Published`** — use `@Observable`
- **`onChange` must use 2-parameter variant**: `onChange(of: value) { old, new in ... }`
- **`Task.sleep(for:)`** — never `Task.sleep(nanoseconds:)`
- **`Button("Label", systemImage: "plus", action: fn)`** when using image in a button label
- **`ImageRenderer`** — never `UIGraphicsImageRenderer` for SwiftUI view rendering
- **Separate each type into its own file** — no multiple structs/classes in one file
- **Place view logic in view models** (e.g. `ChatViewModel`, `HomeDataManager`)
- **Avoid `AnyView`** unless absolutely necessary
- **Avoid hard-coded padding/spacing values** — use `Spacing.*` and `CornerRadius.*` tokens
- **Dynamic Type** — never specify hard-coded font sizes; use the typography scale

---

## Open-Source Libraries Available

These repos live in `../open-source/`. Add them to the project via Swift Package Manager.

### `open-source/DeckKit/`
**SwiftUI card deck library** for swipe-based card UIs.
- SPM URL: `https://github.com/danielsaidi/DeckKit`
- Key API: `DeckView($items) { item in CardView(item) }` — renders a swipeable card stack
- Supports swipe gestures, edge swipes, shuffling, favorites
- **Use for**: Flashcard study sessions (swipe left = wrong, swipe right = correct), onboarding card stacks
- Reference local code in `Sources/` for customization patterns

### `open-source/shiny/`
**Motion-based gyroscope shimmer/texture effects** for SwiftUI views.
- SPM URL: `https://github.com/maustinstar/shiny`
- Key API: `Text("Korah").shiny()` or `.shiny(.hyperGlossy(UIColor.systemGray5))`
- **Use for**: Premium-feeling UI elements — flashcard fronts, achievement badges, onboarding illustrations, the Korah logo/wordmark

### `open-source/ConfettiSwiftUI/`
**Confetti particle animations** for celebratory moments.
- SPM URL: `https://github.com/simibac/ConfettiSwiftUI`
- Key API: `.confettiCannon(counter: $counter)` — trigger by incrementing counter
- Supports shapes, emojis, SF Symbols, custom text
- **Use for**: Completing a flashcard deck, finishing a practice test, hitting a streak milestone, study session completion

### `open-source/lottie-ios/`
**Lottie JSON animation player** for complex vector animations.
- SPM URL: `https://github.com/airbnb/lottie-ios`
- Key API (SwiftUI): `LottieView(animation: .named("loading"))` from the `Lottie` package
- **Use for**: Launch animation, loading states, empty state illustrations, onboarding animations
- Source JSON animations from LottieFiles.com (free tier available)

### `open-source/swipeable-cards/`
**Local SwiftUI swipeable cards demo** — raw SwiftUI implementation (no external dependency).
- Located at: `../open-source/swipeable-cards/Swipeable Cards/`
- **Use for**: Reference implementation for building custom swipe gesture logic without DeckKit if more control is needed

### `open-source/open-swiftui-animations/`
A local reference collection for SwiftUI animation patterns (currently empty — check the original GitHub repo for examples).
- GitHub: search "open-swiftui-animations" for the source repo
- **Use for**: Custom view transition patterns, micro-interaction animations

---

## Planned: OpenNotebook / NotebookLM Features (iOS)

The iOS app will receive an equivalent feature set to the web version. The iOS implementation should feel native and leverage Apple platform capabilities:

### Notebook Management
- A new "Notebooks" tab or section in the Study tab
- Create/edit/delete notebooks to organize study material by subject or class
- Each notebook contains sources, notes, and chat sessions

### Source Uploading
- Accept PDFs, images (OCR via Vision framework), and web URLs
- Use `DocumentGroup` or `UIDocumentPickerViewController` for file import
- Upload source content to the Vercel backend for chunking + embedding

### RAG-Powered Chat
- Chat sessions tied to a notebook context
- Backend retrieves relevant source chunks before calling OpenAI
- Display citation footnotes referencing source documents

### Notes Feature
- Manual note creation (rich text)
- AI-generated notes from sources (summarization, key points extraction)
- Notes linked to specific source passages

### Content Transformations
- Quick-action buttons on study items: "Generate Study Guide from this PDF", "Make Flashcards from Notes"
- These call the shared Vercel transformation endpoints

### Audio Transcription
- Record voice notes → transcribe via `/api/transcribe` (Whisper)
- Import lecture audio files → transcribe → add as a notebook source

---

## Important Notes for AI Agents

1. **StudyDataManager is UserDefaults-based and being migrated** — when adding new study data features, implement them directly in Firestore rather than UserDefaults
2. **The app is dark-mode only** (`preferredColorScheme(.dark)` in `KorahApp`) — but the design system supports light mode for future use
3. **The main feature UI is entirely in `Korah (Beta)/Views/`** — this is where most new code goes
4. **HomePageView uses old styling** (`.background(Color.white.opacity(0.1))`, `.cornerRadius(10)`) — migrate these to design system tokens when touching that file
5. **`korah-bot` Vercel proxy is the shared backend** — do not create a separate iOS-only backend; extend the existing Vercel project
6. **Widget target** (`FocusTimerWidget`) is separate from the main app target — ensure any shared data uses App Groups
7. Do not introduce third-party Swift packages without discussion, except those listed in the open-source section above
