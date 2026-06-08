extends CharacterBody2D

# ══════════════════════════════════════════════════════════════════
#  ENEMY BUG  –  enemy_bug.gd
#  Features:
#    • Weapon-type damage table (bow / magic / lance / sword)
#    • Path2D patrol when no player in range
#    • Spawns / activates only when player enters VisibleOnScreenNotifier2D
#    • Chases & attacks player on sight
# ══════════════════════════════════════════════════════════════════

# ── Stats ──────────────────────────────────────────────────────────
const MAX_HP        : int   = 5
const MOVE_SPEED    : float = 60.0   # patrol speed (px/s)
const CHASE_SPEED   : float = 90.0   # chase speed  (px/s)
const ATTACK_RANGE  : float = 24.0   # pixels – how close to deal damage
const ATTACK_DAMAGE : int   = 1      # damage the bug deals to the player
const ATTACK_COOLDOWN: float = 0.5  # seconds between attacks

# ── Weapon damage table ────────────────────────────────────────────
# Each entry is either a fixed int  →  exact damage
#                      or [min, max] →  random range (inclusive)
const WEAPON_DAMAGE: Dictionary = {
	"bow"   : 3,          # always 3
	"magic" : [5, 10],    # random 5–10
	"lance" : {           # two sub-types
		"pierce": 2,
		"thrust": 5
	},
	"sword" : [1, 2],     # random 1–2
}

# ── State ──────────────────────────────────────────────────────────
enum State { DORMANT, PATROL, CHASE, ATTACK, DEATH }
var state: State = State.DORMANT

# ── Runtime vars ───────────────────────────────────────────────────
var hp           : int        = MAX_HP
var _is_dead     : bool       = false
var _player      : Node2D     = null   # set when player enters detection area
var _attack_timer: float      = 0.0

# Patrol / path following
var _path_points  : PackedVector2Array = []
var _path_index   : int    = 0
var _path_forward : bool   = true      # ping-pong direction

# ── Node refs ──────────────────────────────────────────────────────
@onready var sprite   : AnimatedSprite2D           = $AnimatedSprite2D
@onready var audio    : AudioStreamPlayer2D        = $AudioStreamPlayer2D
@onready var body     : CollisionShape2D           = $CollisionShape2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var detect_area: Area2D                   = $DetectArea   # see scene guide


# ══════════════════════════════════════════════════════════════════
#  READY
# ══════════════════════════════════════════════════════════════════
func _ready() -> void:
	# collision_layer 2  = enemy bodies.
	# collision_mask  1  = world/tilemap layer so the bug stays on the ground.
	# The player body (layer 1) is intentionally NOT in the mask so the enemy
	# doesn't physically push the character — proximity is handled via DetectArea.
	# NOTE: the player's weapon hitboxes are on layer 3, mask 2, so they CAN
	# still detect this enemy body without any physical push happening.
	collision_layer = 2
	collision_mask  = 1   # world tiles only — do NOT add the player layer here

	# Start dormant – only wake up when on screen
	set_process(false)
	set_physics_process(false)
	sprite.play("Enemy_Movement")

	# Screen visibility signals
	screen_notifier.screen_entered.connect(_on_screen_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)

	# Detection area signals (Area2D child named DetectArea)
	# Mask 1 = player body layer only, so weapons (layer 3) don't trigger chase.
	detect_area.collision_mask = 1
	detect_area.body_entered.connect(_on_detect_body_entered)
	detect_area.body_exited.connect(_on_detect_body_exited)

	# Grab path points from a Path2D sibling (optional)
	_init_path()


# ══════════════════════════════════════════════════════════════════
#  PATH INITIALISATION
#  The bug looks for a Path2D node named "EnemyPath" in its parent.
#  If found it follows those waypoints; otherwise it just idles.
# ══════════════════════════════════════════════════════════════════
func _init_path() -> void:
	var parent = get_parent()
	if parent is Path2D:
		_path_points = parent.curve.get_baked_points()


# ══════════════════════════════════════════════════════════════════
#  SCREEN NOTIFIER  –  sleep / wake
# ══════════════════════════════════════════════════════════════════
func _on_screen_entered() -> void:
	if _is_dead:
		return
	set_process(true)
	set_physics_process(true)
	if state == State.DORMANT:
		state = State.PATROL
		sprite.play("Enemy_Movement")

func _on_screen_exited() -> void:
	# Freeze processing when off-screen to save CPU / render memory
	set_process(false)
	set_physics_process(false)


# ══════════════════════════════════════════════════════════════════
#  DETECTION AREA  –  player enter / exit
# ══════════════════════════════════════════════════════════════════
func _on_detect_body_entered(body_node: Node2D) -> void:
	if body_node.is_in_group("player"):
		_player = body_node
		if not _is_dead:
			state = State.CHASE

func _on_detect_body_exited(body_node: Node2D) -> void:
	if body_node == _player:
		_player = null
		if not _is_dead:
			state = State.PATROL


# ══════════════════════════════════════════════════════════════════
#  PROCESS  –  attack cooldown timer
# ══════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta


# ══════════════════════════════════════════════════════════════════
#  PHYSICS PROCESS  –  movement & attack
# ══════════════════════════════════════════════════════════════════
func _physics_process(_delta: float) -> void:
	match state:
		State.PATROL:
			_do_patrol()
		State.CHASE:
			_do_chase()
		State.ATTACK:
			velocity = Vector2.ZERO   # stand still while attacking
			_do_attack()
	move_and_slide()


