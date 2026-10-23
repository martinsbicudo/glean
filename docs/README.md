# Glean documentation

Technical documentation for Glean. To install or build it, start with the
[project README](../README.md); for day-to-day use, the [guide](guide.md).

| Page | What it covers |
|---|---|
| [guide.md](guide.md) | Using Glean: spaces, adding cards, reviewing, pronunciation, where your files are |
| [architecture.md](architecture.md) | Components, data files, the review and AI flows, the file map |
| [ai.md](ai.md) | Claude Code and Codex: exact commands, the prompts, JSON formats, fallback |
| [development.md](development.md) | Building, testing (including the live AI and speech tests), the no-Xcode rules |
| [troubleshooting.md](troubleshooting.md) | Logs, permissions, common errors |
| [../brand/BRAND.md](../brand/BRAND.md) | Logo, colours, icon files |

## Fixed product decisions

Chosen on purpose. Keep them unless the owner decides otherwise:

- **Any language, one space each.** A space has its own study language, native language, level, goal and
  files. Glean never reads meeting notes or anything outside its own folder.
- **AI only through Claude Code or Codex**, with the user's own login. No API keys, no local models.
  "None" must keep working: every AI button is optional.
- **The scheduler is deterministic (SM-2).** The AI never changes intervals. It reads the review
  history to coach and to write new cards.
- **Pronunciation through Apple's on-device recognizer** (`SpeechAnalyzer`, macOS 26+). It measures
  whether you were understood, word by word. Glean must never claim it grades phonemes. Shadowing
  (speak, then record automatically) uses the same scoring.
- **Plain files in `~/Glean`.** JSON the user can read, edit and back up. Spaces are never deleted, only
  moved to `~/Glean/Trash`.
