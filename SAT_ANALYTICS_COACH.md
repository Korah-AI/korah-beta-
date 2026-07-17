# SAT Analytics → Korah Coach

A proposal for a small system that feeds a student's SAT analytics to Korah so
the model can (a) give personalized advice inside Math Chat and (b) periodically
refresh a short "coach summary" on the student's profile — where the *model*
draws the conclusion from current stats + progress trends, dated against the last
time it ran.

The point is not another dashboard. The student already sees their numbers. The
point is a running, plain-English read on *what the numbers mean and what to do
next* — the thing a human tutor does between sessions.

---

## 1. What we already collect

All of this exists today in Firestore via `SATAnalyticsService`
(`Korah (Beta)/Managers/SATAnalyticsService.swift`), mirrored with korah-web:

| Path | Shape | Useful signal |
|------|-------|---------------|
| `users/{uid}/satProfile/main` | `SATProfile` | current/goal score, math vs english split, `testDate`, `updatedAt` |
| `users/{uid}/satTotals/summary` | `SATTotals` | `answered`, `correct`, `incorrect`, `practiceTime`, `totalXP`, `level`, `lastActivity` |
| `users/{uid}/satSkills/{skillCd}` | `SATSkillStat` | per-skill attempts/correct, `byDifficulty`, `lastSeen` |
| `users/{uid}/satAttempts/{auto}` | append-only log | every attempt with `ts`, `correct`, `difficulty`, `skillCd`, `domain`, `timeSpent` |

The append-only `satAttempts` log is the key asset: it lets us compute **trends**
(this week vs last week, accuracy slope per skill, pace) rather than only
lifetime totals. Practice Rush already writes to this on every `check()`.

---

## 2. The idea in one line

> Roll the raw analytics into a compact **StudentSnapshot**, hand it to Korah,
> and let the model produce the conclusion — never hard-code the advice logic.

Two consumers of the same snapshot:

1. **Math Chat context** — inject the snapshot into the system prompt so Korah's
   answers are aware of the student's weak skills, goal gap, and test date.
2. **Coach summary** — a scheduled/triggered call that asks Korah to write a
   short dated summary + 2–3 next actions, stored back on the profile.

---

## 3. Build the snapshot (deterministic, cheap)

A new lightweight builder — `SATCoachSnapshot` — reads the collections above and
computes derived signals in Swift. Do the arithmetic here; leave the *judgement*
to the model.

```swift
struct SATCoachSnapshot: Codable {
    // Where they stand
    var currentScore: Int?
    var goalScore: Int?
    var mathScore: Int?
    var englishScore: Int?
    var daysUntilTest: Int?          // from profile.testDate

    // Volume & consistency
    var totalAnswered: Int
    var overallAccuracy: Double
    var practiceMinutes: Int
    var activeDaysLast14: Int        // distinct days with an attempt
    var attemptsThisWeek: Int
    var attemptsPrevWeek: Int        // momentum: up / down / stalled

    // Skill-level read (top few each way, not the whole list)
    var weakestSkills: [SkillLine]   // low accuracy AND enough attempts
    var strongestSkills: [SkillLine]
    var neglectedSkills: [SkillLine] // not seen in N days / never attempted
    var accuracyByDifficulty: [String: Double]  // E/M/H

    // Trend since last coaching
    var lastCoachedAt: String?       // ISO, from profile
    var accuracyDeltaSinceLastCoach: Double?

    struct SkillLine: Codable {
        var skillCd: String
        var name: String
        var domain: String
        var attempts: Int
        var accuracy: Double
    }
}
```

Guardrails so advice stays honest:
- A skill only counts as "weak" with a **minimum sample** (e.g. ≥ 5 attempts),
  otherwise it's "neglected," not "weak."
- Cap each skill list at ~5 entries so the prompt stays small and the model
  isn't tempted to list everything.
- Everything is derived from data already synced — no new writes on the hot path.

---

## 4. Consumer A — advice inside Math Chat

`MathChatModel` (`Korah (Beta)/Views/SAT/MathChatView.swift`) already builds an
`AIChatMessage(role: "system", …)` prompt. Append a compact, rendered form of the
snapshot to that system prompt when the student opens chat:

