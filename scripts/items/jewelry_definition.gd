class_name JewelryDefinition
extends ItemDefinition

@export var damage_bonus := 0.0
@export var defense_bonus := 0.0
@export var max_health_bonus := 0.0
@export var movement_speed_bonus := 0.0
@export var attack_speed_bonus := 0.0
@export var critical_chance_bonus := 0.0
@export var critical_damage_bonus := 0.0
@export var loot_chance_bonus := 0.0

func _init() -> void:
	item_type = ItemEnums.ItemType.JEWELRY
	stackable = false
	max_stack = 1
