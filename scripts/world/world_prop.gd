class_name WorldProp
extends Node2D

signal potion_requested(world_position: Vector2)

const PART_SHADOW := &"shadow"
const PART_BACK := &"back"
const PART_MAIN := &"main"
const PART_FRONT := &"front"

var prop_kind: StringName = GameIds.PROP_BUSH
var definition: PropDefinition
var world_position := Vector2.ZERO
var visual_radius := 28.0
var collision_radius := 28.0
var destructible := true
var blocks_navigation := true
var variant := 0.0
var ground_shadow: WorldPropVisualPart
var back_visual: WorldPropVisualPart
var main_visual: WorldPropVisualPart
var front_visual: WorldPropVisualPart
var collision_shape: CollisionShape2D

func setup(prop_definition: PropDefinition, spawn_position: Vector2, visual_variant: float = 0.0) -> void:
	definition = prop_definition
	prop_kind = definition.id
	world_position = spawn_position
	variant = visual_variant
	visual_radius = definition.visual_radius
	collision_radius = definition.collision_radius
	destructible = definition.destructible
	blocks_navigation = definition.blocks_navigation

func _ready() -> void:
	_build_visual_tree()
	if destructible:
		add_to_group("destructible")
	position = IsoMath.world_to_screen(world_position)
	refresh_visual()

func _build_visual_tree() -> void:
	if ground_shadow != null:
		return
	ground_shadow = _make_part("GroundShadow", PART_SHADOW, -2)
	back_visual = _make_part("BackVisual", PART_BACK, -1)
	main_visual = _make_part("MainVisual", PART_MAIN, 0)
	front_visual = _make_part("FrontVisual", PART_FRONT, 1)
	var body := StaticBody2D.new()
	body.name = "CollisionBody"
	body.collision_layer = 0
	body.collision_mask = 0
	add_child(body)
	collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = collision_radius
	collision_shape.shape = shape
	collision_shape.disabled = definition == null or not definition.has_collision
	body.add_child(collision_shape)

func _make_part(node_name: String, id: StringName, z_value: int) -> WorldPropVisualPart:
	var part := WorldPropVisualPart.new()
	part.name = node_name
	part.z_index = z_value
	part.setup(self, id)
	add_child(part)
	return part

func refresh_visual() -> void:
	for part in [ground_shadow, back_visual, main_visual, front_visual]:
		if part != null:
			part.queue_redraw()

func hit_by_sword() -> void:
	if not destructible:
		return
	if randf() < definition.potion_chance:
		potion_requested.emit(world_position)
	queue_free()

func draw_part(part_id: StringName, canvas: Node2D) -> void:
	if definition == null:
		return
	match part_id:
		PART_SHADOW:
			_draw_shadow(canvas)
		PART_BACK:
			_draw_back(canvas)
		PART_MAIN:
			_draw_main(canvas)
		PART_FRONT:
			_draw_front(canvas)

func _draw_shadow(canvas: Node2D) -> void:
	if definition.is_decal:
		return
	canvas.draw_set_transform(Vector2(4.0, 10.0), 0.0, Vector2(1.35, 0.42) * definition.shadow_scale)
	canvas.draw_circle(Vector2.ZERO, visual_radius, Color(0.01, 0.008, 0.008, 0.30))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_back(canvas: Node2D) -> void:
	match definition.resolved_style():
		&"tree":
			canvas.draw_circle(Vector2(-16.0, -70.0), 31.0, definition.secondary_color)
			canvas.draw_circle(Vector2(18.0, -74.0), 35.0, definition.base_color.darkened(0.15))
		&"column", &"ruined_column":
			canvas.draw_rect(Rect2(-13.0, -definition.visual_height, 26.0, definition.visual_height), definition.secondary_color)

