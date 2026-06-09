extends Area2D
# enemy_spawner.gd
# Modifications from original:
#   • Added @export coin_pickup_scene  — drag CoinPickup.tscn here in inspector.
#   • Added @export coin_per_enemy     — coins awarded per kill (default 1).
#   • Connected to each enemy's "died" signal after spawning so a coin is
#     dropped at the enemy's last known position when it is defeated.
#     If your enemy script emits a different signal name, update ENEMY_DEATH_SIGNAL.

@export var enemy_scene:       PackedScene
@export var coin_pickup_scene: PackedScene   # assign CoinPickup.tscn in Inspector
@export var spawn_count:       int = 100     # how many bugs to spawn
@export var path:              Path2D        # drag EnemyPath here in inspector
@export var coin_per_enemy:    int = 1       # coins per kill

# Change this if your enemy script uses a different signal name.
const ENEMY_DEATH_SIGNAL := "died"

var _spawned: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _spawned:
		return
	if not body.is_in_group("player"):
		return

	_spawned = true
	_spawn_enemies()


func _spawn_enemies() -> void:
	if path == null or enemy_scene == null:
		return

	var points: PackedVector2Array = path.curve.get_baked_points()
	if points.is_empty():
		return

	for i in spawn_count:
		# Pick a random point on the path.
		var random_point: Vector2 = points[randi() % points.size()]

		var enemy = enemy_scene.instantiate()

		# Wire coin drop before the enemy is added to the tree so the signal
		# connection is in place by the time the enemy can die.
		if enemy.has_signal(ENEMY_DEATH_SIGNAL):
			enemy.connect(ENEMY_DEATH_SIGNAL, _on_enemy_died.bind(enemy))
		else:
			# Fallback: connect via tree_exiting so any enemy works even without
			# a custom "died" signal, though position accuracy may vary.
			enemy.connect("tree_exiting", _on_enemy_tree_exiting.bind(enemy))

		# call_deferred avoids the "flushing queries" crash when spawning
		# from inside a body_entered physics callback.
		path.call_deferred("add_child", enemy)
		enemy.set_deferred("global_position", random_point)


# ─── Coin drop helpers ───────────────────────────────────────────

func _on_enemy_died(enemy: Node2D) -> void:
	# Called by the enemy's own "died" signal — most reliable position.
	_drop_coin_at(enemy.global_position)


func _on_enemy_tree_exiting(enemy: Node2D) -> void:
	# Fallback: called just before the node leaves the tree.
	# global_position is still valid at this point.
	_drop_coin_at(enemy.global_position)


func _drop_coin_at(world_position: Vector2) -> void:
	if coin_pickup_scene == null:
		push_warning("[EnemySpawner] coin_pickup_scene not assigned — no coin will drop.")
		return

	var coin = coin_pickup_scene.instantiate()

	# Set coin value if the script exposes the property.
	if "coin_value" in coin:
		coin.coin_value = coin_per_enemy

	# Add the coin to the same parent as the spawner so it lives in world space.
	var parent := get_parent()
	if parent:
		parent.call_deferred("add_child", coin)
		coin.set_deferred("global_position", world_position)
	else:
		push_warning("[EnemySpawner] No parent to attach coin to.")
