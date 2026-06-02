## LocationTitleCardConfig.gd
## A Resource that holds all the data for one location card.
## Create instances via: LocationTitleCardConfig.new() or @export vars in your scene.
##
## Usage example:
##   var cfg = LocationTitleCardConfig.new()
##   cfg.location_name_en = "Abyss"
##   cfg.location_name_jp = "深淵"
##   title_card.show_location(cfg)

class_name LocationTitleCardConfig
extends Resource

## English / romanised location name (shown small above the main title)
@export var location_name_en: String = "Abyss"

## CJK / stylised title (shown large)
@export var location_name_jp: String = "深淵"

## Short flavour description shown below the divider
@export var description: String = "A vast labyrinth filled with countless mysteries"

## Symbol / icon character rendered above the title
@export var icon_symbol: String = "✦"

## ── Typography ─────────────────────────────────────────────────────────────
@export_group("Typography")
@export var icon_size: int = 28
@export var subtitle_size: int = 14
@export var title_size: int = 52
@export var description_size: int = 14

## ── Colours ────────────────────────────────────────────────────────────────
@export_group("Colors")
## Accent colour used for icon, divider, and tinting
@export var accent_color: Color = Color(0.784, 0.659, 0.333, 1.0)   # gold
@export var title_color: Color = Color(0.941, 0.902, 0.800, 1.0)    # warm white
@export var subtitle_color: Color = Color(0.784, 0.722, 0.533, 1.0)
@export var description_color: Color = Color(0.659, 0.596, 0.471, 1.0)
@export var overlay_alpha: float = 0.55

## ── Divider ────────────────────────────────────────────────────────────────
@export_group("Divider")
@export var divider_width: float = 320.0

## ── Timings (seconds) ──────────────────────────────────────────────────────
@export_group("Animation")
@export var fade_in_duration: float = 0.4
@export var stagger_delay: float = 0.12
@export var hold_duration: float = 2.5
@export var fade_out_duration: float = 0.5

## ── Preset helpers ─────────────────────────────────────────────────────────
static func gold_preset() -> LocationTitleCardConfig:
	var c := LocationTitleCardConfig.new()
	return c

static func silver_preset() -> LocationTitleCardConfig:
	var c := LocationTitleCardConfig.new()
	c.accent_color      = Color(0.690, 0.745, 0.773, 1.0)
	c.title_color       = Color(0.925, 0.949, 0.961, 1.0)
	c.subtitle_color    = Color(0.690, 0.745, 0.773, 1.0)
	c.description_color = Color(0.565, 0.643, 0.682, 1.0)
	return c

static func crimson_preset() -> LocationTitleCardConfig:
	var c := LocationTitleCardConfig.new()
	c.accent_color      = Color(0.898, 0.451, 0.451, 1.0)
	c.title_color       = Color(1.0,   0.804, 0.824, 1.0)
	c.subtitle_color    = Color(0.937, 0.604, 0.604, 1.0)
	c.description_color = Color(0.898, 0.451, 0.451, 1.0)
	return c

static func teal_preset() -> LocationTitleCardConfig:
	var c := LocationTitleCardConfig.new()
	c.accent_color      = Color(0.302, 0.816, 0.882, 1.0)
	c.title_color       = Color(0.878, 0.969, 0.980, 1.0)
	c.subtitle_color    = Color(0.502, 0.871, 0.918, 1.0)
	c.description_color = Color(0.302, 0.816, 0.882, 1.0)
	return c
