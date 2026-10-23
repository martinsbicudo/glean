# Architecture

Glean is a single Swift Package Manager executable (`Sources/Glean`), wrapped into a signed `.app` by
`scripts/build-app.sh`. It is a regular Dock app with one main window, a menu bar extra and a Settings
window, all SwiftUI (`GleanApp.swift`).

- Swift tools 6.2, Swift 5 language mode, minimum macOS 26 (for `SpeechAnalyzer`).
- Builds with the Command Line Tools only. That rules out SwiftUI's `@State` macro; see
  [development.md](development.md).
- No third-party packages. External tools: the `claude` / `codex` CLIs, both optional.

## Data

All in `~/Glean` (`SpaceStore.productionRoot`; tests always pass a temporary root):

| File | Written by | Format |
|---|---|---|
| `spaces.json` | `SpaceStore`, atomically | `{"version": 1, "spaces": [Space], "selected": UUID}` |
| `spaces/<uuid>/cards.json` | `CardStore.save()`, atomically on every change | `{"version": 1, "cards": [Card]}`, pretty, sorted keys, ISO 8601 dates |
| `spaces/<uuid>/reviews.jsonl` | `CardStore.append` | one `ReviewEntry` per line: a rating, or a pronunciation score + what was heard, or a written `sentence` + `sentenceOK` (the three kinds of fields are all optional, so older lines decode unchanged) |
| `spaces/<uuid>/insights.json` | `InsightsStore.save` | the latest `CoachReport` |
| `Trash/<uuid>-<yyyyMMdd-HHmmss>/` | `SpaceStore.delete` | a deleted space's folder plus `space.json` with its name |

A `Space` is `{id, name, target, native, level, dailyGoal, direction, created}`. `target` and `native` are BCP-47
locales from the one `Language` list (`Language.swift`); they must differ by base language. `target` is also
the locale for speech and text to speech. `direction` is a `ReviewDirection` (`recognize`, `recall`, `mixed`); a `spaces.json` written before it existed decodes with `mixed`, and unknown values do too. `CardStore(directory:)` and `InsightsStore(directory:)` have no
default directory: `AppModel` builds them only from `SpaceStore.directory(for:)`. `InsightsStore` refuses to
write outside a `spaces/` folder. Nothing writes the old root files `~/Glean/cards.json`, `reviews.jsonl` and
`insights.json` any more; they are only read, once, by the migration.

### Data state

`SpaceStore.state` is a `DataState`: `ready(Space)`, `noSpaces`, `migrationNeeded`, `spacesUnreadable` or
`orphanedSpaces`. `AppModel.store` and `AppModel.insights` exist only in `ready`; otherwise the window shows
a message with Reload and Open Folder. `SpaceStore.create` throws, and "New Space…" is disabled, unless the
state is `ready` or a real `noSpaces` (no `spaces.json`, no legacy `cards.json`, no space folders).

### Migration from the single-deck layout

`LegacyMigration.run` runs on launch and on Reload when `spaces.json` doesn't exist:

1. Orphan guard, before anything else: a folder in `spaces/` that isn't `.migrating-*` means `spaces.json`
   was lost. Nothing is written (`orphanedSpaces`).
2. Leftover `.migrating-*` folders are removed. No `cards.json` in the root: nothing to migrate (`noSpaces`).
3. The legacy `cards.json` is decoded; failure stops here (`migrationNeeded`).
4. `cards.json`, `reviews.jsonl` and `insights.json` are copied into `spaces/.migrating-<uuid>/`, each copy
   is compared byte for byte with its source, and the copied `cards.json` must have the same card count.
5. The folder is renamed to `spaces/<uuid>/` and `spaces.json` is written last, with one "English" space.
   If that write fails, the renamed folder is removed again. Any earlier failure removes the staging folder.

The space's target is the old `accent` setting when it was an English locale, else `en-US`; the native
language comes from the old `nativeLanguage` mapped to a locale (unknown: `pt-BR`); the level from `level`.
Those `UserDefaults` keys are read raw and never removed. The legacy files are never modified or deleted.
File operations are injectable (`MigrationFileOps`) so the tests can make each step fail.

