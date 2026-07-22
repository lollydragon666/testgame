extends Node

signal run_succeeded(run_id: String)
signal run_rewards_committed(run_id: String, item_count: int)

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
var run_inventory := RunInventoryService.new()
var run_context := RunContext.new()
var pending_run_rewards := PendingRunRewards.new()
var shop_service := ShopService.new()
var selected_location_id: StringName = &"test_location"
var selected_location_tier := 1
var current_run_seed := 0
var last_expedition_result: ExpeditionResult
var current_mode := Mode.MENU
var _auto_save_suspended := false

func _ready() -> void:
	load_profile()
	_configure_inventory()
	run_inventory.configure(GAME_CONTENT)

func _configure_inventory() -> void:
	inventory = InventoryService.new()
	inventory.configure(GAME_CONTENT)
	inventory.load_serialized(profile.inventory_items, profile.equipped_items, profile.selected_weapon_definition_id)
	pending_run_rewards = PendingRunRewards.new()
	pending_run_rewards.configure(GAME_CONTENT, inventory, profile, profile.pending_run_rewards, save_profile)
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.equipment_changed.connect(_on_inventory_changed)
	shop_service = ShopService.new()
	shop_service.configure(GAME_CONTENT, inventory, profile, save_profile)
	_sync_inventory_profile()

func _on_inventory_changed() -> void:
	_sync_inventory_profile()
	if not _auto_save_suspended:
		save_profile()

func _sync_inventory_profile() -> void:
	profile.inventory_items = inventory.serialized_items()
	profile.equipped_items = inventory.serialized_equipment()
	var weapon_id := String(profile.equipped_items.get(String.num_int64(ItemEnums.EquipmentSlot.WEAPON), ""))
	var weapon := inventory.permanent_item(weapon_id)
	profile.selected_weapon_definition_id = weapon.definition_id if weapon != null else &""
	profile.pending_run_rewards = pending_run_rewards.serialized_items()
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

## Полностью заменяет постоянный прогресс новым профилем и сразу записывает его.
## Отдельный путь позволяет безопасно проверять сброс без изменения основного save.
func reset_profile(path := SAVE_PATH) -> bool:
	profile = PlayerProfile.new()
	_configure_inventory()
	run_inventory.configure(GAME_CONTENT)
	run_context = RunContext.new()
	selected_location_id = &"test_location"
	selected_location_tier = 1
	current_run_seed = 0
	last_expedition_result = null
	current_mode = Mode.MENU
	return save_profile(path)

func set_mode(mode: Mode) -> void:
	current_mode = mode

func enter_menu() -> void:
	current_mode = Mode.MENU

func enter_hub() -> void:
	current_mode = Mode.HUB

func enter_combat_sandbox() -> void:
	current_mode = Mode.COMBAT_SANDBOX

func begin_expedition(location_id: StringName) -> bool:
	if run_context.state == RunContext.RunState.ACTIVE or run_context.state == RunContext.RunState.SUCCESS_PENDING:
		return false
	var requested_tier := selected_location_tier if selected_location_id == location_id else 1
	if not select_expedition(location_id, requested_tier):
		return false
	last_expedition_result = null
	if not start_new_run():
		return false
	current_mode = Mode.EXPEDITION
	return true

func start_new_run() -> bool:
	if run_context.state == RunContext.RunState.ACTIVE or run_context.state == RunContext.RunState.SUCCESS_PENDING:
		return false
	run_inventory.clear()
	run_context = RunContext.create(inventory.serialized_equipment())
	inventory.attach_run_inventory(run_inventory, run_context.starting_equipment)
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

func complete_run_successfully() -> bool:
	if run_context.state != RunContext.RunState.ACTIVE or run_context.rewards_committed:
		return false
	var run_items := run_inventory.get_items()
	for item in run_items:
		if item == null or item.instance_id.is_empty() or GAME_CONTENT.item(item.definition_id) == null:
			return false
	var previous_items := inventory.serialized_items()
	var previous_equipment := inventory.serialized_equipment()
	var previous_runtime_equipment := inventory.runtime_equipment_snapshot()
	var previous_pending := pending_run_rewards.serialized_items()
	run_context.state = RunContext.RunState.SUCCESS_PENDING
	var pending_count := 0
	_auto_save_suspended = true
	inventory.begin_transaction()
	for item in run_items:
		if not inventory.add_item_preserving_identity(item):
			if not pending_run_rewards.add_item(item):
				inventory.end_transaction()
				_rollback_reward_transfer(previous_items, previous_equipment, previous_runtime_equipment, previous_pending)
				_auto_save_suspended = false
				run_context.state = RunContext.RunState.ACTIVE
				return false
			pending_count += 1
	inventory.end_transaction()
	var saved := save_profile()
	_auto_save_suspended = false
	if not saved:
		_rollback_reward_transfer(previous_items, previous_equipment, previous_runtime_equipment, previous_pending)
		run_context.state = RunContext.RunState.ACTIVE
		return false
	run_context.rewards_committed = true
	run_context.committed_item_count = run_items.size()
	run_context.pending_item_count = pending_count
	run_context.completed_at_unix = int(Time.get_unix_time_from_system())
	run_context.state = RunContext.RunState.COMPLETED
	run_inventory.clear()
	inventory.detach_run_inventory()
	run_succeeded.emit(run_context.run_id)
	run_rewards_committed.emit(run_context.run_id, run_items.size())
	return true

func _rollback_reward_transfer(
	items: Array[Dictionary],
	equipment: Dictionary,
	runtime_equipment: Dictionary,
	pending: Array[Dictionary]
) -> void:
	inventory.load_serialized(items, equipment, profile.selected_weapon_definition_id)
	pending_run_rewards.configure(GAME_CONTENT, inventory, profile, pending, save_profile)
	inventory.attach_run_inventory(run_inventory, run_context.starting_equipment)
	inventory.restore_runtime_equipment(runtime_equipment)

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
	run_inventory.configure(GAME_CONTENT)
	run_context = RunContext.new()
	selected_location_id = &"test_location"
	selected_location_tier = 1
	current_run_seed = 0
	last_expedition_result = null
	current_mode = Mode.MENU
