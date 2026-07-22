class_name BossEnemy
extends EnemyBase

var attack_cooldown := 1.8
## Оставшееся время большого читаемого замаха топором.
var windup := 0.0
## Защита от повторного урона в пределах одной атаки босса.
var attack_applied := false

func _init() -> void:
	enemy_kind = GameIds.ENEMY_BOSS
	visual_radius = 58.0
	collision_radius = 58.0
	max_health = 920.0
	move_speed = 34.0
	contact_damage = 36.0
	experience_value = 300

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if windup > 0.0:
		windup -= delta
		# Удар происходит ближе к концу замаха, оставляя игроку время выйти из зоны.
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
