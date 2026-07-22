class_name EntityHurtbox
extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func set_collision_radius(value: float) -> void:
	var circle := collision_shape.shape as CircleShape2D
	if circle == null:
		push_error("EntityHurtbox requires a CircleShape2D")
		return
	circle.radius = value
