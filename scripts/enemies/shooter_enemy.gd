class_name ShooterEnemy
extends EnemyBase

var shot_cooldown := 1.6
var strafe_sign := 1.0

func _init() -> void:
	enemy_kind = GameIds.ENEMY_SHOOTER
	visual_radius = 22.0
	collision_radius = 22.0
	max_health = 54.0
	move_speed = 62.0
	contact_damage = 10.0
	experience_value = 26
	strafe_sign = -1.0 if randf() < 0.5 else 1.0

func tick_behavior(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	var offset: Vector2 = player.world_position - world_position
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.001 else Vector2.RIGHT
	if distance < 300.0:
		world_position -= direction * move_speed * delta
	elif distance > 430.0:
		world_position += direction * move_speed * delta
	world_position += direction.orthogonal() * strafe_sign * move_speed * 0.42 * delta
	if distance < 620.0 and shot_cooldown <= 0.0:
		shot_cooldown = 2.35
		projectile_requested.emit(world_position, direction, 12.0)
