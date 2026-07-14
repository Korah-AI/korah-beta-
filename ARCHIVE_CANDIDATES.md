# Archive / Removal Candidates

Audit of `Korah (Beta)` (2026-07) — files with no live entry point from the
current app flow (`KorahApp` → `LauncherView` → `MainTabView`: SAT Home ·
Practice · Ask Korah · Profile). Verified by grepping type references across
all Swift files. Nothing here has been deleted yet; files also need removal
from the Xcode target when archived.

## Definitely dead (zero inbound references)

| File | Notes |
|---|---|
| `OpeningView.swift` | Replaced by `LauncherView` + `LaunchAnimationView` |
| `Views/Authentication/MoodSettingsView.swift` | Whole `Authentication/` folder is just this file |
| `Views/Feedback/FeedbackView.swift` | Nothing presents it |
| `Views/Chat/SATChatTheme.swift` | No references anywhere |

## Dead cluster: ToDo / Tasks / mood

Deferred from v1 navigation (see comment in `MainTabView.swift`); nothing
navigates to `ToDoListView`.

- `Views/ToDo/ToDoListView.swift`
- `Views/Tasks/AddTaskView.swift`
- `Views/Tasks/EditTaskView.swift`
- `Views/Tasks/MoodHelpers.swift`
- `Views/homepage/HomeDataManager.swift` (only referenced by ToDo/Tasks files)

**Keep for now:** `Views/Tasks/Task.swift` (`StudyTask`) — still imported by
`NotificationManager`, which is alive. Its task-notification scheduling
functions have no live callers either, so `Task.swift` can go once those are
trimmed out of `NotificationManager`.

## Dead cluster: old scanner chat

Superseded by `Views/Chat/ChatView` (the "Ask Korah" tab).

- `Views/Scanner/ScanView.swift` (only entry point to the rest)
- `Views/Conversation/ConversationHistoryView.swift`
- `Views/Scanner/KorahLatexView.swift`
- `Helpers/APIErrorHandler.swift`
- `Models/RateLimitError.swift` (only used by `APIErrorHandler`)

**Keep:** `LatexMarkdownView.swift`, `KorahMarkdownTheme.swift`,
`CustomCameraView.swift`, `ImageUtils.swift` — used by the live chat and the
SAT explanation sheet.

## Dead cluster: entire `Views/Study/` tree (~25 files)

`StudyHomeView` (in `StudyViews.swift`) has no entry point anywhere in the
live app, which orphans everything under it:

- `Views/Study/StudyViews.swift`, `StudyModels.swift`, `StudyUtilities.swift`,
  `DateFormatting.swift`, `ModernLoadingOverlay.swift`
- `Views/Study/Flashcards/*`
- `Views/Study/StudyGuides/*`
- `Views/Study/PracticeTests/*`
- `Views/Study/AIGenerators/*`
- `Views/Study/ManualCreators/*`
- `Views/Study/Scanners/*`
- `Managers/StudyGenerationService.swift`

**Keep for now:** `FirestoreStudyService` / `StudyDataManager` — still
referenced by `KorahApp`, `MainTabView`, and `DataMigrationManager`
(migration of existing user data).

## MathChat — still wired, needs a small edit to retire

`SATHomeView`'s `desmosCard` ("Learn how to use Desmos") still pushes
`HomeDestination.mathChat`. To retire:

1. Remove `desmosCard` and its use in `SATHomeView`
2. Remove the `.mathChat` case from `HomeDestination` (`SATHomeView.swift`)
3. Delete `Views/SAT/MathChatView.swift`

**Keep:** `Views/SAT/DesmosWebView.swift` — the calculator sheet in
`SATPlayerView` and `SATRushView` uses it.

## Legacy but alive

- `Theme.swift` — old Color/View extensions still used alongside
  `DesignSystem/AppTheme.swift`; consolidate gradually rather than delete.
