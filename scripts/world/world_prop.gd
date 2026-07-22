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
