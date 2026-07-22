class_name ExpeditionTierDefinition
extends Resource

@export_range(1, 10, 1) var tier := 1
@export var display_name := ""
@export_range(1, 100, 1) var wave_count := 1
@export var difficulty_multiplier := 1.0
@export var enemy_count_multiplier := 1.0
@export var spawn_rate_multiplier := 1.0
@export_range(0, 100, 1) var guaranteed_elite_count := 0
@export_range(0.0, 1.0, 0.01) var elite_chance := 0.0
@export var boss_id: StringName
@export_range(0, 100000, 1) var reward_gold := 0
@export_range(0.0, 1.0, 0.01) var repeat_reward_multiplier := 0.5

func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if tier < 1 or tier > 10:
		errors.append("tier must be between 1 and 10")
	if display_name.is_empty():
		errors.append("display_name cannot be empty")
	if wave_count < 1:
		errors.append("wave_count must be at least 1")
	if difficulty_multiplier <= 0.0:
		errors.append("difficulty_multiplier must be positive")
	if enemy_count_multiplier <= 0.0:
		errors.append("enemy_count_multiplier must be positive")
	if spawn_rate_multiplier <= 0.0:
		errors.append("spawn_rate_multiplier must be positive")
	if guaranteed_elite_count < 0:
		errors.append("guaranteed_elite_count cannot be negative")
	if elite_chance < 0.0 or elite_chance > 1.0:
		errors.append("elite_chance must be between 0 and 1")
	if reward_gold < 0:
		errors.append("reward_gold cannot be negative")
	if repeat_reward_multiplier < 0.0 or repeat_reward_multiplier > 1.0:
		errors.append("repeat_reward_multiplier must be between 0 and 1")
	return errors
