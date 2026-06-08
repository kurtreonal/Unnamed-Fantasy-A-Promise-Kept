extends Area2D

@export var enemy_scene: PackedScene
@export var spawn_count: int = 10       # how many bugs to spawn
@export var path: Path2D                # drag EnemyPath here in inspector

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
		# pick a random point on the path
		var random_point: Vector2 = points[randi() % points.size()]

		var enemy = enemy_scene.instantiate()
		# call_deferred avoids the "flushing queries" crash when spawning
		# from inside a body_entered physics callback
		path.call_deferred("add_child", enemy)
		enemy.set_deferred("global_position", random_point)
