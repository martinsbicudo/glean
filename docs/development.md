# Development

| Command | What it does |
|---|---|
| `make install` | `scripts/build-app.sh` (release build, bundle, sign) then `scripts/install-app.sh` (replace `/Applications/Glean.app` and relaunch) |
| `make test` | Unit tests |
| `make icons` | Rebuild brand SVGs, `Resources/AppIcon.icns` and the menu bar PNGs from `brand/generate.py` |
| `swift build` | Debug build only |

## Building without Xcode

Only the Command Line Tools are installed, and they don't ship SwiftUI's macro plugin. So:

- **Don't use `@State`** (it is a macro now). Keep view state in a small `ObservableObject` class with
  `@Published` properties, held by `@StateObject private var ui`. See any view for the pattern.
- `@StateObject`, `@Environment`, `@Binding`, `@Bindable`, `@FocusState` and `@Observable` work.
- No `#Preview`.
- With only the Command Line Tools, Swift Testing's macros are found only with an explicit plugin path.
  `make test` adds `-Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`
  when the active developer directory is the Command Line Tools (not with Xcode);
  use the same flags when calling `swift test` directly.

## Tests

Swift Testing in `Tests/GleanTests`:

| Suite | Covers |
|---|---|
| `SchedulerTests` | SM-2 intervals, lapses, minimum ease, preview labels |
| `PronunciationScoreTests` | Alignment, punctuation/case, missing words, word order |
| `SpaceStoreTests` | Spaces round trip, select, edit, delete to Trash (same name, `/`), unreadable `spaces.json`, due counts across spaces, language list |
| `LegacyMigrationTests` | The migration: happy path, setting mapping, every guard and injected failure, orphan folders, retry |
| `AddChatTests` | Chat reply parsing (message + cards, cards only, prose around, junk JSON first), history formatting and its 10-turn limit, duplicate filtering, the chat prompt |
| `RecallTests` | Review direction (Mixed by reps), cloze blanking (case, multi-word, inflections, no match), typed answer comparison |
| `SentenceTests` | Sentence-check reply parsing, `ReviewEntry` backward-compatible decoding, `StudyReport` writing mistakes, `Space` without a direction decoding as Mixed |
| `AIJSONTests` | JSON inside prose or fences, other JSON in the prose skipped, arrays, single cards, fill keeps identity and schedule, coach report |
| `CardStoreTests` | Dedupe, persistence, review log and stats, hand-written `cards.json` |
| `RemindersTests` | Reminder plan across spaces only when due, ordering, notification text, streak text only at the last hour today when nothing was studied |
| `StudyProgressTests` | Streaks across midnight, gaps, today not studied yet, best streak, injected time zones, goal, retention (30 days, per space), 30-day series with empty days, multi-space aggregation, sentence and pronunciation entries excluded, read-only snapshots |
| `ShadowTests` | Duration estimate and auto-stop (× 1.6 + 1 s), phrases of a card, sequence advance, start offset, per-phrase scores |
| `SettingsTests` | Reminder-hour parsing, engine order, loose kind names |
| `CoachDataTests` | The coach's study report, insights saved (and refused outside `spaces/`) and fed back into prompts, learner profile, chat context |
| `AgentCLITests` | Exact Claude Code and Codex arguments, Claude Code result and error parsing |

Every test uses a temporary root directory and its own `UserDefaults(suiteName:)`. No test (apart from the
opt-in live ones, which also use temporary folders) may touch `~/Glean` or a default data directory: there
is none, `CardStore`, `InsightsStore` and `SpaceStore` always take their location as an argument.

Opt-in live tests (they call the real CLIs or speech models, so they are skipped by default):

```bash
GLEAN_LIVE_AI=1 make test       # chats for cards, checks a sentence and answers a question with Claude Code, completes a card with Codex
GLEAN_LIVE_SPEECH=1 make test   # speaks a phrase with `say`, transcribes it with SpeechAnalyzer, scores it
```

## Signing

`scripts/build-app.sh` signs with the identity set in `scripts/signing.local.env` (ignored by git;
`scripts/signing.env` loads it). Set `SIGN_IDENTITY`, `SIGN_KEYCHAIN` and, if the keychain is locked,
`SIGN_KEYCHAIN_PASSWORD`. Without it, the build is ad-hoc signed and macOS asks for microphone and
notification permission again after every rebuild.

## Common changes

| Change | Where |
|---|---|
| Card fields | `Card` (+ its lenient `init(from:)`), `CardDraft`, `Prompts.cardSchema`, `CardDetails`, `CardEditor` |
| Prompts | `Prompts.swift` |
| Scheduling | `Scheduler.swift` and `SchedulerTests` |
| Languages | `Language.all` |
| Where data lives | `SpaceStore` (never build a `CardStore` outside it) |
| Reminder rules | `PlannedReminder.plan` and `RemindersTests` |
| Colours | `brand/generate.py` (icons) and `Brand.swift` (UI) |
