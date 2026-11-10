# Project continuity

When continuing work on this game, read `.private/second-brain/vault/START HERE.md` if it exists. This local Obsidian vault records decisions, verified sources, current limitations and the Graphify code index. Notes are context; verify implementation details against the current source. The user's latest instructions take precedence over older notes.

Update the relevant local note when a design decision changes. Keep keys, credentials, player saves, model environments and intermediate artwork out of notes intended for publication. `.private/` stays excluded from Git and Godot exports.

The redesigned game starts at `Game/main.tscn`, uses the `Campaign` state autoload and actual Dialogic timelines. Preserve the original music. Run tests only with the isolated profiles created by `tools/check_redesign.ps1`.

See `docs/SECOND_BRAIN.md` for local knowledge tools and `docs/CHARACTER_DIRECTION.md` for the current art direction.
