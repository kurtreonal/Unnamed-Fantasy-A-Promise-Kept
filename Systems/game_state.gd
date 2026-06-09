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
var prologue_active: bool = false

## Set by WorldTransition before a scene load so WorldBase can place
## the player at the correct position in the new scene.
## Reset to Vector2.ZERO by WorldBase after the player is repositioned.
##
## HOW IT WORKS WITH DOORS:
##   World1 → Dungeon door  : sets spawn_position = dungeon entry point
##   Dungeon → World1 door  : sets spawn_position = World1 door position
##
## Both are set via the WorldTransition inspector (spawn_position export)
## OR dynamically via use_player_position_as_spawn = true.
var spawn_position: Vector2 = Vector2.ZERO

## Set by SaveManager when loading a slot so home_scene knows which
## timeline to restart from the beginning.
## Reset to "" by home_scene after it is consumed.
var saved_scene: String = ""

## Resolved by home_scene before starting the evening timeline.
## Values: "high" | "mid" | "low"
var affection_tier: String = "low"

## Tracks the last day scene_03 was triggered.
## Used to enforce the 3-day cooldown between doubt scene repeats.
## Starts at -99 so the gap check always passes on first trigger.
var last_scene03_day: int = -99
