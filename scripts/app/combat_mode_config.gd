class_name CombatModeConfig
extends Resource

const MODE_EXPEDITION := &"expedition"
const MODE_SANDBOX := &"combat_sandbox"

@export var mode_id: StringName
@export var enable_rewards := false
@export var enable_profile_bonuses := false
@export var enable_auto_waves := false
@export var enable_level_up_choices := true
@export var return_target: StringName
@export var debug_controls_enabled := false

static func expedition() -> CombatModeConfig:
	var config := CombatModeConfig.new()
	config.mode_id = MODE_EXPEDITION
	config.enable_rewards = true
	config.enable_profile_bonuses = true
	config.enable_auto_waves = true
	config.enable_level_up_choices = true
	config.return_target = &"hub"
	return config

static func sandbox() -> CombatModeConfig:
	var config := CombatModeConfig.new()
	config.mode_id = MODE_SANDBOX
	config.enable_rewards = false
	config.enable_profile_bonuses = false
	config.enable_auto_waves = false
	config.enable_level_up_choices = true
	config.return_target = &"main_menu"
	config.debug_controls_enabled = true
	return config