# ── Patrol ─────────────────────────────────────────────────────────
func _do_patrol() -> void:
	if _path_points.is_empty():
		velocity = Vector2.ZERO
		return

	var target: Vector2 = _path_points[_path_index]
	var dir: Vector2    = (target - global_position)

	if dir.length() < 4.0:          # reached waypoint
		_advance_path_index()
	else:
		velocity = dir.normalized() * MOVE_SPEED
		_flip_sprite(velocity.x)


func _advance_path_index() -> void:
	if _path_forward:
		_path_index += 1
		if _path_index >= _path_points.size():
			_path_forward = false
			_path_index   = _path_points.size() - 2
	else:
		_path_index -= 1
		if _path_index < 0:
			_path_forward = true
			_path_index   = 1


# ── Chase & attack ─────────────────────────────────────────────────
func _do_chase() -> void:
	if not is_instance_valid(_player):
		state = State.PATROL
		return

	var dist: float  = global_position.distance_to(_player.global_position)
	var dir: Vector2 = (_player.global_position - global_position).normalized()

	if dist <= ATTACK_RANGE:
		state = State.ATTACK
		_try_attack()
	else:
		state = State.CHASE
		velocity = dir * CHASE_SPEED
		_flip_sprite(velocity.x)


## Called every physics frame while in ATTACK state.
## Re-evaluates distance so the bug returns to chase if the player
## moves out of range, and fires _try_attack() whenever the cooldown allows.
func _do_attack() -> void:
	if not is_instance_valid(_player):
		state = State.PATROL
		return

	var dist: float = global_position.distance_to(_player.global_position)
	if dist > ATTACK_RANGE:
		# Player escaped — go back to chasing.
		state = State.CHASE
		return

	# Player still in range — attempt another attack (timer guards frequency).
	_try_attack()


func _try_attack() -> void:
	# Cooldown not yet expired or animation still playing — wait.
	if _attack_timer > 0.0:
		return
	if not is_instance_valid(_player):
		return

	_attack_timer = ATTACK_COOLDOWN
	sprite.play("Enemy_Attack")
	sprite.animation_finished.connect(_on_attack_anim_finished, CONNECT_ONE_SHOT)

	# Deal damage to player – expects player to have take_damage(amount) method.
	if _player.has_method("take_damage"):
		_player.take_damage(ATTACK_DAMAGE)

	if not audio.playing:
		audio.play()


func _on_attack_anim_finished() -> void:
	if _is_dead:
		return
	# Resume movement animation; state machine will decide next action.
	sprite.play("Enemy_Movement")
	# Stay in ATTACK state if still in range — _do_attack() will re-fire
	# _try_attack() once the cooldown expires.  Switch to CHASE only if the
	# player has moved out of range or gone invalid.
	if not is_instance_valid(_player):
		state = State.PATROL
	elif global_position.distance_to(_player.global_position) > ATTACK_RANGE:
		state = State.CHASE
	# else: remain State.ATTACK — next _do_attack() call retries automatically.


# ── Sprite flip helper ─────────────────────────────────────────────
# The sprite sheet's default facing direction is LEFT.
# So we flip_h when moving RIGHT (x_vel > 0), not left.
func _flip_sprite(x_vel: float) -> void:
	if x_vel != 0.0:
		sprite.flip_h = x_vel > 0.0


# ══════════════════════════════════════════════════════════════════
#  TAKE DAMAGE  –  called by effect_combat.gd (or any weapon Area2D)
#
#  Signature:  take_damage(amount, weapon_type, sub_type)
#
#  weapon_type : "bow" | "magic" | "lance" | "sword"
#  sub_type    : only used for lance – "pierce" or "thrust"
#                (ignored for other weapons)
#
#  Examples:
#    enemy.take_damage(0, "bow")            → applies 3
#    enemy.take_damage(0, "magic")          → applies 5–10 random
#    enemy.take_damage(0, "lance", "pierce")→ applies 2
#    enemy.take_damage(0, "lance", "thrust")→ applies 5
#    enemy.take_damage(0, "sword")          → applies 1–2 random
#    enemy.take_damage(4)                   → legacy fallback, applies 4
# ══════════════════════════════════════════════════════════════════
func take_damage(amount: int = 1,
				 weapon_type: String = "",
				 sub_type: String = "") -> void:
	if _is_dead:
		return

	var final_dmg: int = _resolve_damage(amount, weapon_type, sub_type)
	hp -= final_dmg

	# Visual hit flash
	sprite.modulate = Color(1.5, 0.3, 0.3)
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(self) and not _is_dead:
			sprite.modulate = Color.WHITE
	)

	if not audio.playing:
		audio.play()

	if hp <= 0:
		_die()


# ── Damage resolver ────────────────────────────────────────────────
func _resolve_damage(fallback: int,
					  weapon_type: String,
					  sub_type: String) -> int:
	if weapon_type == "" or not WEAPON_DAMAGE.has(weapon_type):
		return fallback          # legacy / unknown weapon → use raw amount

	var entry = WEAPON_DAMAGE[weapon_type]

	# Lance has sub-types
	if weapon_type == "lance":
		var key: String = sub_type if sub_type != "" else "thrust"
		return entry.get(key, fallback)

	# Fixed value
	if entry is int:
		return entry

	# Random range [min, max]
	if entry is Array and entry.size() == 2:
		return randi_range(entry[0], entry[1])

	return fallback


# ══════════════════════════════════════════════════════════════════
#  DEATH
# ══════════════════════════════════════════════════════════════════
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
