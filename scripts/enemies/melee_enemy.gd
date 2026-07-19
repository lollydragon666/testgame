class_name MeleeEnemy
extends EnemyBase

var attack_cooldown := 0.0
var weapon_phase := 0.0

func _init() -> void:
	enemy_kind = "melee"
	hit_radius = 25.0
	max_health = 82.0
	move_speed = 78.0
	contact_damage = 14.0
	experience_value = 22

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	weapon_phase = fmod(weapon_phase + delta * 5.8, TAU)
	var distance := world_position.distance_to(player.world_position)
	if distance > 62.0:
		distance = move_toward_player(delta)
	if distance <= 72.0 and attack_cooldown <= 0.0:
		attack_cooldown = 0.82
		damage_player()

func _draw() -> void:
	draw_set_transform(Vector2(0.0, 9.0), 0.0, Vector2(1.25, 0.45))
	draw_circle(Vector2.ZERO, hit_radius, Color(0.01, 0.008, 0.008, 0.36))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := health_color(Color("405d32"))
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), Color("574637"), false, 2.0)
	var aim_screen := IsoMath.world_to_screen((player.world_position - world_position).normalized()).normalized()
	var sword_direction := aim_screen.rotated(sin(weapon_phase) * 0.72)
	draw_line(sword_direction * 16.0, sword_direction * 58.0, Color("d4c4a4"), 6.0)
	draw_line(sword_direction * 20.0 - sword_direction.orthogonal() * 10.0, sword_direction * 20.0 + sword_direction.orthogonal() * 10.0, Color("a8874d"), 5.0)
	draw_health_bar(55.0)

