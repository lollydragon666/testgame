extends Node

enum Mode {
	MENU,
	HUB,
	EXPEDITION,
	COMBAT_SANDBOX,
}

const HEALTH_UPGRADE_COST := 50
const HEALTH_UPGRADE_AMOUNT := 10.0

var profile := PlayerProfile.new()
var selected_location_id: StringName = &"test_location"
var current_run_seed := 0
var last_expedition_result: ExpeditionResult
var current_mode := Mode.MENU

func set_mode(mode: Mode) -> void:
	current_mode = mode

func enter_menu() -> void:
	current_mode = Mode.MENU

func enter_hub() -> void:
	current_mode = Mode.HUB

func enter_combat_sandbox() -> void:
	current_mode = Mode.COMBAT_SANDBOX

func begin_expedition(location_id: StringName) -> bool:
	if not profile.is_location_unlocked(location_id):
		return false
	selected_location_id = location_id
	current_run_seed = randi()
	last_expedition_result = null
	current_mode = Mode.EXPEDITION
	return true

func claim_expedition_result(result: ExpeditionResult) -> bool:
	if result == null or result.reward_claimed:
		return false
	result.reward_claimed = true
	profile.gold += maxi(0, result.earned_gold)
	profile.completed_expeditions += 1
	last_expedition_result = result
	return true

func purchase_health_upgrade() -> bool:
	if profile.gold < HEALTH_UPGRADE_COST:
		return false
	profile.gold -= HEALTH_UPGRADE_COST
	profile.permanent_max_health_bonus += HEALTH_UPGRADE_AMOUNT
	return true

func reset_profile_for_tests() -> void:
	profile = PlayerProfile.new()
	selected_location_id = &"test_location"
	current_run_seed = 0
	last_expedition_result = null
	current_mode = Mode.MENU
