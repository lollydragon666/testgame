class_name PlayerProfile
extends Resource

@export var gold := 0:
	set(value):
		gold = maxi(0, value)
@export var permanent_max_health_bonus := 0.0
@export var permanent_damage_bonus := 0.0
@export var completed_expeditions := 0
@export var unlocked_location_ids: Array[StringName] = [&"test_location"]
@export var location_progress: Array[LocationProgress] = []

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

# TODO(save): добавить версию формата, путь user://, атомарную запись и
# восстановление после повреждения файла. Debug-состояние sandbox сюда не входит.
