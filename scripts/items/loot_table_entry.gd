class_name LootTableEntry
extends Resource

@export var definition_id: StringName
@export var item_type: ItemEnums.ItemType = ItemEnums.ItemType.CONSUMABLE
@export var weight := 1.0
@export var min_quantity := 1
@export var max_quantity := 1
@export var minimum_wave := 1
@export var maximum_wave := 0

func is_available(wave: int) -> bool:
	return wave >= minimum_wave and (maximum_wave <= 0 or wave <= maximum_wave)

