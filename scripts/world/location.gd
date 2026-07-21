class_name GameLocation
extends Node2D

signal potion_requested(world_position: Vector2)

## Размер одной ромбовидной плитки пола в мировых координатах.
@export var tile_size := 180.0

var world_config: WorldConfig
## Постоянный WorldRoot: пропсы должны быть соседями героя и врагов для общей Y-сортировки.
var props_parent: Node2D
## Список нужен для регенерации карты и заполнения реестра разрушаемых объектов.
var generated_props: Array[WorldProp] = []
var random := RandomNumberGenerator.new()

var world_limit: float:
	get:
		return world_config.world_limit if world_config != null else 0.0

func configure(config: WorldConfig, parent: Node2D) -> void:
	world_config = config
	props_parent = parent

func _ready() -> void:
	if world_config == null:
		push_error("GameLocation requires WorldConfig before entering the tree")
		return
	if props_parent == null:
		props_parent = Node2D.new()
		props_parent.name = "Props"
		props_parent.y_sort_enabled = true
		add_child(props_parent)
	regenerate()
	queue_redraw()

func regenerate(seed_value: int = 0) -> void:
	if props_parent == null:
		return
	for prop in generated_props:
		if not is_instance_valid(prop):
			continue
		prop.set_process(false)
		if prop.get_parent() != null:
			prop.get_parent().remove_child(prop)
		prop.queue_free()
	generated_props.clear()
	# Нулевой seed создаёт новую карту, ненулевой позволяет воспроизвести раскладку.
	if seed_value == 0:
		random.randomize()
	else:
		random.seed = seed_value
	_generate_kind(GameIds.PROP_BUSH, 120)
	_generate_kind(GameIds.PROP_BARREL, 64)
	_generate_kind(GameIds.PROP_TREE, 46)

func _generate_kind(kind: StringName, count: int) -> void:
	# Ограничение попыток защищает от бесконечного цикла при слишком плотной генерации.
	var positions: Array[Vector2] = []
	for prop in generated_props:
		if is_instance_valid(prop):
			positions.append(prop.world_position)
	var requested_count := count
	var max_attempts := requested_count * 45 + 200
	var attempts := 0
	while count > 0 and attempts < max_attempts:
		attempts += 1
		var candidate := Vector2(
			random.randf_range(-world_limit + world_config.prop_edge_margin, world_limit - world_config.prop_edge_margin),
			random.randf_range(-world_limit + world_config.prop_edge_margin, world_limit - world_config.prop_edge_margin)
		)
		if candidate.length() < world_config.prop_player_clear_radius:
			continue
		var blocked := false
		for used in positions:
			if used.distance_to(candidate) < world_config.prop_minimum_spacing:
				blocked = true
				break
		if blocked:
			continue
		var prop := WorldProp.new()
		prop.setup(kind, candidate, random.randf_range(0.0, TAU))
		prop.potion_requested.connect(_relay_potion)
		props_parent.add_child(prop)
		generated_props.append(prop)
		positions.append(candidate)
		count -= 1

func _relay_potion(spawn_position: Vector2) -> void:
	potion_requested.emit(spawn_position)

func _draw() -> void:
	# Пол рисуется одним Node2D; отдельные объекты находятся в Y-sort слое поверх него.
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
