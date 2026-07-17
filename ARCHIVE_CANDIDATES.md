# Archive / Removal Candidates

Audit of `Korah (Beta)` (2026-07, re-verified 2026-07-17) — files with no live
entry point from the current app flow (`KorahApp` → `LauncherView` →
`MainTabView`: SAT Home · Practice · Ask Korah · Profile). Verified by
scanning every top-level type across all Swift files for inbound references.
Nothing here has been deleted yet; files also need removal from the Xcode
target when archived.

## Definitely dead (zero inbound references)

| File | Notes |
|---|---|
| `OpeningView.swift` | Replaced by `LauncherView` + `LaunchAnimationView` |
| `Views/Authentication/MoodSettingsView.swift` | Whole `Authentication/` folder is just this file; archiving it also resolves the `Authentication/` vs `Auth/` naming clash |
| `Views/Feedback/FeedbackView.swift` | Nothing presents it |

> **Correction (2026-07-17):** `Views/Chat/SATChatTheme.swift` was previously
> listed here — it is **live**. `ChatView` uses `SATStarter.all` (welcome
> starter cards), the `SATAccent` palette, and `satGlassBar()`. Do not delete.

## Dead cluster: ToDo / Tasks / mood

Deferred from v1 navigation (see comment in `MainTabView.swift`); nothing
navigates to `ToDoListView`.

- `Views/ToDo/ToDoListView.swift`
- `Views/Tasks/AddTaskView.swift`
- `Views/Tasks/EditTaskView.swift`
- `Views/Tasks/MoodHelpers.swift`
- `Views/homepage/HomeDataManager.swift` (only referenced by ToDo/Tasks files;
  the lowercase `homepage/` folder will be empty after this)

**Keep for now:** `Views/Tasks/Task.swift` (`StudyTask`) — still imported by
`NotificationManager`, which is alive. Its task-notification scheduling
functions have no live callers either, so `Task.swift` can go once those are
trimmed out of `NotificationManager` (see Maintenance below).

## Dead cluster: old scanner chat

Superseded by `Views/Chat/ChatView` (the "Ask Korah" tab).

- `Views/Scanner/ScanView.swift` (only entry point to the rest)
- `Views/Conversation/ConversationHistoryView.swift`
- `Views/Scanner/KorahLatexView.swift`
- `Helpers/APIErrorHandler.swift`
- `Models/RateLimitError.swift` (only used by `APIErrorHandler`)

When this cluster goes, also remove the **voice endpoints in
`Views/Config/APIConfig.swift`** (`legacyBaseURL`, `transcriptionsURL`,
`speechURL`) — only ScanView's TTS code uses them.

**Keep:** `LatexMarkdownView.swift`, `KorahMarkdownTheme.swift`,
`CustomCameraView.swift`, `ImageUtils.swift` — used by the live chat and the
SAT explanation sheet.

**Keep for now:** `Views/Conversation/ConversationManager.swift` — its only
live caller is `DataMigrationManager` (migrating old file-based conversations
to Firestore). Retire it together with the migration path.
`ConversationModels.swift` stays regardless: `Conversation` /
`ConversationMessage` are used by the live `ChatViewModel` and
`FirestoreConversationService`.

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
- `Managers/NetworkMonitor.swift` — only referenced by Study-cluster files
  (StudyGuidesView, ManualCreators, PracticeTestsView); dies with the tree

**Keep for now:** `FirestoreStudyService` / `StudyDataManager` — still
referenced by `KorahApp`, `MainTabView`, and `DataMigrationManager`
(migration of existing user data).

## `Theme.swift` — dead once the clusters above are archived

Previously listed as "legacy but alive; consolidate gradually." Re-audit
shows **every caller of every member is in a dead cluster** (Study tree,
ToDo/Tasks, Feedback, Scanner, OpeningView). `korahCard`, `korahListStyle`,
`openedAgo`, `KorahText`, and `SegmentedHeader` have zero callers anywhere.
No consolidation needed — delete the whole file together with the clusters.

## MathChat — still wired, needs a small edit to retire

