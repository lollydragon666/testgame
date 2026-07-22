class_name ItemAffixDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export var allowed_item_types: Array[ItemEnums.ItemType] = []
@export var allowed_slots: Array[ItemEnums.EquipmentSlot] = []
@export var stat_type: ItemEnums.ItemStatType = ItemEnums.ItemStatType.DAMAGE_FLAT
@export_range(1, 999, 1) var minimum_item_level := 1
@export var base_min := 0.0
@export var base_max := 0.0
@export var value_per_item_level := 0.0
@export var weight := 1.0
@export var percentage := false
@export_range(0, 4, 1) var decimals := 0
@export var exclusive_group: StringName

func supports(definition: ItemDefinition, item_level := 1) -> bool:
	if definition == null or item_level < minimum_item_level:
		return false
	if not allowed_item_types.has(definition.item_type):
		return false
	return allowed_slots.is_empty() or allowed_slots.has(definition.equipment_slot)

func value_range(item_level: int) -> Vector2:
	var level_bonus := float(maxi(0, item_level - 1)) * value_per_item_level
	return Vector2(minf(base_min, base_max) + level_bonus, maxf(base_min, base_max) + level_bonus)

func roll(rng: RandomNumberGenerator, item_level := 1) -> ItemAffixRoll:
	if rng == null:
		return null
	var limits := value_range(item_level)
	var result := ItemAffixRoll.new()
	result.affix_id = id
	result.stat = stat_type
	result.value = snappedf(rng.randf_range(limits.x, limits.y), pow(10.0, -decimals))
	result.is_percentage = percentage
	return result
