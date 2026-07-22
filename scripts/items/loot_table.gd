class_name LootTable
extends Resource

@export var id: StringName
@export var base_drop_chance := 0.08
@export var entries: Array[LootTableEntry] = []

func roll_entry(wave: int, rng: RandomNumberGenerator) -> LootTableEntry:
	if rng == null:
		return null
	var available: Array[LootTableEntry] = []
	var total_weight := 0.0
	for entry in entries:
		if entry != null and entry.weight > 0.0 and entry.is_available(wave):
			available.append(entry)
			total_weight += entry.weight
	if available.is_empty() or total_weight <= 0.0:
		return null
	var roll := rng.randf() * total_weight
	for entry in available:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return available.back()

