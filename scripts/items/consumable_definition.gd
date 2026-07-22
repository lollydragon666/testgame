class_name ConsumableDefinition
extends ItemDefinition

@export var effect_type: ItemEnums.ConsumableEffectType = ItemEnums.ConsumableEffectType.HEAL
@export var effect_value := 0.0
@export var duration := 0.0
@export var cooldown := 1.0

func accepts_slot(slot: ItemEnums.EquipmentSlot) -> bool:
	return slot == ItemEnums.EquipmentSlot.CONSUMABLE_2 or slot == ItemEnums.EquipmentSlot.CONSUMABLE_3
