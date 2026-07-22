extends Node

enum Mode {
	MENU,
	HUB,
	EXPEDITION,
	COMBAT_SANDBOX,
}

const HEALTH_UPGRADE_COST := 50
const HEALTH_UPGRADE_AMOUNT := 10.0
const GAME_CONTENT: GameContent = preload("res://resources/game_content.tres")

var profile := PlayerProfile.new()
var selected_location_id: StringName = &"test_location"
var selected_location_tier := 1
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
	var requested_tier := selected_location_tier if selected_location_id == location_id else 1
	if not select_expedition(location_id, requested_tier):
		return false
	current_run_seed = randi()
	last_expedition_result = null
	current_mode = Mode.EXPEDITION
	return true

func select_expedition(location_id: StringName, tier: int) -> bool:
	var location := GAME_CONTENT.location(location_id)
	if location == null or not profile.is_location_unlocked(location_id):
		return false
	var progress := profile.get_location_progress(location_id)
	if progress == null or location.tier_definition(tier) == null:
		return false
	if not progress.is_tier_unlocked(tier):
		return false
	selected_location_id = location_id
	selected_location_tier = tier
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
	selected_location_tier = 1
	current_run_seed = 0
	last_expedition_result = null
	current_mode = Mode.MENU
