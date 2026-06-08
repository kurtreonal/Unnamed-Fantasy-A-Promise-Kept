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

## Set by SaveManager before a scene load so WorldBase/HomeScene
## can place the player at the exact saved position.
## Reset to Vector2.ZERO after the player is repositioned.
var spawn_position: Vector2 = Vector2.ZERO

## Set by SaveManager when loading a slot so home_scene knows which
## timeline to restart from the beginning.
## Values match home_scene's _request_scene() keys:
##   ""         → use normal scene-decision logic (not a loaded save)
##   "prologue" → restart prologue from the top
##   "morning"  → restart scene_01_morning_wakeup from the top
##   "evening"  → restart scene_02_evening_return from the top
##   "doubt"    → restart scene_03_moment_of_doubt from the top
## Reset to "" by home_scene after it is consumed.
var saved_scene: String = ""

## Resolved by home_scene before starting the evening timeline.
## Values: "high" | "mid" | "low"
## Used to pick the correct label entry point in scene_02_evening_return.dtl.
## Reset to "low" each time it is consumed by _play_scene("evening").
var affection_tier: String = "low"
