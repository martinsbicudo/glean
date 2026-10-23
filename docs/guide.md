# Using Glean

How to set Glean up and study with it. To install or build it, see the [project README](../README.md).

## First run

1. Open **Glean ▸ Settings** (⌘,):
   - **Connect to:** Claude Code, Codex, or None (manual). Glean shows whether it found the CLI.
   - **Reminders:** pick the hours.
2. Create a space (**New Space…** in the picker at the top of the sidebar): a name, the language
   you're learning, your own language (translations go there), your level, a daily goal and the review direction (below). Use
   **Edit Space…** to change them later, or to delete a space (its folder moves to `~/Glean/Trash`).
3. Add cards:
   - **Add with AI:** a chat. Ask for cards ("10 phrasal verbs for travel"), paste a text, or ask for
     changes ("make #3 easier"). Each answer comes with a list of cards, all ticked: untick what you
     don't want and press **Add N cards**. Terms already in the space are left out. The last 10 turns
     are sent every time, so follow-ups work. Without a connected AI the screen explains how to connect
     one and offers **New Card**.
   - **Cards ▸ +** (⌘N) adds a card by hand. **Complete with AI** fills in the rest from just the term.
4. Review every day. Space shows the answer, 1–4 answer it.

## Review direction

Each space has a **Review direction** (New / Edit Space):

- **Recognize:** you see the term and remember what it means.
- **Recall:** you see the translations, the meaning and an example with the term blanked out, and
  remember the term. You can type it (optional): after you show the answer you get a check, a
  "close" or a cross (case, accents and punctuation don't matter). You still rate the card yourself.
- **Mixed** (the default): new cards are Recognize; once a card has been answered twice, it alternates
  between Recall and Recognize. Cards with no translation or meaning are always Recognize.

## Studying a card

After you flip a card, the side panel has:

- **Ask the AI:** quick questions or your own. **Save answer to card notes** keeps a good answer.
- **Use it in a sentence:** write a sentence with the term and press **Check**. The AI says whether
  it is right, gives the fixed sentence, a short explanation in your language and more natural options.
  Every checked sentence is saved with whether it was right; the Coach looks at the wrong ones. Needs a connected AI.
- **Say it:** choose the term or one of the examples, press **Record**, say it, press **Stop**.
  Green words were understood, red ones weren't. It tells you if speech recognition understood you;
  it doesn't grade single sounds.
- **Shadow:** press **Shadow** to hear the selected phrase in the space's voice. Recording starts by
  itself when it finishes, and stops by itself after a little longer than the phrase takes (or press
  **Stop**). You get a score per phrase; **Next** moves through the term and then its examples, **Try
  again** repeats one. Every attempt is saved like a normal pronunciation check.

🔊 reads the term or an example aloud, 🐢 reads it slowly.

## Where things are

| What | Where |
|---|---|
| Your spaces | `~/Glean/spaces.json` |
| Cards of a space | `~/Glean/spaces/<id>/cards.json` |
| Review and pronunciation history | `~/Glean/spaces/<id>/reviews.jsonl` |
| Latest coach analysis | `~/Glean/spaces/<id>/insights.json` |
| Deleted spaces | `~/Glean/Trash/<id>-<date>/` |
| Log | `~/Library/Logs/Glean.log` |
| Settings | macOS defaults, domain `local.glean.app` |

Plain files: back them up, sync them, or edit `cards.json` by hand (missing fields are fine).

Coming from the first version, which kept `cards.json`, `reviews.jsonl` and `insights.json` directly in
`~/Glean`? The first launch copies them into an "English" space (checking every copy) and leaves the
originals untouched. Once you're happy you can delete them by hand. See
[troubleshooting](troubleshooting.md) to go back to the old version.
