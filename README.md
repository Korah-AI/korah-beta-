[KORAH APP](https://korah.app)
=========

A free AI-powered tutoring and study app made for underrepresented students.


FEATURES
--------
- AI Tutor Chat: Text and voice conversations with guided learning
- Study Tools: Flashcards, study guides, and practice tests
- Document Scanning: Take pictures of documents to receive extra help
- Task Management: To-do lists with Pomodoro timer
- Mood Tracking: Focus level check-ins for personalized task recommendations

DEVELOPMENT
-----------
- Languages: Swift, JavaScript.
- API: OpenAI; GPT-4o (will be changed for better latency). Proxied via Vercel in backend.

SAT QUESTION BANK FILTERS
--------------------------
`SATBankView.swift` (mobile) previously had a "Filters" button in the top
right that opened a sheet (`SATBankFiltersSheet`). That sheet is gone; it's
been replaced with a filter bar matching the web version (`sat/index.html`,
not part of this repo): a "Question Limit" dropdown + a "Filters" toggle
that reveals a chip row — **Question set, Difficulty, Time Spent, Saved,
Completed, Result** — plus "Reset filters".

- **Question set** → `bank.assessment` (`SATCatalog.assessments`: SAT /
  PSAT/NMSQT / PSAT). Also bound in `ProfileView.swift`.
- **Difficulty** → `bank.selectedDifficulties` (E/M/H) via `SATCatalog.difficulties`.
- **Question Limit** → `bank.limit`.
- **Saved / Completed / Result / Time Spent** → new state on `SATBankStore`
  (`savedOnly`, `completionFilter`, `resultFilter`, `timeSpentFilter`). These
  have no server-side support — the College Board question API only knows
  sections/domains/skills/difficulties/assessment/limit — so they're applied
  as a client-side post-fetch filter. `SATBankStore.loadProgress()` now also
  loads `SATAnalyticsService.getLatestOutcomes()` (per-question
  correct/timeSpent from `satAttempts`) and `getBookmarks()` (`satBookmarks`)
  into `outcomes`/`bookmarkedIds`; `SATBankStore.matchesQuestionFilters(_:)`
  checks a fetched question against the active filters, and
  `SATPlayerSession.load()` (`Managers/SATPlayerSession.swift`) filters
  `response.questions` through it right after fetching, before anything is
  shown to the player.

Caveat: `bank.limit` is a server-side cap applied *before* the client-side
Saved/Completed/Result/Time Spent filter, so combining a small limit with one
of those filters can yield fewer questions than the limit (or zero) — there's
no way around this without the API supporting these filters directly.

`bank.resetFilters()` only clears the filter bar (assessment, difficulty,
limit, and the four question-level filters) — it leaves the topic accordion's
`selectedSkills` alone, since topic selection is a separate concern from
these filters.

<h1> Todo List </h1>

<ul>
  <li> Update prompting to be better, longer, etc. Right now, it is too strict and concise. Render as markdown instead of JSON. </li>
  <li> Screen Time Features (Must request from Apple. May add "paid" tier for acceptance) </li>
  <li> Live Activities + Notifications </li>
  <li> Either update or remove Tasks section </li>
  <li> Switch to Responses API to update model to GPT-5-Nano </li>
  <li> Implement auto-cropping like Gauth </li>
  <li> Add text streaming for API </li>
  <li> Update loading screens </li>
  <li> Take notes from StudyFetch </li>
  <li> Take Jayden's overall feedback @feedback.md </li>
  <li> Make .env file for the API Key in a .gitignore file to reduce latency? </li>
  <li> Make outline for web version </li>
  <li> Korah AP/SAT? (use webscrapers and Vapi for tailoring? </li>
</ul>

<h1>Main Priorities</h1>
<ul>
  <li> Update A.I. responses, speed, latency, and streaming. </li>
  <li>Implement Screentime Features. </li>
  <li>Begin Website Development</li>
  <li>Update U.I. (Gauth/StudyFetch Inspired)</li>
  <li>Update daily notifcations</li>
</ul>

