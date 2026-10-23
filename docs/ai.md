# AI: Claude Code and Codex

Glean never holds an API key. It runs the CLI the user already signed in to, headless, with no tools,
and reads the answer.

## Choosing the engine

Settings ▸ AI ▸ **Connect to**: `None (manual)`, `Claude Code` or `Codex`. With a CLI chosen, Glean
tries it first and falls back to the other one if it's installed. With None, the AI buttons are
disabled and explain how to connect.

Binaries are looked up in `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin` and `~/.local/bin`.
An optional model name per engine can be set in Settings (empty = the CLI's default).

## Exact commands

Claude Code (system prompt as an argument, message on stdin):

```
claude -p --output-format json --setting-sources project --strict-mcp-config --no-session-persistence \
  --tools "" --system-prompt <system> [--model <model>]
```

Codex (system prompt and message together on stdin, answer read from a file):

```
codex exec --skip-git-repo-check --ephemeral --ignore-user-config --ignore-rules -s read-only \
  -C <temp dir> -o <temp dir>/answer.md [-m <model>] -
```

Both run in a fresh temporary directory that is deleted afterwards.

## The actions (`Tutor`)

| Action | Where | Prompt | Answer |
|---|---|---|---|
| Add cards (chat) | Add with AI | `Prompts.addChatSystem` + learner, terms already in the space, the last 10 turns (`AddChat.history`), the new message | `{"message": "...", "cards": [card]}` |
| Check a sentence | Review side panel | `Prompts.sentenceSystem` + learner, the term and its translations, the sentence | `{"ok", "corrected", "explanation", "better"}` |
| Complete a card | Card editor | `Prompts.fillSystem` + the card so far | one card object |
| Ask about a card | Review and Cards side panel | `Prompts.askSystem(profile:)` + card, the learner's history with it, the conversation so far | plain text (inline Markdown rendered) |
| Coach | Coach ▸ Analyze with AI | `Prompts.coachSystem` + `StudyReport` + terms already in the deck | `{"summary", "weaknesses", "tips", "cards"}` |

The prompts are generic over the space: `LearnerProfile` names the language being studied (with its locale),
the native language and the level, and every prompt refers to "the language being studied" instead of a
fixed language.

### Add-cards chat

The learner's message is wrapped in `<<< >>>`; the history lists each turn as `Learner: ...` or `Tutor: ...`
and, for a tutor turn with cards, `(cards shown: 1. term; 2. term)` so "make #3 easier" can be resolved.
Only the last 10 turns are sent. `AIJSON.chat` accepts `{"message", "cards"}`, cards only
(`{"cards": [...]}`), a bare array or a single card, and a message with no cards; JSON elsewhere in the
reply that is none of those is skipped. A reply that isn't JSON at all is shown as plain text. Cards whose
term is in the space (or repeated within the reply) are dropped before the preview; if that drops every
card the message says so. The preview ticks all cards; **Add N cards** adds the ticked ones. The
conversation is kept per space while the app runs and cleared with **New Chat**.

### Sentence check

`{"ok": true|false, "corrected": "minimal fix, same sentence when ok", "explanation": "native language",
"better": ["up to 2 more natural options"]}`. `ok` is required; the other fields default to empty. Each check
is appended to `reviews.jsonl` as an entry with `sentence` and `sentenceOK` and no rating, so it doesn't
count as a review. `StudyReport` lists the 10 most recent incorrect sentences for the Coach.

Card JSON (`Prompts.cardSchema`): `term`, `kind`, `translations` (2–5 in the native language),
`meaning` (native language), `definition` (simple, in the language being studied), `pronunciation` (IPA for
the locale), `examples` (5+), `source` (the cleaned sentence from the pasted text), `tags`.

`AIJSON.candidates` lists every balanced `{…}` or `[…]` in the reply that is valid JSON (brackets
inside strings are ignored). The parsers take the first candidate with the expected shape (cards, or a
non-empty coach report), so code fences, a stray sentence or prose like `Step [1]` around the JSON
don't break parsing. Nothing is saved before the learner ticks cards and presses Add.

## How the AI "learns" the learner

The scheduler doesn't change. What adapts is the content:

1. Every rating and pronunciation attempt goes to the space's `reviews.jsonl`.
2. **Analyze with AI** sends a `StudyReport`: totals, per-kind forgotten/hard counts, the 15 hardest
   cards, recent pronunciation misses with what the recognizer heard, and recent incorrect sentences.
3. The coach answers with a summary, weak spots, tips and up to 6 new cards for those weak spots.
4. The weak spots and summary are added to the learner profile in every later prompt (`InsightsStore.profileNotes`),
   so answers in the chat and newly generated cards focus on them. Each space has its own coach report.
