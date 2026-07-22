class_name WorldPropVisualPart
extends Node2D

var prop: WorldProp
var part_id: StringName

func setup(owner_prop: WorldProp, id: StringName) -> void:
	prop = owner_prop
	part_id = id

func _draw() -> void:
	if prop != null:
		prop.draw_part(part_id, self)
