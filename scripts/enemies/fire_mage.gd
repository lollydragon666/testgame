class_name FireMage
extends MageEnemyBase

func _init() -> void:
	enemy_kind = "fire_mage"
	spell_kind = "fireball"
	magic_color = Color("c92e1c")
	max_health = 96.0
	move_speed = 54.0
	spell_damage = 19.0
	cast_interval = 3.1
	experience_value = 42

