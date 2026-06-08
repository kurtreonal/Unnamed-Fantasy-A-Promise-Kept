## LocationTitleCard.gd
## Attach this to the LocationTitleCard CanvasLayer scene.
##
## ── Quick start ─────────────────────────────────────────────────────────────
##
##   var cfg := LocationTitleCardConfig.new()
##   cfg.location_name_en = "Abyss"
##   cfg.location_name_jp = "深淵"
##   cfg.description      = "A vast labyrinth filled with countless mysteries"
##   LocationTitle_Card.show_location(cfg)
##
##   # Block until done:
##   await LocationTitle_Card.show_and_wait(cfg)

class_name LocationTitleCard
extends CanvasLayer

## Emitted when the full show → hold → hide sequence completes.
signal card_finished

## Emitted as soon as the card is fully visible (after fade-in + stagger).
signal card_visible

## ── Inspector default ────────────────────────────────────────────────────────
@export var default_config: LocationTitleCardConfig

## ── Node references ──────────────────────────────────────────────────────────
@onready var _overlay:   ColorRect       = $Root/Overlay
@onready var _vignette:  ColorRect       = $Root/Vignette
@onready var _icon_lbl:  Label           = $Root/CardContainer/IconLabel
@onready var _sub_lbl:   Label           = $Root/CardContainer/SubtitleLabel
@onready var _title_lbl: Label           = $Root/CardContainer/TitleLabel
@onready var _divider:   HBoxContainer   = $Root/CardContainer/DividerContainer
@onready var _line_l:    ColorRect       = $Root/CardContainer/DividerContainer/LineLeft
@onready var _dot:       ColorRect       = $Root/CardContainer/DividerContainer/Dot
@onready var _line_r:    ColorRect       = $Root/CardContainer/DividerContainer/LineRight
@onready var _desc_lbl:  Label           = $Root/CardContainer/DescriptionLabel

## Stagger order — each element gets its own tween spawned with a Timer delay.
var _elements: Array[Control]

## Track running tweens so we can kill them all on interrupt.
var _tweens: Array[Tween] = []

## Prevent multiple show requests while sequence is running.
var _running := false

## ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_elements = [_icon_lbl, _sub_lbl, _title_lbl, _divider, _desc_lbl]
	_build_vignette()
	_set_all_alpha(0.0)
	_overlay.color.a = 0.0
	visible = false


## ── Public API ───────────────────────────────────────────────────────────────

func show_location(config: LocationTitleCardConfig = null) -> void:
	if _running:
		return

	_running = true

	var cfg: LocationTitleCardConfig = config if config else default_config
	if cfg == null:
		cfg = LocationTitleCardConfig.new()

	_clear_tweens()
	_apply_config(cfg)
	_set_all_alpha(0.0)
	_overlay.color.a = 0.0
	visible = true

	# Run the full sequence as a coroutine on this node.
	_run_sequence(cfg)


func hide_immediate() -> void:
	_clear_tweens()
	visible = false
	_set_all_alpha(0.0)
	_overlay.color.a = 0.0


## Awaits the full show → hold → hide sequence, then clears tweens.
## After this returns, it is safe to change scenes immediately.
func show_and_wait(config: LocationTitleCardConfig = null) -> void:
	show_location(config)
	await card_finished
	_clear_tweens()
	await get_tree().process_frame


## ── Sequence ─────────────────────────────────────────────────────────────────
## Each step is a separate Tween so we never call set_parallel() on a
## TweenerStep — only on Tween objects, which is the correct Godot 4 API.

