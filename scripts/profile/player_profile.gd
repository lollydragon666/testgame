class_name PlayerProfile
extends Resource

const SAVE_VERSION := 3

@export var gold := 0:
	set(value):
		gold = maxi(0, value)
@export var permanent_max_health_bonus := 0.0
@export var permanent_damage_bonus := 0.0
@export var completed_expeditions := 0
@export var unlocked_location_ids: Array[StringName] = [&"test_location"]
@export var location_progress: Array[LocationProgress] = []
@export var save_version := SAVE_VERSION
@export var inventory_items: Array[Dictionary] = []
@export var equipped_items: Dictionary = {}
@export var selected_weapon_definition_id: StringName = &""
@export var pending_run_rewards: Array[Dictionary] = []

func _init() -> void:
	ensure_location_progress(&"test_location")

func is_location_unlocked(location_id: StringName) -> bool:
	return unlocked_location_ids.has(location_id)

func unlock_location(location_id: StringName) -> bool:
	if location_id.is_empty() or is_location_unlocked(location_id):
		return false
	unlocked_location_ids.append(location_id)
	ensure_location_progress(location_id)
	return true

func get_location_progress(location_id: StringName) -> LocationProgress:
	for progress in location_progress:
		if progress != null and progress.location_id == location_id:
			return progress
	return null

func ensure_location_progress(location_id: StringName) -> LocationProgress:
	if location_id.is_empty():
		return null
	var existing := get_location_progress(location_id)
	if existing != null:
		return existing
	var progress := LocationProgress.new()
	progress.location_id = location_id
	location_progress.append(progress)
	return progress

func register_location_victory(location: LocationDefinition, tier: int) -> bool:
	if location == null or not is_location_unlocked(location.id):
		return false
	var progress := ensure_location_progress(location.id)
	return progress != null and progress.register_victory(tier, location.maximum_tier())

func calculate_tier_reward(location: LocationDefinition, tier: int) -> int:
	if location == null or not is_location_unlocked(location.id):
		return 0
	var definition := location.tier_definition(tier)
	var progress := get_location_progress(location.id)
	if definition == null or progress == null or not progress.is_tier_unlocked(tier):
		return 0
	if progress.completion_count(tier) == 0:
		return definition.reward_gold
	return floori(definition.reward_gold * definition.repeat_reward_multiplier)

func grant_gold(amount: int) -> bool:
	if amount < 0:
		return false
	gold += amount
	return true

func to_dict() -> Dictionary:
	var progress_data: Array[Dictionary] = []
	for progress in location_progress:
		if progress != null:
			progress_data.append({
				"location_id": String(progress.location_id),
				"highest_unlocked_tier": progress.highest_unlocked_tier,
				"highest_completed_tier": progress.highest_completed_tier,
				"boss_defeated": progress.boss_defeated,
				"completion_counts": progress.completion_counts.duplicate(true),
			})
	return {
		"save_version": save_version,
		"gold": gold,
		"permanent_max_health_bonus": permanent_max_health_bonus,
		"permanent_damage_bonus": permanent_damage_bonus,
		"completed_expeditions": completed_expeditions,
		"unlocked_location_ids": Array(unlocked_location_ids).map(func(id: StringName) -> String: return String(id)),
		"location_progress": progress_data,
		"inventory_items": inventory_items.duplicate(true),
		"equipped_items": equipped_items.duplicate(true),
		"selected_weapon_definition_id": String(selected_weapon_definition_id),
		"pending_run_rewards": pending_run_rewards.duplicate(true),
	}

func load_dict(data: Dictionary) -> void:
	save_version = maxi(1, int(data.get("save_version", 1)))
	gold = int(data.get("gold", 0))
	permanent_max_health_bonus = maxf(0.0, float(data.get("permanent_max_health_bonus", 0.0)))
	permanent_damage_bonus = maxf(0.0, float(data.get("permanent_damage_bonus", 0.0)))
	completed_expeditions = maxi(0, int(data.get("completed_expeditions", 0)))
	unlocked_location_ids.clear()
	for location_id in data.get("unlocked_location_ids", ["test_location"]):
		unlocked_location_ids.append(StringName(String(location_id)))
	if unlocked_location_ids.is_empty():
		unlocked_location_ids.append(&"test_location")
	location_progress.clear()
	for progress_data in data.get("location_progress", []):
		if not progress_data is Dictionary:
			continue
		var progress := LocationProgress.new()
		progress.location_id = StringName(String(progress_data.get("location_id", "")))
		if progress.location_id.is_empty():
			continue
		progress.highest_unlocked_tier = clampi(int(progress_data.get("highest_unlocked_tier", 1)), 1, 10)
		progress.highest_completed_tier = clampi(int(progress_data.get("highest_completed_tier", 0)), 0, 10)
		progress.boss_defeated = bool(progress_data.get("boss_defeated", false))
		for tier_key in Dictionary(progress_data.get("completion_counts", {})):
			progress.completion_counts[int(tier_key)] = maxi(0, int(progress_data["completion_counts"][tier_key]))
		location_progress.append(progress)
	ensure_location_progress(&"test_location")
	inventory_items = []
	for item_data in data.get("inventory_items", []):
		if item_data is Dictionary:
			inventory_items.append(item_data.duplicate(true))
	var saved_equipment: Variant = data.get("equipped_items", {})
	equipped_items = saved_equipment.duplicate(true) if saved_equipment is Dictionary else {}
	selected_weapon_definition_id = StringName(String(data.get("selected_weapon_definition_id", data.get("selected_weapon_id", ""))))
	pending_run_rewards = []
	for item_data in data.get("pending_run_rewards", []):
		if item_data is Dictionary:
			pending_run_rewards.append(item_data.duplicate(true))

# TODO(save): добавить версию формата, путь user://, атомарную запись и
# восстановление после повреждения файла. Debug-состояние sandbox сюда не входит.
