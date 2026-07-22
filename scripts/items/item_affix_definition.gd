class_name ItemAffixDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export var allowed_item_types: Array[ItemEnums.ItemType] = []
@export var stat: ItemEnums.StatType = ItemEnums.StatType.DAMAGE
@export var min_value := 0.0
@export var max_value := 0.0
@export var weight := 1.0
@export var is_percentage := false

func supports(item_type: ItemEnums.ItemType) -> bool:
	return allowed_item_types.has(item_type)

func roll(rng: RandomNumberGenerator) -> ItemAffixRoll:
	if rng == null:
		return null
	var result := ItemAffixRoll.new()
	result.affix_id = id
	result.stat = stat
	result.value = rng.randf_range(minf(min_value, max_value), maxf(min_value, max_value))
	result.is_percentage = is_percentage
	return result