func _draw_main(canvas: Node2D) -> void:
	match definition.resolved_style():
		&"tree":
			canvas.draw_rect(Rect2(-8.0, -62.0, 16.0, 68.0), definition.secondary_color.darkened(0.32))
			canvas.draw_circle(Vector2(0.0, -94.0), 30.0, definition.base_color)
		&"barrel":
			canvas.draw_rect(Rect2(-19.0, -29.0, 38.0, 52.0), definition.base_color)
			canvas.draw_arc(Vector2(0.0, -20.0), 19.0, 0.0, TAU, 24, definition.accent_color, 4.0)
			canvas.draw_line(Vector2(-19.0, 4.0), Vector2(19.0, 4.0), definition.secondary_color, 5.0)
		&"bush":
			for index in 7:
				var angle := TAU * float(index) / 7.0 + variant
				var offset := Vector2.from_angle(angle) * (10.0 + float(index % 2) * 7.0)
				canvas.draw_circle(offset - Vector2(0.0, 8.0), 15.0 + float(index % 3) * 2.0, definition.base_color)
		&"rock":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-25, 0), Vector2(-18, -21), Vector2(3, -31), Vector2(26, -13), Vector2(22, 3)]), definition.base_color)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-18, -21), Vector2(3, -31), Vector2(11, -13), Vector2(-8, -9)]), definition.accent_color)
		&"rock_group":
			for index in 4:
				var offset := Vector2.from_angle(variant + float(index) * 1.7) * (12.0 + index * 3.0)
				canvas.draw_circle(offset - Vector2(0, 8 + index * 2), 10.0 + index * 2.0, definition.base_color.lightened(index * 0.035))
		&"dry_bush":
			for index in 8:
				var direction := Vector2.from_angle(-PI * 0.85 + float(index) * PI * 0.24)
				canvas.draw_line(Vector2(0, 2), direction * (26.0 + index % 3 * 6.0) - Vector2(0, 8), definition.base_color, 3.0)
		&"dead_tree":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-11, 3), Vector2(-8, -83), Vector2(2, -108), Vector2(9, -79), Vector2(12, 3)]), definition.base_color)
			canvas.draw_line(Vector2(-3, -70), Vector2(-34, -99), definition.base_color, 8.0)
			canvas.draw_line(Vector2(4, -58), Vector2(38, -84), definition.base_color, 7.0)
		&"crate", &"broken_crate":
			canvas.draw_rect(Rect2(-25, -42, 50, 43), definition.base_color)
			canvas.draw_rect(Rect2(-21, -38, 42, 35), definition.secondary_color, false, 5.0)
			canvas.draw_line(Vector2(-19, -35), Vector2(19, -6), definition.accent_color, 5.0)
			if definition.resolved_style() == &"broken_crate":
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(5, -42), Vector2(25, -42), Vector2(25, -15), Vector2(14, -24)]), Color(0.08, 0.05, 0.03, 1))
		&"column", &"ruined_column":
			var column_height := definition.visual_height
			canvas.draw_rect(Rect2(-15, -column_height, 30, column_height), definition.base_color)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-20, -column_height), Vector2(15, -column_height), Vector2(21, -column_height + 8), Vector2(-15, -column_height + 8)]), definition.accent_color)
			canvas.draw_rect(Rect2(-21, -10, 42, 12), definition.secondary_color)
		&"low_wall":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-48, -27), Vector2(34, -27), Vector2(48, -16), Vector2(-34, -16)]), definition.accent_color)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-34, -16), Vector2(48, -16), Vector2(48, 2), Vector2(-34, 2)]), definition.base_color)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-48, -27), Vector2(-34, -16), Vector2(-34, 2), Vector2(-48, -8)]), definition.secondary_color)
		&"wall_rubble":
			for index in 6:
				var x := -35.0 + index * 14.0
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 4, -12 - index % 2 * 7), Vector2(x + 15, -8), Vector2(x + 16, 1)]), definition.base_color.lightened(index * 0.02))
		&"bones":
			canvas.draw_line(Vector2(-24, -3), Vector2(20, -16), definition.base_color, 5.0)
			canvas.draw_line(Vector2(-18, -18), Vector2(23, -1), definition.base_color, 5.0)
			canvas.draw_circle(Vector2(-24, -3), 4.0, definition.accent_color)
			canvas.draw_circle(Vector2(23, -1), 4.0, definition.accent_color)
		&"campfire":
			canvas.draw_line(Vector2(-18, 0), Vector2(18, -9), definition.secondary_color, 8.0)
			canvas.draw_line(Vector2(-18, -9), Vector2(18, 0), definition.secondary_color, 8.0)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12, -7), Vector2(-4, -35), Vector2(3, -20), Vector2(10, -43), Vector2(15, -7)]), definition.base_color)
		&"torch":
			canvas.draw_line(Vector2(0, 0), Vector2(0, -58), definition.secondary_color, 7.0)
			canvas.draw_circle(Vector2(0, -66), 11.0, definition.base_color)
			canvas.draw_circle(Vector2(2, -69), 5.0, definition.accent_color)
		&"sacks":
			canvas.draw_circle(Vector2(-12, -12), 17.0, definition.base_color)
			canvas.draw_circle(Vector2(13, -10), 15.0, definition.base_color.darkened(0.08))
			canvas.draw_line(Vector2(-20, -25), Vector2(-5, -25), definition.secondary_color, 4.0)
		&"cart":
			canvas.draw_rect(Rect2(-37, -31, 62, 30), definition.base_color)
			canvas.draw_line(Vector2(25, -7), Vector2(67, 8), definition.secondary_color, 7.0)
			canvas.draw_circle(Vector2(-24, 2), 15.0, definition.secondary_color)
			canvas.draw_circle(Vector2(16, 2), 15.0, definition.secondary_color)
		&"altar":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-34, 0), Vector2(-28, -28), Vector2(28, -28), Vector2(34, 0)]), definition.base_color)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-35, -28), Vector2(25, -38), Vector2(38, -28), Vector2(-28, -18)]), definition.accent_color)
		&"flag":
			canvas.draw_line(Vector2(-5, 0), Vector2(-5, -93), definition.secondary_color, 6.0)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-3, -90), Vector2(37, -80), Vector2(22, -60), Vector2(-3, -68)]), definition.base_color)
		&"decal_cracks":
			for index in 5:
				canvas.draw_line(Vector2.ZERO, Vector2.from_angle(variant + index * 1.28) * (18 + index * 4), definition.base_color, 2.0)
		&"decal_mud", &"decal_blood", &"decal_scorch":
			canvas.draw_set_transform(Vector2.ZERO, variant, Vector2(1.4, 0.55))
			canvas.draw_circle(Vector2.ZERO, visual_radius, definition.base_color)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"decal_grass":
			for index in 8:
				var x := -22.0 + index * 6.0
				canvas.draw_line(Vector2(x, 4), Vector2(x + sin(variant + index) * 5.0, -12 - index % 3 * 4), definition.base_color, 2.0)
		&"decal_small_stones":
			for index in 7:
				canvas.draw_circle(Vector2.from_angle(variant + index) * (8 + index * 3), 2.5 + index % 2, definition.base_color)
		&"decal_impact":
			canvas.draw_arc(Vector2.ZERO, visual_radius, 0.0, TAU, 20, definition.base_color, 3.0)
			for index in 6:
				canvas.draw_line(Vector2.from_angle(index) * 5.0, Vector2.from_angle(index) * visual_radius, definition.base_color, 2.0)
		&"decal_bone":
			canvas.draw_line(Vector2(-13, -3), Vector2(13, 3), definition.base_color, 4.0)
		&"decal_pattern":
			canvas.draw_arc(Vector2.ZERO, visual_radius, 0.0, TAU, 24, definition.base_color, 2.0)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -15), Vector2(13, 8), Vector2(-13, 8)]), Color(definition.base_color, 0.35))
		_:
			canvas.draw_circle(Vector2(0.0, -visual_radius * 0.45), visual_radius, definition.base_color)

func _draw_front(canvas: Node2D) -> void:
	if not definition.has_front_layer:
		return
	match definition.resolved_style():
		&"tree":
			canvas.draw_circle(Vector2(15.0, -82.0), 24.0, definition.base_color.lightened(0.10))
		&"column", &"ruined_column":
			canvas.draw_line(Vector2(-9.0, -definition.visual_height + 4.0), Vector2(-9.0, -4.0), definition.accent_color, 3.0)
