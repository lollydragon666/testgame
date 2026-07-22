class_name LancerEnemy
extends EnemyBase

const THRUST_DURATION := 0.32
## Максимальная дистанция наконечника копья в момент попадания.
const ATTACK_RANGE := 158.0
## Момент урона внутри выпада; до него игрок ещё может увернуться.
const HIT_FRAME_REMAINING_RATIO := 0.45

var attack_cooldown := 1.0
var thrust_time := 0.0
## Один выпад может применить урон только один раз.
var hit_pending := false

func _init() -> void:
	enemy_kind = GameIds.ENEMY_LANCER
	visual_radius = 27.0
	collision_radius = 27.0
	max_health = 96.0
	move_speed = 70.0
	contact_damage = 18.0
	experience_value = 30

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if thrust_time > 0.0:
		thrust_time = maxf(0.0, thrust_time - delta)
		if hit_pending and thrust_time <= THRUST_DURATION * HIT_FRAME_REMAINING_RATIO:
			hit_pending = false
			if world_position.distance_to(player.world_position) <= ATTACK_RANGE:
				damage_player()
		if thrust_time <= 0.0:
			hit_pending = false
		return
	var distance := world_position.distance_to(player.world_position)
	if distance > 138.0:
		move_toward_player(delta)
	elif attack_cooldown <= 0.0:
		attack_cooldown = 2.05
		thrust_time = THRUST_DURATION
		hit_pending = true
		visual_root.play_attack()
