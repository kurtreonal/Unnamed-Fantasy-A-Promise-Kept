extends Node

# ─────────────────────────────────────────────────────────────────
# game_state.gd
# Autoload name: GameState
#
# Lightweight global flag store.
# Persists across scene changes without writing to disk.
# ─────────────────────────────────────────────────────────────────

## Set to true by main_menu when the player clicks "New Game".
## Cleared to false by home_scene after the prologue finishes.
var is_new_game: bool = false

## True while the prologue timeline is still running.
## home_scene.gd uses this to keep TopBar + StatsPanel hidden.
## Also read by hud.gd on _ready to choose the initial visibility state.
var prologue_active: bool = false
