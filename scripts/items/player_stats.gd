class_name PlayerStats
extends RefCounted

const MAX_CRITICAL_CHANCE := 0.75
const MINIMUM_CRITICAL_DAMAGE := 1.5
const MAXIMUM_CRITICAL_DAMAGE := 4.0
const MINIMUM_MOVEMENT_MULTIPLIER := 0.5
const MAXIMUM_MOVEMENT_MULTIPLIER := 2.0

var weapon_definition: WeaponDefinition
var weapon_instance: ItemInstance
var flat_damage_bonus := 0.0
var damage_percent_bonus := 0.0
var damage_bonus: float:
	get:
		return damage_percent_bonus
	set(value):
		damage_percent_bonus = value
var defense := 0.0
var max_health_bonus := 0.0
var movement_speed_bonus := 0.0
var attack_speed_bonus := 0.0
var attack_reach_bonus := 0.0
var attack_width_bonus := 0.0
var critical_chance := 0.0
var critical_damage := MINIMUM_CRITICAL_DAMAGE
var loot_chance := 0.0

func finalize() -> void:
	flat_damage_bonus = maxf(0.0, flat_damage_bonus)
	damage_percent_bonus = maxf(-0.95, damage_percent_bonus)
	defense = maxf(0.0, defense)
	max_health_bonus = maxf(0.0, max_health_bonus)
	movement_speed_bonus = clampf(
		movement_speed_bonus,
		MINIMUM_MOVEMENT_MULTIPLIER - 1.0,
		MAXIMUM_MOVEMENT_MULTIPLIER - 1.0
	)
	attack_speed_bonus = maxf(-0.75, attack_speed_bonus)
	attack_reach_bonus = maxf(-0.5, attack_reach_bonus)
	attack_width_bonus = maxf(-0.5, attack_width_bonus)
	critical_chance = clampf(critical_chance, 0.0, MAX_CRITICAL_CHANCE)
	critical_damage = clampf(critical_damage, MINIMUM_CRITICAL_DAMAGE, MAXIMUM_CRITICAL_DAMAGE)
	loot_chance = maxf(0.0, loot_chance)

func damage_multiplier() -> float:
	return maxf(0.05, 1.0 + damage_percent_bonus)

func movement_multiplier() -> float:
	return clampf(
		1.0 + movement_speed_bonus,
		MINIMUM_MOVEMENT_MULTIPLIER,
		MAXIMUM_MOVEMENT_MULTIPLIER
	)

func reach_multiplier() -> float:
	return maxf(0.5, 1.0 + attack_reach_bonus)

func width_multiplier() -> float:
	return maxf(0.5, 1.0 + attack_width_bonus)

func reduced_damage(incoming_damage: float) -> float:
	return maxf(0.0, incoming_damage) * 100.0 / (100.0 + maxf(0.0, defense))
