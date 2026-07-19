class_name LightningMage
extends MageEnemyBase

func _init() -> void:
	enemy_kind = "lightning_mage"
	spell_kind = "lightning"
	magic_color = Color("397fe8")
	max_health = 72.0
	move_speed = 61.0
	spell_damage = 14.0
	cast_interval = 2.55
	experience_value = 34

