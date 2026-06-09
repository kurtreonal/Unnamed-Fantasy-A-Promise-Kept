extends Control

# ─────────────────────────────────────────────────────────────────
# splash_screen.gd
#
# Displays studio/colleague logos in sequence before the main menu.
# Each logo fades in, holds, then fades out.
#
# Skip: press any key or click to skip the current logo and jump
# to the next one. Skipping the last logo goes to the main menu.
# ─────────────────────────────────────────────────────────────────

const MAIN_MENU_PATH := "res://Scenes/main_menu.tscn"

# Drag the BGM track here in the Inspector:
# res://BGM/Sickly_Days_and_Summer_Traces_trailer.mp3
@export var menu_music: AudioStream

const LOGOS: Array[String] = [
	"res://Assets/logo1.png",
	"res://Assets/logo4.png",
	"res://Assets/logo2.png",
	"res://Assets/logo3.png",
	"res://Assets/logo5.png",
]

const FADE_DURATION : float = 0.6
const HOLD_DURATION : float = 1.8

@onready var logo_display: TextureRect = $LogoDisplay

var _can_skip        : bool = false
var _skip_current    : bool = false


func _ready() -> void:
	logo_display.modulate.a = 0.0

	# Start the menu music here so it carries through to the main menu.
	var music: Node = get_node_or_null("/root/MusicPlayer")
	if music and menu_music:
		music.play(menu_music)

	# Small delay before accepting skip input so an accidental
	# keypress at game launch doesn't instantly skip the first logo.
	await get_tree().create_timer(0.3).timeout
	_can_skip = true
	_run_splash()


func _input(event: InputEvent) -> void:
	if not _can_skip:
		return
	if event is InputEventKey and event.pressed:
		_skip_current = true
	elif event is InputEventMouseButton and event.pressed:
		_skip_current = true


func _run_splash() -> void:
	for path in LOGOS:
		_skip_current = false
		_can_skip     = false

		logo_display.texture    = load(path)
		logo_display.modulate.a = 0.0

		# Brief pause before accepting skip on this logo
		await get_tree().create_timer(0.3).timeout
		_can_skip = true

		# Fade in
		var t := create_tween()
		t.tween_property(logo_display, "modulate:a", 1.0, FADE_DURATION)
		await t.finished

		# Hold — poll for skip each frame
		var timer : float = 0.0
		while timer < HOLD_DURATION:
			if _skip_current:
				break
			timer += get_process_delta_time()
			await get_tree().process_frame

		# Fade out (fast if skipped, normal otherwise)
		var fade_out := 0.2 if _skip_current else FADE_DURATION
		t = create_tween()
		t.tween_property(logo_display, "modulate:a", 0.0, fade_out)
		await t.finished

	get_tree().change_scene_to_file(MAIN_MENU_PATH)
