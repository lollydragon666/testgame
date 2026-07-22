class_name EnemyDefinition
extends Resource

enum EnemyClass {
	SWORDSMAN,
	RAIDER,
	BRUTE,
	SHIELD_BEARER,
	SPEARMAN,
	ARCHER,
	HEALER,
	COMMANDER,
	SUMMONER,
	BOMBER,
	SUMMONED_MINION,
}

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var visual_definition: CharacterVisualDefinition
@export var enemy_class := EnemyClass.SWORDSMAN
@export var visual_radius := 24.0
@export var collision_radius := 24.0
@export var max_health := 70.0
@export var move_speed := 72.0
@export var contact_damage := 12.0
@export var defense := 0.0
@export var attack_damage := 12.0
@export var attack_range := 72.0
@export var attack_cooldown := 1.4
@export var attack_windup := 0.28
@export var attack_active_time := 0.08
@export var attack_recovery := 0.30
@export var preferred_distance := 64.0
@export var retreat_distance := 0.0
@export var ability_cooldown := 0.0
@export var ability_power := 0.0
@export var experience_value := 18
@export var spawn_distance := 620.0
@export var is_boss := false
@export var introduced_wave := 1
@export var spawn_weight := 1.0
@export var max_alive := 0
@export var max_per_wave := 0
@export var counts_for_wave := true
@export var grants_experience := true
@export var grants_loot := true
@export var loot_table_id: StringName = &"normal"

func is_valid_definition() -> bool:
	return (
		not id.is_empty()
		and not display_name.is_empty()
		and scene != null
		and visual_definition != null
		and max_health > 0.0
		and move_speed >= 0.0
		and attack_damage >= 0.0
		and attack_range >= 0.0
		and attack_cooldown >= 0.0
		and introduced_wave > 0
	)
