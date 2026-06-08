## ExampleUsage.gd
## Drop this on any Node in your scene to see how to use LocationTitleCard.
## This file is for reference only — not required for the card to work.

extends Node

@onready var title_card: LocationTitleCard = $LocationTitleCard


func _ready() -> void:
	# ── Option A: Use built-in presets ──────────────────────────────────────
	_show_abyss()

	# Connect to signals if you need callbacks
	title_card.card_visible.connect(_on_card_visible)
	title_card.card_finished.connect(_on_card_finished)


## Show the default gold Abyss card
func _show_abyss() -> void:
	var cfg := LocationTitleCardConfig.gold_preset()
	cfg.location_name_en = "Abyss"
	cfg.location_name_jp = "深淵"
	cfg.description      = "A vast labyrinth filled with countless mysteries"
	cfg.icon_symbol      = "✦"
	title_card.show_location(cfg)


## Show a teal ocean location
func _show_ocean_shrine() -> void:
	var cfg := LocationTitleCardConfig.teal_preset()
	cfg.location_name_en = "Ocean Shrine"
	cfg.location_name_jp = "海の祠"
	cfg.description      = "The tide speaks in whispers here"
	cfg.icon_symbol      = "🌊"
	title_card.show_location(cfg)


## Show a crimson volcano location
func _show_fire_peak() -> void:
	var cfg := LocationTitleCardConfig.crimson_preset()
	cfg.location_name_en = "Fire Peak"
	cfg.location_name_jp = "炎の峰"
	cfg.description      = "The mountain that never sleeps"
	cfg.icon_symbol      = "🔥"
	cfg.hold_duration    = 3.5   # stay on screen longer
	title_card.show_location(cfg)


## Show any fully custom card
func _show_custom() -> void:
	var cfg := LocationTitleCardConfig.new()
	cfg.location_name_en   = "Sanctuary"
	cfg.location_name_jp   = "聖域"
	cfg.description        = "A place of ancient, forgotten light"
	cfg.icon_symbol        = "⛩"
	cfg.title_size         = 64
	cfg.accent_color       = Color(0.784, 0.659, 0.333)
	cfg.title_color        = Color(1.0,   0.95,  0.85)
	cfg.overlay_alpha      = 0.65
	cfg.divider_width      = 400.0
	cfg.fade_in_duration   = 0.5
	cfg.stagger_delay      = 0.15
	cfg.hold_duration      = 3.0
	cfg.fade_out_duration  = 0.6
	title_card.show_location(cfg)


## ── Use with await ───────────────────────────────────────────────────────────
## Call this from an async function to block until the card is gone:
##
##   await title_card.show_and_wait(cfg)
##   # code here runs after the card has fully faded out
##   get_tree().change_scene_to_file("res://Scenes/World1.tscn")

func _enter_dungeon() -> void:
	var cfg := LocationTitleCardConfig.gold_preset()
	cfg.location_name_en = "Abyss"
	cfg.location_name_jp = "深淵"
	cfg.description      = "A vast labyrinth filled with countless mysteries"
	await title_card.show_and_wait(cfg)
	# Runs after the card animation completes
	get_tree().change_scene_to_file("res://Scenes/World1.tscn")


## ── Signal callbacks ─────────────────────────────────────────────────────────

func _on_card_visible() -> void:
	# Card is now fully visible — pause gameplay, play a sound, etc.
	print("Card fully visible — freeze player input here")


func _on_card_finished() -> void:
	# Card has faded out — resume gameplay
	print("Card done — resume game")