func _run_sequence(cfg: LocationTitleCardConfig) -> void:
	# ── Step 1: Fade in overlay ──────────────────────────────────────────────
	var t_overlay := _make_tween()
	t_overlay.tween_method(
		func(a: float): _overlay.color.a = a,
		0.0, cfg.overlay_alpha,
		cfg.fade_in_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await t_overlay.finished

	if not is_instance_valid(t_overlay):
		return

	# ── Step 2: Stagger each element in (parallel fade + slide per element) ──
	# Each element gets its own Tween so set_parallel is called on the Tween
	# itself — never on an individual TweenerStep.
	var stagger_total: float = 0.0
	for i in _elements.size():
		var el: Control  = _elements[i]
		var delay: float = cfg.stagger_delay * i
		stagger_total    = delay + cfg.fade_in_duration

		# Capture original Y before we offset it.
		var origin_y: float = el.position.y
		el.position.y       = origin_y + 18.0
		el.modulate.a       = 0.0

		# Fire-and-forget tween with built-in delay — no timer needed.
		var t_el := _make_tween()
		t_el.set_parallel(true)   # called on Tween — valid in Godot 4
		t_el.tween_property(el, "modulate:a", 1.0, cfg.fade_in_duration) \
			.set_delay(delay) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)
		t_el.tween_property(el, "position:y", origin_y, cfg.fade_in_duration) \
			.set_delay(delay) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUART)

	# Wait for the last element's tween to finish.
	await get_tree().create_timer(stagger_total).timeout

	if not _running:
		return

	card_visible.emit()

	# ── Step 3: Hold ─────────────────────────────────────────────────────────
	await get_tree().create_timer(cfg.hold_duration).timeout

	if not _running:
		return

	# ── Step 4: Fade everything out together ─────────────────────────────────
	var t_out := _make_tween()
	t_out.set_parallel(true)
	for el in _elements:
		t_out.tween_property(el, "modulate:a", 0.0, cfg.fade_out_duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t_out.tween_method(
		func(a: float): _overlay.color.a = a,
		cfg.overlay_alpha, 0.0,
		cfg.fade_out_duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await t_out.finished

	if not _running:
		return

	visible = false

	_clear_tweens()

	await get_tree().process_frame

	_running = false
	card_finished.emit()


## ── Private helpers ──────────────────────────────────────────────────────────

func _make_tween() -> Tween:
	var t := create_tween().bind_node(self)

	_tweens.append(t)

	t.finished.connect(func():
		_tweens.erase(t)
	, CONNECT_ONE_SHOT)

	return t

func _clear_tweens() -> void:
	for t in _tweens:
		if is_instance_valid(t):
			t.kill()

	_tweens.clear()


func _apply_config(cfg: LocationTitleCardConfig) -> void:
	_icon_lbl.text  = cfg.icon_symbol
	_sub_lbl.text   = cfg.location_name_en
	_title_lbl.text = cfg.location_name_jp
	_desc_lbl.text  = cfg.description

	_icon_lbl.add_theme_font_size_override("font_size", cfg.icon_size)
	_sub_lbl.add_theme_font_size_override("font_size",  cfg.subtitle_size)
	_title_lbl.add_theme_font_size_override("font_size", cfg.title_size)
	_desc_lbl.add_theme_font_size_override("font_size",  cfg.description_size)

	_icon_lbl.add_theme_color_override("font_color",  cfg.accent_color)
	_sub_lbl.add_theme_color_override("font_color",   cfg.subtitle_color)
	_title_lbl.add_theme_color_override("font_color", cfg.title_color)
	_desc_lbl.add_theme_color_override("font_color",  cfg.description_color)

	_line_l.color = Color(cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, 0.7)
	_line_r.color = Color(cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, 0.7)
	_dot.color    = Color(cfg.accent_color.r, cfg.accent_color.g, cfg.accent_color.b, 0.8)
	_divider.custom_minimum_size.x = cfg.divider_width


func _set_all_alpha(a: float) -> void:
	for el: Control in _elements:
		el.modulate.a = a


func _build_vignette() -> void:
	var mat    := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv      = UV - vec2(0.5);
	float dist   = length(uv * vec2(1.6, 1.0));
	float v      = smoothstep(0.35, 0.85, dist);
	COLOR        = vec4(0.0, 0.0, 0.0, v * 0.65);
}
"""
	mat.shader      = shader
	_vignette.material = mat
