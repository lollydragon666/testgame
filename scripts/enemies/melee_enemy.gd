class_name MeleeEnemy
extends EnemyBase

const SWING_DURATION := 0.38
const SWING_START := -1.0
const SWING_END := 0.9

var attack_cooldown := 0.45
var weapon_phase := 0.0
var swing_time := 0.0
var swing_direction := 1.0
var next_swing_direction := 1.0

func _init() -> void:
	enemy_kind = "melee"
	hit_radius = 25.0
	max_health = 82.0
	move_speed = 78.0
	contact_damage = 14.0
	experience_value = 22

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	swing_time = maxf(0.0, swing_time - delta)
	weapon_phase = fmod(weapon_phase + delta * 5.8, TAU)
	var distance := world_position.distance_to(player.world_position)
	if distance > 62.0:
		distance = move_toward_player(delta)
	if distance <= 72.0 and attack_cooldown <= 0.0:
		attack_cooldown = 1.25
		swing_time = SWING_DURATION
		swing_direction = next_swing_direction
		next_swing_direction *= -1.0
		damage_player()

func _draw() -> void:
	draw_set_transform(Vector2(0.0, 9.0), 0.0, Vector2(1.25, 0.45))
	draw_circle(Vector2.ZERO, hit_radius, Color(0.01, 0.008, 0.008, 0.36))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := health_color(Color("405d32"))
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), Color("574637"), false, 2.0)
	var aim_screen := IsoMath.world_to_screen((player.world_position - world_position).normalized()).normalized()
	var base_angle := aim_screen.angle()
	var sword_offset := sin(weapon_phase) * 0.18
	if swing_time > 0.0:
		sword_offset = _swing_offset()
		_draw_swing_trail(base_angle)
	var sword_direction := Vector2.from_angle(base_angle + sword_offset)
	draw_line(sword_direction * 16.0, sword_direction * 58.0, Color("d4c4a4"), 6.0)
	draw_line(sword_direction * 20.0 - sword_direction.orthogonal() * 10.0, sword_direction * 20.0 + sword_direction.orthogonal() * 10.0, Color("a8874d"), 5.0)
	draw_health_bar(55.0)

func _swing_start_offset() -> float:
	return SWING_START if swing_direction > 0.0 else SWING_END

func _swing_end_offset() -> float:
	return SWING_END if swing_direction > 0.0 else SWING_START

func _swing_offset() -> float:
	var progress := 1.0 - swing_time / SWING_DURATION
	return lerpf(_swing_start_offset(), _swing_end_offset(), ease(progress, -2.2))

func _draw_swing_trail(base_angle: float) -> void:
	var start_offset := _swing_start_offset()
	var current_offset := _swing_offset()
	var trail := PackedVector2Array()
	for index in 20:
		var progress := float(index) / 19.0
		var angle := base_angle + lerpf(start_offset, current_offset, progress)
		trail.append(Vector2.from_angle(angle) * 58.0)
	draw_polyline(trail, Color(0.31, 0.49, 0.25, 0.68), 8.0)
