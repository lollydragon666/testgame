class_name EnemyMovementController
extends RefCounted

var host: EnemyBase

func configure(enemy: EnemyBase) -> void:
	host = enemy

func approach(direction: Vector2, delta: float, speed_multiplier := 1.0) -> void:
	if host != null and not direction.is_zero_approx():
		host.world_position += direction.normalized() * host.move_speed * speed_multiplier * delta

func retreat(direction_to_target: Vector2, delta: float, speed_multiplier := 1.0) -> void:
	approach(-direction_to_target, delta, speed_multiplier)

func strafe(direction_to_target: Vector2, side: float, delta: float, speed_multiplier := 1.0) -> void:
	approach(direction_to_target.orthogonal() * side, delta, speed_multiplier)
