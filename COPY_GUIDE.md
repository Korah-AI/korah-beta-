# Korah Copy and Voice Guide

How Korah talks. The app sounds like a friendly coach sitting next to the
student: warm, direct, a little playful, never robotic. All examples below
are real strings from the live app; match them.

## Hard rules

1. **No em dashes. Anywhere.** Not in UI strings, not in AI prompts, not in
   notifications. Use a comma, a period, or a colon instead. For compact
   metadata separators use the middot: `3/4 · 75%`, `Algebra · Geometry`.
2. **Sentence case** for titles, buttons, and body copy ("Pick your
   topics", "Back to setup"). The only exception: tiny ALL CAPS eyebrow
   labels on demo/stat cards ("TEST DAY COUNTDOWN", "YOUR TARGET").
3. **Contractions always.** "Let's go", "that's +120 points", "I've taken
   the SAT". Spelled-out forms sound like a manual.
4. **Talk to "you".** The student is you, Korah is your coach. Never "the
   user" or passive voice.

## Patterns

### Titles ask questions

Setup and choice screens use a direct question, not a label:

- "What do you want to practice?"
- "Pick your topics"
- "When are you taking the SAT?"
- "Where are you starting from?"
- "Where do you want to be?"

Not: "Subject selection", "Topic preferences", "Difficulty settings".

### Buttons are short verbs

Check · Continue · Next · Back · Retry · Let's go · Keep going ·
See results · Practice again · Back to setup · Start Rush

One or two words when possible, never "Click here to..." or "Submit".

### Praise rotates, and it's earned

Correct answers pull from a pool so it never repeats stale:
"Nicely done!", "Great job!", "You nailed it!", "Perfect!", "Keep it up!"

Streaks of 5+ get the special line: "5 in a row! 🔥"

Emoji: sparing and purposeful. 🔥 belongs to streaks. Do not sprinkle emoji
on ordinary labels.

### Wrong answers inform, never scold

Show the fact and move on: "Correct answer: B" plus the explanation. No
"Oops", no "Wrong!", no "Better luck next time".

### Numbers are framed as progress

- "that's +120 points" (gains, with a plus sign)
- "You answered 12 questions. Keep the streak going!"
- Pluralize properly: `"question\(count == 1 ? "" : "s")"`. Never "1
  questions" or "question(s)".

### Empty and error states stay calm and give one way out

- "No questions matched those filters." + Back to setup
- Error text comes from the actual error, followed by Retry. No blame, no
  drama, no error codes in the user's face.

### Confirmations offer choices in the user's words

"End this rush?" with "See results" and "Keep going". Not "Are you sure?"
with "OK" and "Cancel".

### Feature blurbs sell the benefit in one line

- "Your personal SAT coach. Set a goal, practice smart, and watch your
  score climb."
- "Algebra, advanced math, data analysis, and geometry"
- "Race the clock in Practice Rush"
- "Stuck? Ask Korah"
- "And it's all 100% free"

## Robotic vs human (rewrite table)

| Robotic | Korah |
|---|---|
| An error occurred while fetching questions. | Couldn't load questions. Retry? |
| Select your desired difficulty level. | Choose difficulty |
| Incorrect. The correct answer was B. | Correct answer: B |
| Congratulations on completing the session! | Rush complete! |
| You have answered 12 questions | You answered 12 questions. Keep the streak going! |
| Please configure your practice preferences | What do you want to practice? |

## AI-generated text

Chat replies and explanations come from the model, so the system prompts
must carry these rules too. When writing or editing prompts (ChatViewModel,
SATExplanationService, MathChat), include: no em dashes, contractions,
sentence case, encouraging coach tone, and short direct sentences.
