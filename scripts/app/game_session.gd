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
const SAVE_PATH := "user://player_profile.json"

var profile := PlayerProfile.new()
var inventory := InventoryService.new()
var selected_location_id: StringName = &"test_location"
var selected_location_tier := 1
var current_run_seed := 0
var last_expedition_result: ExpeditionResult
var current_mode := Mode.MENU

func _ready() -> void:
	load_profile()
	_configure_inventory()

func _configure_inventory() -> void:
	inventory = InventoryService.new()
	inventory.configure(GAME_CONTENT)
	inventory.load_serialized(profile.inventory_items, profile.equipped_items, profile.selected_weapon_definition_id)
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.equipment_changed.connect(_on_inventory_changed)
	_sync_inventory_profile()

func _on_inventory_changed() -> void:
	_sync_inventory_profile()
	save_profile()

func _sync_inventory_profile() -> void:
	profile.inventory_items = inventory.serialized_items()
	profile.equipped_items = inventory.serialized_equipment()
	var weapon := inventory.equipped_item(ItemEnums.EquipmentSlot.WEAPON)
	profile.selected_weapon_definition_id = weapon.definition_id if weapon != null else &""
	profile.save_version = PlayerProfile.SAVE_VERSION

func save_profile(path := SAVE_PATH) -> bool:
	_sync_inventory_profile()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open profile save for writing: %s" % path)
		return false
	file.store_string(JSON.stringify(profile.to_dict()))
	return true

func load_profile(path := SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		profile = PlayerProfile.new()
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Profile save is corrupted: %s" % path)
		profile = PlayerProfile.new()
		return false
	profile = PlayerProfile.new()
	profile.load_dict(parsed)
	return true

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
	if current_run_seed == 0:
		current_run_seed = _new_run_seed()
	return true

func selected_location() -> LocationDefinition:
	return GAME_CONTENT.location(selected_location_id)

func selected_tier() -> ExpeditionTierDefinition:
	var location := selected_location()
	return location.tier_definition(selected_location_tier) if location != null else null

func clear_expedition_selection() -> void:
	selected_location_id = &""
	selected_location_tier = 0
	current_run_seed = 0

func set_next_run_seed(seed_value: int) -> void:
	current_run_seed = seed_value

func _new_run_seed() -> int:
	var seed_value := randi()
	return seed_value if seed_value != 0 else 1

func claim_expedition_result(result: ExpeditionResult) -> bool:
	if result == null or result.reward_claimed:
		return false
	result.reward_claimed = true
	profile.grant_gold(maxi(0, result.earned_gold))
	if result.victory:
		profile.completed_expeditions += 1
	last_expedition_result = result
	save_profile()
	return true

func purchase_health_upgrade() -> bool:
	if profile.gold < HEALTH_UPGRADE_COST:
		return false
	profile.gold -= HEALTH_UPGRADE_COST
	profile.permanent_max_health_bonus += HEALTH_UPGRADE_AMOUNT
	save_profile()
	return true

func reset_profile_for_tests() -> void:
	profile = PlayerProfile.new()
	_configure_inventory()
	selected_location_id = &"test_location"
	selected_location_tier = 1
	current_run_seed = 0
	last_expedition_result = null
	current_mode = Mode.MENU
