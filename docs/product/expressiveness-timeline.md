# Expressiveness timeline table

Maps user question cues → `AnswerShape` → generation directive → rendered format. Enforced by `ExpressivenessTests` and `ProductDocTests`.

## Detection rules (`AnswerShape.detect`)

| Shape | Trigger cues (substring) | Example query |
|-------|-------------------------|---------------|
| `comparison` | compare, vs, differ, contrast | "compare Bazel and CMake" |
| `timeline` | timeline, chronolog, history of, over time | "what's the timeline of the migration?" |
| `list` | list, what are, which, blockers | "list the blockers" |
| `definition` | what is, who is (lookup intent) | "what is Bazel?" |
| `synthesis` | default | "summarize the incident" |

## Directive → render

| Shape | Prompt directive contains | Offline render (`NotchReducer.expressivenessShape`) |
|-------|----------------------------|-----------------------------------------------------|
| `comparison` | "table" | Markdown `\| Item \| Detail \|` table |
| `timeline` | "chronolog" | Numbered list `1. … 2. …` |
| `list` | bullets | `- item` lines |
| `definition` | one-liner | Prose |
| `synthesis` | structured prose | Semicolon-joined or paragraphs |

## Timeline example (Aurora fixture)

**Query:** "How many weeks did the Aurora migration slip?"

| # | Source | Fact | `updatedAt` |
|---|--------|------|-------------|
| 1 | timeline-a | Planned May 5 | 2026-04-01 |
| 2 | timeline-b | Slipped to May 19 | 2026-05-15 |
| 3 | timeline-c | Started June 2 | 2026-06-30 |

**Shape:** `.timeline` or `.synthesis` depending on intent.  
**Tests:** `TimelineBuilderTests`, `SmarterThanSiriTests` B53, `NumericReasonerTests`.

## Expressive events in stream

| Event | UI effect | Test |
|-------|-----------|------|
| `.understanding("…")` | Status before answer | `ExpressiveReducerTests` |
| `.suggestions([…])` | Follow-up chips | `FollowUpTests` |
| `.reasoning([…])` | Visible steps (mnemoctl) | B56 |
| `.related([…])` | See-also cards | — |

## Tone overlay (`/tone brief|balanced|detailed`)

Modifies directive length, not shape. `ResponseToneTests`.
