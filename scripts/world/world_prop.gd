class_name WorldProp
extends Node2D

signal potion_requested(world_position: Vector2)

var prop_kind: StringName = GameIds.PROP_BUSH
var definition: PropDefinition
var world_position := Vector2.ZERO
## Радиус попадания мечом; у дерева используется только как размер объекта.
var visual_radius := 28.0
var collision_radius := 28.0
## Деревья блокируют визуальное пространство, но не входят в боевой реестр меча.
var destructible := true
## Случайный поворот раскладки листьев, чтобы кусты не выглядели одинаково.
var variant := 0.0

func setup(prop_definition: PropDefinition, spawn_position: Vector2, visual_variant: float = 0.0) -> void:
	definition = prop_definition
	prop_kind = definition.id
	world_position = spawn_position
	variant = visual_variant
	visual_radius = definition.visual_radius
	collision_radius = definition.collision_radius
	destructible = definition.destructible

func _ready() -> void:
	if destructible:
		add_to_group("destructible")
	position = IsoMath.world_to_screen(world_position)
	queue_redraw()

func hit_by_sword() -> void:
	if not destructible:
		return
	# Лечение выпадает только из части разрушаемых объектов, а не из врагов.
	if randf() < definition.potion_chance:
		potion_requested.emit(world_position)
	queue_free()

func _draw() -> void:
	match prop_kind:
		GameIds.PROP_TREE:
			draw_set_transform(Vector2(0.0, 15.0), 0.0, Vector2(1.4, 0.45))
			draw_circle(Vector2.ZERO, 35.0, Color(0.01, 0.008, 0.008, 0.34))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_rect(Rect2(-8.0, -62.0, 16.0, 68.0), Color("35271d"))
			draw_circle(Vector2(-15.0, -68.0), 30.0, Color("26351f"))
			draw_circle(Vector2(18.0, -72.0), 34.0, Color("314528"))
			draw_circle(Vector2(0.0, -94.0), 29.0, Color("3d5b31"))
		GameIds.PROP_BARREL:
			draw_rect(Rect2(-19.0, -29.0, 38.0, 52.0), Color("714725"))
			draw_arc(Vector2(0.0, -20.0), 19.0, 0.0, TAU, 24, Color("a8874d"), 4.0)
			draw_line(Vector2(-19.0, 4.0), Vector2(19.0, 4.0), Color("35271d"), 5.0)
		GameIds.PROP_BUSH:
			for index in 7:
				var angle := TAU * float(index) / 7.0 + variant
				var offset := Vector2.from_angle(angle) * (10.0 + float(index % 2) * 7.0)
				draw_circle(offset - Vector2(0.0, 8.0), 15.0 + float(index % 3) * 2.0, Color("3d5b31"))

