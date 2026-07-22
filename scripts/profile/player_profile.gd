class_name PlayerProfile
extends Resource

@export var gold := 0
@export var permanent_max_health_bonus := 0.0
@export var permanent_damage_bonus := 0.0
@export var completed_expeditions := 0
@export var unlocked_location_ids: Array[StringName] = [&"test_location"]

func is_location_unlocked(location_id: StringName) -> bool:
	return unlocked_location_ids.has(location_id)

# TODO(save): добавить версию формата, путь user://, атомарную запись и
# восстановление после повреждения файла. Debug-состояние sandbox сюда не входит.
