extends CharacterBody2D

@export var speed = 200

func _physics_process(delta):

	velocity = Vector2.ZERO

	if Input.is_action_pressed("Right"):
		velocity.x += 1

	if Input.is_action_pressed("Left"):
		velocity.x -= 1

	if Input.is_action_pressed("Up"):
		velocity.y -= 1

	if Input.is_action_pressed("Down"):
		velocity.y += 1


	if velocity != Vector2.ZERO:

		velocity = velocity.normalized() * speed

		# Pick dominant direction
		if abs(velocity.x) > abs(velocity.y):

			if velocity.x > 0:
				$AnimatedSprite2D.play("Walk_Right")
			else:
				$AnimatedSprite2D.play("Walk_Left")

		else:

			if velocity.y > 0:
				$AnimatedSprite2D.play("Walk_Down")
			else:
				$AnimatedSprite2D.play("Walk_Up")

	else:
		$AnimatedSprite2D.stop()

	move_and_slide()