`SATHomeView`'s `desmosCard` ("Learn how to use Desmos") still pushes
`HomeDestination.mathChat`. To retire:

1. Remove `desmosCard` and its use in `SATHomeView`
2. Remove the `.mathChat` case from `HomeDestination` (`SATHomeView.swift`)
3. Delete `Views/SAT/MathChatView.swift`

**Keep:** `Views/SAT/DesmosWebView.swift` — the calculator sheet
(`DesmosCalculatorSheet`) in `SATPlayerView` and `SATRushView` lives there.

## Dead members inside live files (trim, don't delete the file)

- `Views/Auth/AuthComponents.swift` — `AuthErrorBanner`, `AuthFieldRow`,
  `AuthOrDivider` have zero references; only `AuthValidationHint` is live
  (SignupView).
- `DesignSystem/AppTheme.swift` — `KPrimaryButtonStyle`,
  `KSecondaryButtonStyle`, `KGhostButtonStyle`, `KGlassButtonStyle`,
  `KGlassEffectContainer`: zero usages anywhere.
- `DesignSystem/SATCard.swift` — `satDarkCard()` unused.
- `DesignSystem/AppSpacing.swift` — `Avatar` and `Input` token enums unused.
- `Managers/NotificationManager.swift` — the task-notification block
  (`scheduleTaskNotifications`, `cancelTaskNotifications`,
  `rescheduleAllTaskNotifications`) is only called from dead ToDo/Tasks files,
  and `getPendingNotificationCount` has no callers at all. The "creative
  notifications" block IS live (called from `requestPermission`). Trimming
  the task block unblocks deleting `Views/Tasks/Task.swift`.

## Retirement order (dependencies)

1. Definitely-dead files + ToDo/Tasks + scanner + Study clusters
   (removes all users of `Theme.swift` and `NetworkMonitor.swift`)
2. `Theme.swift`, voice endpoints in `APIConfig.swift`
3. Trim `NotificationManager` task block → delete `Views/Tasks/Task.swift`
4. MathChat (small `SATHomeView` edit first)
5. Later, when the Firestore migration is retired: `DataMigrationManager`,
   `ConversationManager`, `StudyDataManager`, `FirestoreStudyService`

---

# Maintenance / code health (2026-07-17 audit)

Live code is in good shape overall: no TODO/FIXME markers, no force-unwrapped
URLs in live paths, almost no stray `print()`, and 15 of 19 managers carry
doc headers. Items worth fixing, roughly in priority order:

1. **ChatViewModel duplicates KorahAIClient's SSE streaming.**
   `ChatViewModel.swift:178–250` hand-rolls the same `data:`-line SSE parsing
   that `KorahAIClient.stream()` already provides (MathChatView uses the
   client). Consolidating deletes ~70 lines and leaves one place to fix
   streaming bugs.
2. **Desmos demo API key in production.** `DesmosWebView.swift:48` loads the
   calculator with Desmos's published demo key (`dcb31709…`), which is not
   licensed for production apps. Get a real key before a wider release.
3. **Shared components buried in feature view files** — move to
   `DesignSystem/`:
   - `SnapSlider` (bottom of `SATRushView.swift`, used by `ProfileView`)
   - `FlexibleChipLayout` (`SATRushView.swift`, used by `SATBankView`)
   - `KPinkButtonStyle` / `.kPink` (`SATPlayerView.swift`)
4. **Three parallel math/markdown rendering paths** in live code:
   `MathMarkdownWebView` (chat, marked+KaTeX web view), `LatexMarkdownView`
   (SAT explanation sheet, MarkdownUI), `HTMLContentView` (SAT question
   stems). If intentional, each file needs a short doc comment saying when
   to use which, so a fourth path doesn't appear.
5. **Missing doc headers** on `AuthManager` (the auth backbone),
   `AppleSignInCoordinator`, `NotificationManager`, and `StreakManager` —
   the only managers without them.
6. **`SATChatTheme.swift` is misnamed/misplaced** — it's live design support
   (accent palette, glass bar, starter prompts) sitting under `Views/Chat/`
   with a name that got it flagged as dead once already. Consider moving to
   `DesignSystem/` or renaming.
