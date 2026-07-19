class_name ShooterEnemy
extends EnemyBase

var shot_cooldown := 1.1
var strafe_sign := 1.0

func _init() -> void:
	enemy_kind = "shooter"
	hit_radius = 22.0
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
		shot_cooldown = 1.65
		projectile_requested.emit(world_position, direction, 12.0)

func _draw() -> void:
	draw_set_transform(Vector2(0.0, 8.0), 0.0, Vector2(1.25, 0.45))
	draw_circle(Vector2.ZERO, hit_radius, Color(0.01, 0.008, 0.008, 0.36))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := health_color(Color("8f211d"))
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), Color("d4c4a4"), false, 2.0)
	draw_circle(Vector2.ZERO, 7.0, Color("040303"))
	draw_health_bar(50.0)

