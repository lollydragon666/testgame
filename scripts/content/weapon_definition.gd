class_name WeaponDefinition
extends ItemDefinition

@export var weapon_class: StringName = ItemEnums.SWORD_CLASS
@export var max_tier := 6
@export var base_damage := 34.0
@export var damage_per_tier := 2.0
@export var base_attack_reach := 91.0
@export var reach_per_tier := 11.0
@export var attack_half_width := 7.0
## Каждый уровень роста меча расширяет world-space зону замаха на 10–15%.
@export_range(1.10, 1.15, 0.01) var width_multiplier_per_tier := 1.12
@export var base_visual_length := 91.0
@export var visual_length_per_tier := 11.0
@export var cooldown := 0.36
@export var swing_duration := 0.28
@export var final_tier_bonus_reach := 8.0
@export var final_tier_bonus_damage := 2.0

func _init() -> void:
	item_type = ItemEnums.ItemType.WEAPON
	equipment_slot = ItemEnums.EquipmentSlot.WEAPON
	stackable = false
	max_stack = 1
