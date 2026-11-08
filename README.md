# Unnamed Fantasy: A Promise Kept

A story about care and devotion.

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
4. Press **F5** (Run Project). The splash screens lead to the main menu; select
   **New Game** to start the prologue. Any key or a click skips a splash logo.

Use **F5** for the full game. **F6** runs only the currently selected scene.
The project uses the Compatibility renderer and does not need export templates
to run inside the editor.

## Controls

- **W/A/S/D:** move; **Space:** dash; **F:** interact.
- **Left mouse:** attack in the world, or advance dialogue.
- **Enter:** advance dialogue.
- **Q/E/R:** switch element, weapon, and skill.
- **B:** recall home from the world.

Android and touch-enabled browsers show movement, attack, interaction, switching,
and recall buttons during exploration. Play in landscape; touch aiming follows
your last movement direction.

Saves are stored in Godot's `user://` directory, separately from the project.
The upstream repository is
[kurtreonal/Unnamed-Fantasy-A-Promise-Kept](https://github.com/kurtreonal/Unnamed-Fantasy-A-Promise-Kept).

## Dialogic compatibility fix

The bundled Dialogic runtime keeps generated character and timeline resources
in a script-managed cache. This avoids a
[Godot 4.6.2 shutdown crash](https://github.com/godotengine/godot/issues/119279).
Retain this change in `addons/dialogic/Core/DialogicResourceUtil.gd` when
replacing the bundled plugin, unless the replacement already addresses it.
