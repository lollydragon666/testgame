class_name ArmorDefinition
extends ItemDefinition

@export var defense := 0.0
@export var max_health_bonus := 0.0
@export var movement_speed_modifier := 0.0

func _init() -> void:
	item_type = ItemEnums.ItemType.ARMOR
	equipment_slot = ItemEnums.EquipmentSlot.ARMOR
	stackable = false
	max_stack = 1
