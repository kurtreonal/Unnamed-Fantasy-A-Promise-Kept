extends Area2D

var player_in_range = false
var is_open = false

func _ready():
	print("Chest loaded")

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		print("Character near chest")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		print("Player left chest")

func _process(_delta):
	if player_in_range and not is_open and Input.is_action_just_pressed("interact"):
		open_chest()

func open_chest():
	is_open = true
	print("Chest opened!")
	$AnimatedSprite2D.play("Chest_Animation")