Settings live in `UserDefaults` (`AppSettings`): engine, models and reminders. Language, level and daily goal
belong to the space.
`Card` and `CardFile` decode leniently: every field except `term` is optional, `kind` accepts loose
names ("phrasal verb", "expression"). Cards are deduplicated by `Card.normalize(term)` (lowercase,
no accents, no punctuation).

Settings live in `UserDefaults` (`AppSettings`): engine, models, native language, level, accent,
reminder hours.

## Components

| File | Responsibility |
|---|---|
| `GleanApp.swift` | Scenes (main window, menu bar extra, Settings), the menu bar menu, the sidebar |
| `AppModel.swift` | Owns settings, the `SpaceStore`, the selected space's stores, speaker and reminders; due counts and Dock badge across all spaces; reschedules reminders on every change |
| `Language.swift` | `Language` (locale, native name, English name) and `Level` |
| `Space.swift` | `Space`, `SpacesFile`, `DataState`, `SpaceError`, folder paths |
| `SpaceStore.swift` | Spaces CRUD, selection, Trash, `spaces.json` |
| `SpaceSnapshots.swift` | Read-only view of every space's cards: `snapshots()`, `dueCounts()` |
| `LegacyMigration.swift` | The one-time move of the old single-deck files into a space |
| `SpaceViews.swift` | Space picker, New/Edit space sheet, the empty / migration / read-only messages |
| `Card.swift` | `Card`, `CardKind`, `Schedule`, normalisation, lenient decoding |
| `Scheduler.swift` | `Rating` and SM-2: `review(_:rating:at:)`, `preview` labels |
| `CardStore.swift` | Loads and saves cards and reviews, add/update/delete/review, stats |
| `ReviewLog.swift` | `ReviewEntry`, per-card `CardStats` |
| `Settings.swift` | `AIEngine`, `AppSettings` |
| `AgentCLI.swift` | Runs Claude Code or Codex headless without tools, chosen engine first, then the other |
| `Prompts.swift` | Every prompt and the card JSON schema |
| `CardDraft.swift` | The AI's card format, coach report, `AIJSON` (finds the JSON in a reply) |
| `Tutor.swift` | The AI actions: add-chat, fill, ask, check a sentence, coach |
| `AddChat.swift` | `AddTurn`, `ChatReply`, `AIJSON.chat`, the chat history sent to the AI and duplicate filtering |
| `ReviewDirection.swift` | `ReviewDirection` and which side (recognize or recall) a card is shown on |
| `Recall.swift` | `Cloze` (blank the term in an example), `AnswerCheck` (✓ / close / ✗) |
| `SentenceCheck.swift` | The AI's verdict on a learner's sentence and its parser |
| `InsightsStore.swift` | Latest coach report; the notes fed back into every prompt |
| `StudyReport.swift` | Turns cards + history into the text the coach reads |
| `Speech.swift` | `Speaker` (system voices) and `PronunciationRecorder` (mic → file → `SpeechAnalyzer`); `Speaker` also reports when an utterance finishes |
| `Shadow.swift`, `ShadowSession.swift`, `ShadowControls.swift` | Shadowing: `Shadow` (pure: duration estimate, auto-stop, phrases of a card), `ShadowSequence` (pure: index, per-phrase scores, advance), `ShadowSession` (speak, record, auto-stop, score) and its view |
| `StudyProgress.swift`, `ProgressViews.swift` | `StudyProgress` (pure: goal, streaks, 30-day series, retention), the goal ring and the Coach's progress section |
| `PronunciationScore.swift` | Word-by-word alignment (LCS) of the target and what was heard |
| `Reminders.swift` | `PlannedReminder.plan` (pure) and the `UNUserNotificationCenter` scheduling |
| `ReviewView.swift`, `CardsView.swift`, `CardEditor.swift`, `AddChatView.swift`, `CoachView.swift`, `SettingsView.swift` | Screens |
| `CardContentView.swift`, `RecallFront.swift`, `ChatPanel.swift`, `SentencePanel.swift`, `PronunciationPanel.swift` | Shared card pieces, the recall front and side panels |

