class_name SwordGalleryPreview
extends Node2D

var definition: WeaponDefinition
var tier := 1

func setup(weapon_definition: WeaponDefinition, sword_tier := 1) -> void:
	definition = weapon_definition
	tier = sword_tier
	queue_redraw()

func _draw() -> void:
	if definition == null:
		return
	var profile := PlayerSwordVisual.sword_profile(PlayerSwordVisual.resolved_style(definition))
	var length := 62.0 * float(profile["length_scale"]) + tier * 2.0
	var width := float(profile["width"]) * 0.72
	draw_line(Vector2(-18, 0), Vector2(1, 0), profile["grip"], 6.0)
	draw_line(Vector2(0, -10 - width), Vector2(0, 10 + width), profile["guard_color"], 5.0)
	var blade := PackedVector2Array([Vector2(4, -width), Vector2(length - 10, -width), Vector2(length, 0), Vector2(length - 10, width), Vector2(4, width)])
	draw_colored_polygon(blade, profile["blade"])
	draw_polyline(blade, profile["edge"], 1.5)
