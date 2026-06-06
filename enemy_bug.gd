extends CharacterBody2D

# ── Stats ─────────────────────────────────────────────────────
const MAX_HP: int = 3

# ── State ─────────────────────────────────────────────────────
enum State { WANDER, ATTACK, DEATH }
var state: State = State.WANDER

# ── Runtime ───────────────────────────────────────────────────
var hp: int       = MAX_HP
var _is_dead: bool = false

# ── Node refs ─────────────────────────────────────────────────
@onready var sprite: AnimatedSprite2D    = $AnimatedSprite2D
@onready var audio:  AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var body:   CollisionShape2D    = $CollisionShape2D

func _ready() -> void:
	sprite.play("Enemy_Movement")
	# Damage is triggered by weapon Area2D.body_entered → effect_combat.gd
	# No signal connections needed on the enemy side.


# ── Called by effect_combat._on_hit_body() ────────────────────
func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	hp -= amount

	# Visual hit flash
	sprite.modulate = Color(1.5, 0.3, 0.3)
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(self) and not _is_dead:
			sprite.modulate = Color.WHITE
	)

	# Play hurt sound — AudioStreamPlayer2D in enemy_bug.tscn
	# Note: assign a proper hurt/impact sound to this node in the Inspector.
	# The current tscn has Sword Whoosh assigned; swap it for an impact SFX.
	if not audio.playing:
		audio.play()

	if hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	state    = State.DEATH
	velocity = Vector2.ZERO
	audio.stop()
	body.set_deferred("disabled", true)
	sprite.modulate = Color.WHITE
	sprite.play("Enemy_Death")
	sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()
