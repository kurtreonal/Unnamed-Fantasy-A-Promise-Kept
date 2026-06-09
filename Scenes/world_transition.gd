extends Area2D
# world_transition.gd
#
# Drop this node (or the WorldTransition.tscn scene) anywhere in a world scene.
# Set the exported variables in the Inspector:
#   • target_scene    — e.g. "res://Scenes/dungeon_world1.tscn"
#   • spawn_position  — where the player appears IN THE TARGET SCENE
#                       (set this on the EXIT door, pointing at the ENTRY of the next world)
#                       Leave at (0,0) to use that world's default spawn.
#   • use_player_position_as_spawn — if true, saves the player's CURRENT position
#                       into GameState.spawn_position so the RETURN door in the
#                       target scene can bring the player back to exactly where
#                       they left from. Set this on the ENTRY door.
#   • fade_duration   — seconds for the black-fade before switching (default 0.8)
#
# HOW TO SET UP A TWO-WAY PORTAL (e.g. World1 ↔ Dungeon):
#
#   World1 scene — "DungeonEntrance" WorldTransition node:
#       target_scene                 = "res://Scenes/dungeon_world1.tscn"
#       spawn_position               = <dungeon entry point, e.g. (200, 400)>
#       use_player_position_as_spawn = false
#       (The dungeon's exit door will save the return position separately.)
#
#   dungeon_world1 scene — "ExitDoor" WorldTransition node:
#       target_scene                 = "res://Scenes/World1.tscn"
#       spawn_position               = <World1 position in front of dungeon door, e.g. (850, 300)>
#       use_player_position_as_spawn = false
#
# Result: player always appears at the correct side of each door.
#
# ALTERNATIVE — dynamic return position:
#   If you want the player to return to exactly where they ENTERED the dungeon
#   (i.e. their position in World1 before going in), set
#   use_player_position_as_spawn = true on the World1 entry door. The dungeon
#   exit door will then use whatever position was saved, ignoring its own spawn_position.

@export var target_scene:    String  = ""
@export var spawn_position:  Vector2 = Vector2.ZERO
@export var fade_duration:   float   = 0.8

## When true: saves the player's CURRENT position as the spawn for the
## target scene, instead of the static spawn_position above.
## Use this on the entry door so the exit door brings the player back
## to exactly where they walked in.
@export var use_player_position_as_spawn: bool = false

var _transitioning: bool = false

# ── Fade rect (created at runtime so this node is self-contained) ──
var _fade_rect: ColorRect = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_fade_rect()


# ── Trigger ────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if _transitioning:
		return
	if not _is_player(body):
		return

	_transitioning = true
	_do_transition(body)


func _do_transition(player_body: Node) -> void:
	var player := _get_player()
	if player and player.has_method("set_input_locked"):
		player.set_input_locked(true)

	var game_state := get_node_or_null("/root/GameState")
	if game_state:
		if use_player_position_as_spawn:
			# Save where the player IS RIGHT NOW — the exit door in the
			# destination scene will use this to bring them back here.
			if player:
				game_state.spawn_position = player.global_position
				print("[WorldTransition] Saved player position as return spawn: %s" % player.global_position)
		elif spawn_position != Vector2.ZERO:
			# Use the static position set in the Inspector.
			game_state.spawn_position = spawn_position
			print("[WorldTransition] Set spawn_position to inspector value: %s" % spawn_position)

	await _fade_out(fade_duration)

	if target_scene == "":
		push_error("[WorldTransition] target_scene is empty — set it in the Inspector!")
		_transitioning = false
		return

	get_tree().change_scene_to_file(target_scene)


# ── Fade helpers ───────────────────────────────────────────────────
func _build_fade_rect() -> void:
	var layer       := CanvasLayer.new()
	layer.layer      = 100
	add_child(layer)

	_fade_rect              = ColorRect.new()
	_fade_rect.color        = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)


func _fade_out(duration: float) -> void:
	if not _fade_rect:
		await get_tree().create_timer(duration).timeout
		return
	var t := 0.0
	while t < duration:
		t += get_process_delta_time()
		_fade_rect.color.a = clamp(t / duration, 0.0, 1.0)
		await get_tree().process_frame
	_fade_rect.color.a = 1.0


# ── Helpers ────────────────────────────────────────────────────────
func _get_player() -> Node:
	var root := get_tree().current_scene
	if root.has_node("%Character"):
		return root.get_node("%Character")
	return root.get_node_or_null("Character")


func _is_player(body: Node) -> bool:
	return body.name == "Character" or body.is_in_group("player")
