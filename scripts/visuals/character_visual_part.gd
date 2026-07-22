class_name CharacterVisualPart
extends Node2D

var part_id: StringName
var visual: CharacterVisual

func setup(owner_visual: CharacterVisual, id: StringName) -> void:
	visual = owner_visual
	part_id = id

func _draw() -> void:
	if visual != null:
		visual.draw_part(part_id)

