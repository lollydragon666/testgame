class_name LancerEnemy
extends EnemyBase

var attack_cooldown := 0.5
var thrust_time := 0.0

func _init() -> void:
	enemy_kind = "lancer"
	hit_radius = 27.0
	max_health = 96.0
	move_speed = 70.0
	contact_damage = 18.0
	experience_value = 30

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	thrust_time = maxf(0.0, thrust_time - delta)
	var distance := world_position.distance_to(player.world_position)
	if distance > 138.0:
		move_toward_player(delta)
	elif attack_cooldown <= 0.0:
		attack_cooldown = 1.45
		thrust_time = 0.32
		if distance <= 158.0:
			damage_player()

func _draw() -> void:
	var body := health_color(Color("806a45"))
	var diamond := PackedVector2Array([Vector2(0.0, -hit_radius), Vector2(hit_radius, 0.0), Vector2(0.0, hit_radius), Vector2(-hit_radius, 0.0)])
	draw_colored_polygon(diamond, body)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("574637"), 2.0)
	var direction := IsoMath.world_to_screen((player.world_position - world_position).normalized()).normalized()
	var extension := 95.0 if thrust_time > 0.0 else 65.0
	draw_line(direction * 8.0, direction * extension, Color("714725"), 7.0)
	draw_line(direction * (extension - 22.0), direction * extension, Color("d4c4a4"), 10.0)
	draw_health_bar(58.0)

