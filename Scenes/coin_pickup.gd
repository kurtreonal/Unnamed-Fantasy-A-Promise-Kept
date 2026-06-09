extends Area2D
# coin_pickup.gd

@export var coin_value:      int   = 1
@export var auto_expire_sec: float = 8.0   # coin vanishes if never collected

const FLOAT_DURATION := 0.35
const FLOAT_HEIGHT   := 14.0

var _collected: bool = false


func _ready() -> void:
	var sprite := _get_sprite()
	if sprite:
		sprite.play("spin")

	# Float upward.
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - FLOAT_HEIGHT, FLOAT_DURATION)\
		 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Auto-expire so coins don't pile up forever.
	get_tree().create_timer(auto_expire_sec).timeout.connect(_on_expire)

	# Use area_entered instead of body_entered — more reliable when the
	# player is a CharacterBody2D wrapped in an Area2D, and avoids being
	# triggered by enemy corpses or other physics bodies.
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


# ─── Pickup via Area2D overlap (preferred) ────────────────────────
func _on_area_entered(area: Area2D) -> void:
	if _collected:
		return
	# Accept any area that is in the player group OR whose owner/parent is.
	if area.is_in_group("player") or \
	   (area.get_parent() and area.get_parent().is_in_group("player")):
		_collect()


# ─── Pickup via CharacterBody2D / RigidBody2D direct overlap ──────
func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collect()


# ─── Expire without collection ────────────────────────────────────
func _on_expire() -> void:
	if _collected:
		return
	# Fade out quietly.
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)


# ─── Core collect logic ───────────────────────────────────────────
func _collect() -> void:
	_collected = true
	set_deferred("monitoring", false)

	var coin_system: Node = get_node_or_null("/root/CoinSystem")
	if coin_system:
		coin_system.add_coins(coin_value)
		print("[CoinPickup] Collected %d coin(s). Total: %d" % [coin_value, coin_system.get_coins()])
	else:
		push_warning("[CoinPickup] CoinSystem autoload not found!")

	_play_collect_animation()


func _play_collect_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.08)\
		 .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.14)\
		 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _get_sprite() -> AnimatedSprite2D:
	for child in get_children():
		if child is AnimatedSprite2D:
			return child
	return null
