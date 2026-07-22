class_name PlayerStats
extends RefCounted

const MAX_CRITICAL_CHANCE := 0.75

var weapon_definition: WeaponDefinition
var weapon_instance: ItemInstance
var damage_bonus := 0.0
var defense := 0.0
var max_health_bonus := 0.0
var movement_speed_bonus := 0.0
var attack_speed_bonus := 0.0
var critical_chance := 0.0
var critical_damage := 1.5
var loot_chance := 0.0

func finalize() -> void:
	damage_bonus = maxf(-0.95, damage_bonus)
	defense = maxf(0.0, defense)
	max_health_bonus = maxf(0.0, max_health_bonus)
	movement_speed_bonus = maxf(-0.75, movement_speed_bonus)
	attack_speed_bonus = maxf(-0.75, attack_speed_bonus)
	critical_chance = clampf(critical_chance, 0.0, MAX_CRITICAL_CHANCE)
	critical_damage = maxf(1.0, critical_damage)
	loot_chance = maxf(0.0, loot_chance)

func reduced_damage(incoming_damage: float) -> float:
	return maxf(0.0, incoming_damage) * 100.0 / (100.0 + maxf(0.0, defense))
