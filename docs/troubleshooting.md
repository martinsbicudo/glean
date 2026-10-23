# Troubleshooting

The log is `~/Library/Logs/Glean.log`: every AI call (engine and activity), failures, speech model
downloads and file errors.

| Problem | What to do |
|---|---|
| "No AI is connected" | Settings ▸ AI ▸ Connect to: Claude Code or Codex. |
| "Claude Code isn't installed or wasn't found" | Install the CLI and sign in once in Terminal (`claude`, or `codex login`). Settings shows the path it found. |
| "Claude Code failed: …" / "Codex failed: …" | Usually not signed in or out of usage. Run the CLI in Terminal to see the message. Glean already tried the other engine if it was installed. |
| "The AI didn't answer with JSON" | Try again; for long notes, ask for fewer cards. |
| Generating takes a while | Long texts can take a minute or two. |
| "Glean can't use the microphone" | System Settings ▸ Privacy & Security ▸ Microphone ▸ allow Glean. |
| Pronunciation check is slow the first time | macOS downloads the speech model for the space's language once. |
| No reminders | System Settings ▸ Notifications ▸ Glean ▸ allow. Reminders only fire when cards are due at that hour. |
| Permissions asked again after every rebuild | The app is ad-hoc signed. Configure a signing identity in `scripts/signing.local.env` (see the README), then `make install`. |
| "Apple speech recognition has no model for this language" | macOS has no on-device speech model for the space's language. Everything else works; only the pronunciation check is unavailable. |
| "Couldn't read ~/Glean/spaces/<id>/cards.json" | The file isn't valid JSON (probably a manual edit). Glean won't write to it until it loads again. Fix it or restore a backup (Open Folder), then press Reload. |
| "Couldn't read ~/Glean/spaces.json" | Same idea for the list of spaces. Glean won't recreate or overwrite it. Fix or restore it, then Reload. |
| "spaces.json is missing but space folders exist" | `spaces.json` was deleted or lost. Restore it from a backup, or move `~/Glean/spaces` aside (Open Folder), then Reload. Glean never guesses which folder is which. |
| "Couldn't read ~/Glean/cards.json … Nothing was changed" on first launch | The old single-deck `cards.json` can't be parsed, so it can't be moved into a space. Fix or restore it (Open Folder), then Reload. New Space is disabled until then. |
| A space was deleted by mistake | Its folder is in `~/Glean/Trash/<id>-<date>/` (`space.json` inside has its name). Create a space, quit Glean, and copy `cards.json`, `reviews.jsonl` and `insights.json` into the new `spaces/<id>/` folder. |

## Going back to the first version (single deck)

The first version read and wrote `cards.json`, `reviews.jsonl` and `insights.json` directly in `~/Glean`. After
the move to spaces those root files are stale: the live data is in `~/Glean/spaces/<id>/`. To run an older
build again:

1. Quit Glean.
2. Open `~/Glean/spaces.json` and note the `id` of the space to go back with (the "English" space made by the
   migration).
3. Back up the root files: `mkdir ~/Glean/pre-rollback && cp ~/Glean/{cards.json,reviews.jsonl,insights.json} ~/Glean/pre-rollback/`
4. Copy that space over them: `cp ~/Glean/spaces/<id>/{cards.json,reviews.jsonl,insights.json} ~/Glean/`
   (skip any file the space doesn't have).
5. Install the older build (`git revert` the spaces commits, then `make install`).

## Moving forward again after using the old version

The old build changed the root files, so the spaces are out of date. To let the new version migrate them again:

1. Quit Glean.
2. `mkdir ~/Glean/pre-rollforward-$(date +%Y%m%d) && mv ~/Glean/spaces.json ~/Glean/spaces ~/Glean/pre-rollforward-$(date +%Y%m%d)/`
3. Launch the new Glean. With no `spaces.json`, it migrates the root files into a new "English" space.
4. Spaces other than English that you created in between stay in the `pre-rollforward-<date>` folder; copy their
   folders back into `spaces/` and add them to `spaces.json` by hand, or recreate them and copy the files in.
