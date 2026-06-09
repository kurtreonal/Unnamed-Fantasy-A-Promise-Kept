extends Control

# ─────────────────────────────────────────────────────────────────
# main_menu.gd
#
# Uses %UniqueNodeName accessors instead of $Path/To/Node so this
# script works regardless of where the buttons sit in the scene tree.
# In main_menu.tscn, mark BtnNewGame, BtnContinue, and BtnQuit as
# "Access as Unique Name" (right-click → Access as Unique Name in
# the Godot Scene panel, or add % prefix in the .tscn manually).
# ─────────────────────────────────────────────────────────────────

const HOME_SCENE_PATH := "res://Scenes/home_scene.tscn"

var save_system:  Node
var save_manager: Node

# Slots UI scene — same one used in-game by hud.gd
const SLOTS_SCENE := "res://UI/SaveSlots/save_slots_ui.tscn"

# % prefix = unique-name access — works no matter where the node lives
@onready var btn_new_game:  Button = %BtnNewGame
@onready var btn_load_game: Button = %BtnLoadGame
@onready var btn_quit:      Button = %BtnQuit
@onready var version_label: Label  = %VersionLabel


func _ready() -> void:
	save_system  = get_node_or_null("/root/SaveSystem")
	save_manager = get_node_or_null("/root/SaveManager")

	# Music is already playing via MusicPlayer autoload (started in splash_screen).
	# Nothing to do here — it carries over automatically.

	# Hard-fail with a clear message if any button is still missing
	assert(btn_new_game  != null, "[MainMenu] %BtnNewGame not found — ensure the node has 'Access as Unique Name' enabled in main_menu.tscn")
	assert(btn_load_game != null, "[MainMenu] %BtnContinue not found — ensure the node has 'Access as Unique Name' enabled in main_menu.tscn")
	assert(btn_quit      != null, "[MainMenu] %BtnQuit not found — ensure the node has 'Access as Unique Name' enabled in main_menu.tscn")

	# Enable Load if there is at least one slot save OR an old single-file save.
	var has_slot_save: bool = false
	if save_manager:
		for info in save_manager.get_all_slots():
			if info != null:
				has_slot_save = true
				break
	var has_save: bool = has_slot_save or (save_system != null and save_system.save_exists)
	btn_load_game.disabled = not has_save
	btn_load_game.modulate = Color(1, 1, 1, 1) if has_save else Color(0.55, 0.55, 0.55, 0.7)

	btn_new_game.pressed.connect(_on_new_game)
	btn_load_game.pressed.connect(_on_load_game)
	btn_quit.pressed.connect(_on_quit)

	_animate_in()


# ─────────────────────────────────────────────────────────────────
# Button Handlers
# ─────────────────────────────────────────────────────────────────

func _on_new_game() -> void:
	print("[MainMenu] New Game pressed.")

	if save_system:
		save_system.delete_save()

	# Reset all in-memory systems to clean defaults
	var affection := get_node_or_null("/root/Affection_System")
	var health    := get_node_or_null("/root/Health_System")
	var meal      := get_node_or_null("/root/Meal_System")
	var day       := get_node_or_null("/root/DaySystem")

	if affection:
		affection.current_affection = 0
		affection.current_mood      = 0
	if health:
		health.rin_health = 50
	if meal:
		meal.coins     = 5000
		meal.last_meal = ""
	if day:
		day.current_day    = 1
		day.current_hour   = 8
		day.current_minute = 0
		day._curfew_fired  = false
		day.return_reason  = Day_System.ReturnReason.NONE

	# Set flags BEFORE transitioning so home_scene reads them in _ready()
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state:
		game_state.is_new_game     = true
		game_state.prologue_active = true
		print("[MainMenu] GameState → is_new_game=true, prologue_active=true")
	else:
		push_error("[MainMenu] GameState autoload not found!")

	_transition_to_game()


func _on_load_game() -> void:
	print("[MainMenu] Load Game pressed.")
	_open_load_slots_ui()


func _open_load_slots_ui() -> void:
	# Prevent stacking
	if get_tree().root.get_node_or_null("SaveSlotsLayer"):
		return
	if not ResourceLoader.exists(SLOTS_SCENE):
		push_error("[MainMenu] save_slots_ui.tscn not found: %s" % SLOTS_SCENE)
		return

	var ui: Node = load(SLOTS_SCENE).instantiate()
	ui.name = "SaveSlotsUI"
	ui.mode = "load"
	get_tree().root.add_child(ui)
	# No need to connect closed — save_slots_ui._on_close() self-cleans its wrapper.
	print("[MainMenu] Load slot UI opened.")


func _on_quit() -> void:
	get_tree().quit()


# ─────────────────────────────────────────────────────────────────
# Transition & Animation
# ─────────────────────────────────────────────────────────────────

func _transition_to_game() -> void:
	# Fade out the menu music before the prologue starts.
	var music: Node = get_node_or_null("/root/MusicPlayer")
	if music:
		music.fade_out(0.5)

	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	await t.finished
	get_tree().change_scene_to_file(HOME_SCENE_PATH)


func _animate_in() -> void:
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.8)
