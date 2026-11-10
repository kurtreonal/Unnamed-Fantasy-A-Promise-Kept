# Unnamed Fantasy: A Promise Kept

A quiet story about a childhood promise, shared school days, and finding a way forward together.

The 0.2.0 redesign follows Rin (the Asami character) and the protagonist, both
17-year-old high-school classmates, during a 28-day spring recess. It combines
clickable illustrated home scenes, quests, shared meals and activities, two
relationship meters, and top-down dungeon combat. Romance is non-explicit.

[Play in your browser](https://kurtreonal.github.io/Unnamed-Fantasy-A-Promise-Kept/)
or download the signed ARM64 Android APK from
[GitHub Releases](https://github.com/kurtreonal/Unnamed-Fantasy-A-Promise-Kept/releases).
See [RELEASE.md](RELEASE.md) for export, signing, and deployment instructions.

## Open and run

1. Install **Godot 4.6.2 Standard** (the .NET edition is not required).
2. In Godot's Project Manager, choose **Import** and select the `project.godot`
   in this folder.
3. Open the project and allow the initial asset import to finish. Dialogic is
   included in `addons/dialogic` and enabled automatically.
4. Press **F5** (Run Project). The redesigned title screen opens directly;
   select **Begin a new story** to start the Dialogic prologue.

Use **F5** for the full game. **F6** runs only the currently selected scene.
The project uses the Compatibility renderer and does not need export templates
to run inside the editor.

## Controls

- **WASD/arrows:** move; **Space:** dodge; **F:** interact.
- **Left mouse:** primary attack; **right mouse:** weapon skill.
- **R:** restorative tea; **B:** recall home.
- **I/J:** inventory and journal; **Escape:** menu.
- **Enter/Space:** reveal or advance dialogue; hold to skip ordinary lines.
- **H:** reveal home interaction areas. Click Rin to spend time together.

Equip one weapon through inventory. Settings provide keyboard remapping and three
camera distances. Important dialogue and choices stop held skipping and require
fresh input. Android and touch-enabled browsers use a joystick and compact attack,
skill, dodge and interaction controls; utilities are available from Menu.

Saves are stored in Godot's `user://` directory, separately from the project.
New campaign saves use `user://campaign/`. The title's **Save stories** screen
can import legacy saves into an empty new slot while preserving the originals.
The upstream repository is
[kurtreonal/Unnamed-Fantasy-A-Promise-Kept](https://github.com/kurtreonal/Unnamed-Fantasy-A-Promise-Kept).

## Dialogic compatibility fix

The bundled Dialogic runtime keeps generated character and timeline resources
in a script-managed cache. This avoids a
[Godot 4.6.2 shutdown crash](https://github.com/godotengine/godot/issues/119279).
Retain this change in `addons/dialogic/Core/DialogicResourceUtil.gd` when
replacing the bundled plugin, unless the replacement already addresses it.

## Editing and production

The new story scenes remain editable Dialogic timelines under `Game/Timelines/`.
See [the redesign guide](docs/REDESIGN.md) for content authoring, isolated tests,
the local AOM3/ControlNet art pipeline and save compatibility. Asset provenance is
recorded in `Game/Art/ASSET_MANIFEST.json`; generated PNGs have adjacent prompt,
seed and model metadata. All eight original music tracks remain unchanged.

The campaign contains 24 quests, 24 unique relationship events, ten activities,
six recipes, three dungeon regions and five endings. The 4–6 hour duration is a
playtesting target, not a measured guarantee.
