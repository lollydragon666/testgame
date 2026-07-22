class_name MeleeEnemy
extends EnemyBase

const SWING_DURATION := 0.38
const SWING_START := -1.0
const SWING_END := 0.9
## Дистанция повторно проверяется именно на ударном кадре.
const ATTACK_RANGE := 72.0
## Доля оставшегося времени анимации, при которой клинок наносит урон.
const HIT_FRAME_REMAINING_RATIO := 0.45

var attack_cooldown := 0.45
var weapon_phase := 0.0
var swing_time := 0.0
var swing_direction := 1.0
var next_swing_direction := 1.0
## Сбрасывается после первого попадания или промаха, исключая двойной урон.
var hit_pending := false

func _init() -> void:
	enemy_kind = GameIds.ENEMY_MELEE
	visual_radius = 25.0
	collision_radius = 25.0
	max_health = 82.0
	move_speed = 78.0
	contact_damage = 14.0
	experience_value = 22

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if swing_time > 0.0:
		swing_time = maxf(0.0, swing_time - delta)
		if hit_pending and swing_time <= SWING_DURATION * HIT_FRAME_REMAINING_RATIO:
			hit_pending = false
			if world_position.distance_to(player.world_position) <= ATTACK_RANGE:
				damage_player()
		if swing_time <= 0.0:
			hit_pending = false
		return
	weapon_phase = fmod(weapon_phase + delta * 5.8, TAU)
	var distance := world_position.distance_to(player.world_position)
	if distance > 62.0:
		distance = move_toward_player(delta)
	if distance <= ATTACK_RANGE and attack_cooldown <= 0.0:
		attack_cooldown = 1.25
		swing_time = SWING_DURATION
		swing_direction = next_swing_direction
		next_swing_direction *= -1.0
		hit_pending = true

func _swing_start_offset() -> float:
	return SWING_START if swing_direction > 0.0 else SWING_END

func _swing_end_offset() -> float:
	return SWING_END if swing_direction > 0.0 else SWING_START

func _swing_offset() -> float:
	var progress := 1.0 - swing_time / SWING_DURATION
	return lerpf(_swing_start_offset(), _swing_end_offset(), ease(progress, -2.2))
