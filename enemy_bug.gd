extends CharacterBody2D

# ── Stats ─────────────────────────────────────────────────────

const WANDER_SPEED:   float = 60.0   # px/s while wandering

const CIRCLE_RADIUS:  float = 60.0   # radius of wander circle

const CIRCLE_SPEED:   float = 1.2    # radians/s around the circle

const MAX_HP:         int   = 3      # hits to kill

# ── State machine ─────────────────────────────────────────────

enum State { WANDER, ATTACK, DEATH }

var state: State = State.WANDER

# ── Runtime vars ──────────────────────────────────────────────

var hp: int = MAX_HP

var _circle_angle: float = 0.0      # current angle on the wander circle

var _circle_origin: Vector2         # center of the wander circle (set on ready)

var _is_dead: bool = false

# ── Node refs ─────────────────────────────────────────────────

@onready var sprite:     AnimatedSprite2D  = $AnimatedSprite2D

@onready var audio:      AudioStreamPlayer2D = $AudioStreamPlayer2D

@onready var attack_col:   CollisionShape2D  = $AttactHitbox

@onready var body:     Area2D            = $AnimatedSprite2D/Area2D

@onready var body_col: CollisionShape2D  = $AnimatedSprite2D/Area2D/CollisionShape2D

func _ready() -> void:

	_circle_origin = global_position

	sprite.play("Enemy_Movement")

	body.body_entered.connect(_on_body_entered)

	body.area_entered.connect(_on_body_area_entered)



func take_damage(amount: int = 1) -> void:

	if _is_dead:

		return

	hp -= amount

	audio.play()   # hurt sound

	if hp <= 0:

		_die()



func _die() -> void:

	_is_dead      = true

	state         = State.DEATH

	velocity      = Vector2.ZERO

	attack_col.set_deferred("disabled", true)   # disable attack

	body_col.set_deferred("disabled", true)     # disable body

	sprite.play("Enemy_Death")

	sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)

	

func _on_death_anim_finished() -> void:

	queue_free()

func _on_body_area_entered(area: Area2D) -> void:

	var weapon_hitboxes = [

		"SwordHitBox", "LanceHitBox",

		"FireBallHitBox", "LightningHitBox"

	]

	if area.name in weapon_hitboxes:

		take_damage(1)

func _on_body_entered(body: Node2D) -> void:

	if body.name == "Arrow_Projectile":

		take_damage(1)