## Review flow

`ReviewView` shows the selected space's `store.dueCards().first` on the side chosen by
`space.direction.side(for: card)`: Recognize shows the term; Recall shows `RecallFront` (translations,
meaning, the first example where `Cloze.blank` finds the term, optional typed answer). Mixed uses Recognize
while `schedule.reps < 2`, then Recall on even `reps` and Recognize on odd. There is one schedule per card.
Flipping a Recall card with a typed answer shows `AnswerCheck.compare` (normalised with `Card.normalize`
after dropping apostrophes; a Levenshtein distance up to `length / 6`, at least 1, for terms of 4+ characters
is "close"). In Recall the shortcut for Show answer is Return, because Space would type a space in the field.
Space flips, 1–4 call `store.review(id, rating:)`, which
runs `Scheduler.review`, saves `cards.json` and appends to `reviews.jsonl`. "Again" brings the card back
in 10 minutes, so it returns in the same session once due.

SM-2 details: Hard ×1.2 and ease −0.15; Good 1 d, then 3 d, then × ease; Easy 4 d, then × ease × 1.3
and ease +0.15; Again resets reps, ease −0.2 (minimum 1.3) and counts a lapse if the card had been
learned.

## Shadowing

The "Shadow" button in `PronunciationPanel` hands `Shadow.phrases(for:)` (the term, then the examples) to a
`ShadowSession`. For each phrase it calls `Speaker.sayAndWait`, whose continuation is resolved by
`AVSpeechSynthesizerDelegate` (`didFinish`, or `didCancel` with `false`), then starts the recorder and arms
a timer of `Shadow.autoStop(for:)` = estimated duration × 1.6 + 1 s (estimate: the larger of words / 2.5 and
non-space characters / 15 per second). The timer or the Stop button calls `finishListening()`, which
transcribes, scores with `PronunciationScore.compare`, stores the score in the `ShadowSequence` and calls
`store.recordPronunciation`. Next moves the sequence on. A generation counter makes any stale speech,
recording or timer result a no-op; changing card, leaving the panel or exiting calls `cancel()`, which stops
speech, the timer and the recorder.

## Progress

`StudyProgress(spaces:now:calendar:)` is pure. Its input is `[SpaceReviews]` from
`SpaceStore.reviewSnapshots()`, which reads every space's `reviews.jsonl` through `CardStore.readReviews`
and never writes. Only entries with a `rating` count as reviews (sentence checks and pronunciation
attempts don't). Days are the injected calendar's local days. The streak is the run of consecutive days
with at least one rating in any space, ending today, or yesterday when nothing was studied yet today.
The goal compares today's ratings in the space with `Space.dailyGoal`. The 30-day series covers today and
the 29 days before it, with empty days as 0; retention is the share of ratings other than Again (Hard, Good, Easy) in the same
window, per space. `AppModel.refresh()` (every store change and every minute) rebuilds it.

## Reminders

On every store change and on settings changes, `AppModel.refresh()` asks `PlannedReminder.plan`, over the cards
of all spaces, which of the next 7 days × chosen hours have due cards (using the current schedules); the
notification names each space and a few of its terms. It removes the pending
`glean-reminder-*` notifications and adds the new ones. No reminder fires when nothing is due. The last configured hour of today also carries `streakDays` when
`StudyProgress` says nothing was studied today and the current streak is above zero; the text then asks to
study to keep the streak. Other hours and later days never do. Clicking
one opens Glean on Review.

## AI flows

See [ai.md](ai.md). Every AI call goes through `Tutor` → `AgentCLI`. The learner profile in every prompt
includes the language being studied, the native language, the level and the weak spots from the latest coach report, so the
AI's answers and new cards adapt to what the learner struggles with.
