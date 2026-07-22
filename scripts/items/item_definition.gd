class_name ItemDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var item_type: ItemEnums.ItemType = ItemEnums.ItemType.WEAPON
@export var equipment_slot: ItemEnums.EquipmentSlot = ItemEnums.EquipmentSlot.NONE
@export var rarity: ItemEnums.ItemRarity = ItemEnums.ItemRarity.COMMON
@export var base_price := 0
@export var sell_price := 0
@export var stackable := false
@export var max_stack := 1
@export var icon: Texture2D
@export var visual_scene: PackedScene
@export var visual_style: StringName = &"default"
@export var sort_order := 0
@export var allow_duplicate_equipment := true
@export var can_sell := true
@export var minimum_wave := 1

func resolved_sell_price(affix_count := 0) -> int:
	var base_value := sell_price
	if base_value <= 0 and base_price > 0:
		base_value = maxi(1, floori(float(base_price) * 0.35))
	return maxi(0, floori(float(base_value) * (1.0 + maxf(0.0, float(affix_count)) * 0.10)))

func accepts_slot(slot: ItemEnums.EquipmentSlot) -> bool:
	if equipment_slot == ItemEnums.EquipmentSlot.RING:
		return slot == ItemEnums.EquipmentSlot.RING_1 or slot == ItemEnums.EquipmentSlot.RING_2
	return equipment_slot == slot
