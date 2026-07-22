class_name EnemySpawnGroupDefinition
extends Resource

@export var id: StringName
@export var minimum_wave := 1
@export var maximum_wave := 0
@export var weight := 1.0
@export var enemy_ids: Array[StringName] = []
@export var minimum_counts: Array[int] = []
@export var maximum_counts: Array[int] = []
@export var formation_radius := 100.0

func build_spawn_list(random: RandomNumberGenerator, wave_number: int) -> Array[StringName]:
	var result: Array[StringName] = []
	if wave_number < minimum_wave or (maximum_wave > 0 and wave_number > maximum_wave):
		return result
	for index in enemy_ids.size():
		var minimum := minimum_counts[index] if index < minimum_counts.size() else 1
		var maximum := maximum_counts[index] if index < maximum_counts.size() else minimum
		for _entry in random.randi_range(minimum, maxi(minimum, maximum)):
			result.append(enemy_ids[index])
	return result
