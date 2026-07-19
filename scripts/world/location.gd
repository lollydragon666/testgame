class_name GameLocation
extends Node2D

signal potion_requested(world_position: Vector2)

@export var world_limit := 3600.0
@export var tile_size := 180.0

var props_root: Node2D
var random := RandomNumberGenerator.new()

func _ready() -> void:
	props_root = Node2D.new()
	props_root.name = "Props"
	add_child(props_root)
	regenerate()
	queue_redraw()

func regenerate(seed_value: int = 0) -> void:
	if props_root == null:
		return
	for child in props_root.get_children():
		props_root.remove_child(child)
		child.queue_free()
	if seed_value == 0:
		random.randomize()
	else:
		random.seed = seed_value
	_generate_kind("bush", 120)
	_generate_kind("barrel", 64)
	_generate_kind("tree", 46)

func _generate_kind(kind: String, count: int) -> void:
	var positions: Array[Vector2] = []
	for child in props_root.get_children():
		positions.append(child.world_position)
	var attempts := 0
	while count > 0 and attempts < count * 45 + 200:
		attempts += 1
		var candidate := Vector2(
			random.randf_range(-world_limit + 170.0, world_limit - 170.0),
			random.randf_range(-world_limit + 170.0, world_limit - 170.0)
		)
		if candidate.length() < 310.0:
			continue
		var blocked := false
		for used in positions:
			if used.distance_to(candidate) < 82.0:
				blocked = true
				break
		if blocked:
			continue
		var prop := WorldProp.new()
		prop.setup(kind, candidate, random.randf_range(0.0, TAU))
		prop.potion_requested.connect(_relay_potion)
		props_root.add_child(prop)
		positions.append(candidate)
		count -= 1

func _relay_potion(spawn_position: Vector2) -> void:
	potion_requested.emit(spawn_position)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ONE * -12000.0, Vector2.ONE * 24000.0), Color("040303"))
	var tile_count := int(world_limit * 2.0 / tile_size)
	for x_index in tile_count:
		for y_index in tile_count:
			var world_x := -world_limit + float(x_index) * tile_size
			var world_y := -world_limit + float(y_index) * tile_size
			var p0 := IsoMath.world_to_screen(Vector2(world_x, world_y))
			var p1 := IsoMath.world_to_screen(Vector2(world_x + tile_size, world_y))
			var p2 := IsoMath.world_to_screen(Vector2(world_x + tile_size, world_y + tile_size))
			var p3 := IsoMath.world_to_screen(Vector2(world_x, world_y + tile_size))
			var color := Color("171310") if (x_index + y_index) % 2 == 0 else Color("211913")
			draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), color)
	var corners := PackedVector2Array([
		IsoMath.world_to_screen(Vector2(-world_limit, -world_limit)),
		IsoMath.world_to_screen(Vector2(world_limit, -world_limit)),
		IsoMath.world_to_screen(Vector2(world_limit, world_limit)),
		IsoMath.world_to_screen(Vector2(-world_limit, world_limit)),
		IsoMath.world_to_screen(Vector2(-world_limit, -world_limit))
	])
	draw_polyline(corners, Color("a8874d"), 9.0)
