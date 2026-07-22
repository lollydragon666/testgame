class_name BrawlerEnemy
extends EnemyBase

const PUNCH_DURATION := 0.42

var attack_cooldown := 0.65
var punch_time := 0.0
## Знак выбирает левую или правую руку для следующей анимации.
var punch_side := 1.0
## Урон откладывается до середины движения кулака.
var punch_pending := false

func _init() -> void:
	enemy_kind = GameIds.ENEMY_BRAWLER
	visual_radius = 23.0
	collision_radius = 23.0
	max_health = 64.0
	move_speed = 76.0
	contact_damage = 11.0
	experience_value = 17

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if punch_time > 0.0:
		punch_time = maxf(0.0, punch_time - delta)
		if punch_pending and punch_time <= PUNCH_DURATION * 0.48:
			punch_pending = false
			if world_position.distance_to(player.world_position) <= 72.0:
				damage_player()
		return
	var distance := world_position.distance_to(player.world_position)
	if distance > 58.0:
		move_toward_player(delta)
	elif attack_cooldown <= 0.0:
		attack_cooldown = 1.45
		punch_time = PUNCH_DURATION
		punch_pending = true
		punch_side *= -1.0
		visual_root.play_attack()
