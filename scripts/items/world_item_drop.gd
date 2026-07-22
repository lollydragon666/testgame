class_name WorldItemDrop
extends Node2D

signal picked_up(item: ItemInstance)
signal pickup_failed(message: String)

const PICKUP_PROTECTION_TIME := 0.30
const PICKUP_RADIUS := 24.0

var item: ItemInstance
var definition: ItemDefinition
var player: PlayerHero
var permanent_inventory: InventoryService
var run_inventory: RunInventoryService
var run_context: RunContext
var world_position := Vector2.ZERO
var protection_remaining := PICKUP_PROTECTION_TIME
var _time := 0.0
var _name_label: Label

func setup(
	item_instance: ItemInstance,
	item_definition: ItemDefinition,
	player_hero: PlayerHero,
	inventory_service: Variant,
	spawn_position: Vector2,
	context: RunContext = null
) -> void:
	item = item_instance
	definition = item_definition
	player = player_hero
	if inventory_service is RunInventoryService:
		run_inventory = inventory_service as RunInventoryService
		run_context = context
	elif inventory_service is InventoryService:
		# Compatibility path for isolated legacy tests; gameplay uses run_inventory.
		permanent_inventory = inventory_service as InventoryService
	world_position = spawn_position
	position = IsoMath.world_to_screen(world_position)

func _ready() -> void:
	add_to_group(&"world_item_drop")
	_name_label = Label.new()
	_name_label.text = "%s\n[ДОБЫЧА ЗАБЕГА]" % (definition.display_name if definition != null else "Предмет") if run_inventory != null else (definition.display_name if definition != null else "Предмет")
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-100.0, -49.0)
	_name_label.size = Vector2(200.0, 24.0)
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", _rarity_color())
	add_child(_name_label)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_time += delta
	protection_remaining = maxf(0.0, protection_remaining - delta)
	queue_redraw()
	if protection_remaining > 0.0 or player == null or not player.is_alive:
		return
	if world_position.distance_to(player.world_position) > PICKUP_RADIUS + player.collision_radius:
		return
	try_pick_up()

func try_pick_up() -> bool:
	if item == null:
		return false
	if run_inventory != null:
		if run_context == null or not run_context.is_active() or not run_inventory.add_item(item):
			pickup_failed.emit("Временный инвентарь заполнен")
			return false
	elif permanent_inventory == null or not permanent_inventory.add_item(item):
		pickup_failed.emit("Инвентарь заполнен")
		return false
	picked_up.emit(item)
	queue_free()
	return true

func _draw() -> void:
	var bob := sin(_time * 3.2) * 3.0
	var color := _rarity_color()
	draw_circle(Vector2(0.0, bob), 18.0, Color(color, 0.12))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -12.0 + bob),
		Vector2(12.0, bob),
		Vector2(0.0, 12.0 + bob),
		Vector2(-12.0, bob),
	]), color)
	draw_arc(Vector2(0.0, bob), 15.0, 0.0, TAU, 24, Color("e8d7b2"), 2.0)

func _rarity_color() -> Color:
	if item == null:
		return Color("c3b79e")
	return [
		Color("c3b79e"),
		Color("73b86b"),
		Color("5f86c9"),
		Color("9e62c7"),
		Color("d49a3a"),
	][clampi(item.rarity, ItemEnums.ItemRarity.COMMON, ItemEnums.ItemRarity.LEGENDARY)]
