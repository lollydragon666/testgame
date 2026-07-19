class_name BossEnemy
extends EnemyBase

var attack_cooldown := 1.8
var windup := 0.0
var attack_applied := false

func _init() -> void:
	enemy_kind = "boss"
	hit_radius = 58.0
	max_health = 920.0
	move_speed = 34.0
	contact_damage = 36.0
	experience_value = 300

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.28 and not attack_applied:
			attack_applied = true
			if world_position.distance_to(player.world_position) <= 185.0:
				damage_player()
		return
	var distance := world_position.distance_to(player.world_position)
	if distance > 142.0:
		move_toward_player(delta)
	elif attack_cooldown <= 0.0:
		attack_cooldown = 4.5
		windup = 1.4
		attack_applied = false

func _draw() -> void:
	draw_set_transform(Vector2(0.0, 17.0), 0.0, Vector2(1.35, 0.46))
	draw_circle(Vector2.ZERO, hit_radius, Color(0.01, 0.008, 0.008, 0.52))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := health_color(Color("8f4623"))
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), Color("d0ad64"), false, 4.0)
	var direction := IsoMath.world_to_screen((player.world_position - world_position).normalized()).normalized()
	var axe_angle := -1.5 if windup > 0.28 else 0.45
	direction = direction.rotated(axe_angle)
	draw_line(direction * 24.0, direction * 110.0, Color("35271d"), 12.0)
	var head_center := direction * 105.0
	var side := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([head_center - side * 30.0, head_center + direction * 28.0, head_center + side * 30.0, head_center - direction * 8.0]), Color("574637"))
	draw_health_bar(125.0)