```
STUDENT CONTEXT (use to tailor tone and examples; don't recite it back):
- Goal 1400, currently ~1250 (math 640 / english 610), test in 23 days.
- 312 questions answered, 68% overall; hard-difficulty accuracy 41%.
- Weakest: Linear equations in two variables (54%), Inference (58%).
- Momentum: 40 attempts this week vs 12 last week (ramping up).
Prefer examples from weak skills. Be encouraging but specific.
```

The model then naturally says things like "since two-variable linear systems have
been tripping you up, let's do this one that way…" No new tools, no schema — just
richer context. Keep it advisory: instruct the model *not* to parrot the stats.

---

## 5. Consumer B — the dated coach summary

This is the "update their profile based on overall analytics" piece. A single
call, run occasionally, that lets the model reach a conclusion given the snapshot
**and** how long it's been since the last one.

### Trigger — pick one to start
- **On demand:** a "Get Korah's read" button on the SAT home / profile.
- **Passive/staleness-based (recommended default):** when the student opens SAT
  home, if `lastCoachedAt` is older than ~3 days **and** there's been new
  activity since, kick off a background refresh. Cheap, invisible, always fresh.
- Later: a scheduled cloud job for push-notification nudges.

### The request
Send the snapshot as JSON plus a tight instruction:

```
You are Korah, an SAT coach. Below is a JSON snapshot of one student's
progress, including the date you last coached them (lastCoachedAt) and how
their accuracy has moved since. Draw YOUR OWN conclusion — do not just restate
numbers. Return JSON:
{
  "headline":  "one warm sentence on where they are right now",
  "trend":     "improving | steady | slipping | just getting started",
  "focus":     ["2–3 concrete, skill-specific next actions"],
  "note":      "one honest line tying it to their goal and test date"
}
If little has changed since lastCoachedAt, say so plainly instead of inventing
progress.
```

Asking for **structured JSON** (not prose) keeps it renderable and lets us store
fields cleanly. The model owns `trend` and `focus` — that's the "let the AI come
up with a conclusion" requirement.

### Store it back
Write to a new sub-doc so it never collides with score fields:

```
users/{uid}/satCoach/latest
  { headline, trend, focus[], note, generatedAt, basedOnAnswered }
```

And stamp `satProfile/main.lastCoachedAt = generatedAt` so the next run can
reason about elapsed time and delta. Keeping a short history
(`satCoach/{autoId}`) would later let Korah say "last time I told you to drill
inference — you've moved from 58% → 71%. Nice."

### Surface it
A compact card on SAT home / profile:

```
🧭  Korah's read · updated 2d ago
"You're 150 points from your goal with 3 weeks left — very doable."
Trend: improving ↗
Do next:
  • 15 hard-difficulty algebra questions this week
  • Revisit inference questions — accuracy dipped
```

---

## 6. Why let the model conclude (vs. rules)

We *could* hard-code "if accuracy < 60% show 'focus on X'." We shouldn't:
- Trends are multivariate (accuracy vs pace vs time-left vs recency). A rules
  engine for that becomes brittle fast and reads robotic.
- The model can weigh "slipping on hard questions but ramping volume with 3 weeks
  left" into one human sentence — that's exactly its strength.
- Deterministic **inputs** (the snapshot) + model **judgement** (the conclusion)
  gives us reproducibility where it matters and nuance where it helps.

---

## 7. Scope / rollout

1. **Snapshot builder** — `SATCoachSnapshot` from existing Firestore data. No
   schema changes, no hot-path writes. *Verify:* unit-test derived fields (weak
   vs neglected thresholds, week-over-week counts) against a seeded attempt log.
2. **Math Chat context** — inject rendered snapshot into the system prompt.
   *Verify:* chat references a real weak skill for a seeded profile.
3. **Coach summary** — one structured call → `satCoach/latest`, stamp
   `lastCoachedAt`, staleness trigger on SAT home. *Verify:* re-running with no
   new activity yields a "not much has changed" summary, not fabricated gains.
4. **Card UI** — render `satCoach/latest` on profile / SAT home.

Steps 1–2 are independently shippable and low-risk; 3–4 build on the snapshot.

### Cost / privacy notes
- One summary every few days per active student is negligible token cost; the
  snapshot is intentionally small (~a few hundred tokens).
- Never send raw PII — the snapshot is scores and skill codes, no names/emails.
- All source data is already the student's own, already synced with korah-web.
