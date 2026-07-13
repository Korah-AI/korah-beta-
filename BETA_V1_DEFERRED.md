# Deferred features — Korah iOS v1 (SAT-first release)

Decisions recorded 2026-07-12 while implementing `BETA_UPDATE_PLAN.md`.

## Tasks / To-Do — deferred, code kept
Per product decision: **defer, but keep the code in the project.**

- `Views/ToDo/ToDoListView.swift`, `Views/Tasks/*` (Task model, Add/EditTaskView, MoodHelpers)
  and `Views/homepage/HomeDataManager.swift` still compile and work, but are **not linked
  from the v1 tab bar** (`Views/MainTabView.swift`: SAT · Ask Korah · Study · Profile).
- To re-enable: add a tab (or a Study-tab entry point) that presents `ToDoListView()`.
- Task data still lives in UserDefaults via `HomeDataManager` (`korah`-local, not synced).

## Focus Timer + widget — dropped from v1 (deleted)
- Deleted `Views/ToDo/Timer/` (`FocusTimerView`, `CompactStudyTimerView`,
  `FloatingTimerIndicator`) and the `FocusTimerWidget/` folder; removed the
  ActivityKit/WidgetKit references from the Xcode project.
- `ToDoListView` had its embedded quick-start timer UI removed (marked with a
  comment pointing here).
- To restore: recover the files from git history and re-add a widget extension target.

## Study generation — partial /api/generate-study-item adoption
- **Flashcards** prompt generation now goes through `StudyGenerationService`
  (`POST /api/generate-study-item`, `/api/r` fallback — same as web study-api.js).
- **Study guides and practice tests** stay on their existing `/api/r` JSON contracts:
  the beta's viewers render a structured-JSON guide format (`StudyGuide.content`)
  and an index-based test format (`PracticeTestQuestion.correctIndex`) that don't
  match the web's `markdown` / `answer`-string shapes. Aligning those models with
  the web (for true cross-platform study items) is follow-up work.
- File/photo attachments for generation (web supports base64 images/PDFs) are not
  wired into `generate-study-item` yet; the Scan flows send images via `/api/r`.

## Other v1 scope notes
- Mood check-in still exists inside `ToDoListView`'s mood picker (deferred with tasks).
- Voice features in `ScanView` (`/api/transcribe`, `/api/speak`) still point at the
  legacy `korah-beta.vercel.app` deployment (`APIConfig.legacyBaseURL`) because the
  canonical korah-web deployment does not serve them.
- Old `HomePageView` shell and `MainAppView` stub were deleted (replaced by `MainTabView`).
