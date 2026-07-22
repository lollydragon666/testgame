class_name PropDefinition
extends Resource

@export var id: StringName
@export var style: StringName
@export var spawn_count := 0
@export var visual_radius := 28.0
@export var collision_radius := 28.0
@export var destructible := true
@export var potion_chance := 0.0
@export var size := Vector2(56.0, 56.0)
@export var base_color := Color("3d5b31")
@export var secondary_color := Color("26351f")
@export var accent_color := Color("a8874d")
@export var has_collision := true
@export var blocks_navigation := true
@export var shadow_scale := Vector2.ONE
@export var visual_height := 28.0
@export var has_front_layer := false
@export var is_decal := false

func resolved_style() -> StringName:
	return style if not style.is_empty() else id
