class_name HubController
extends Node2D

const HUB_MOVE_SPEED := 260.0
const HUB_LIMIT := Vector2(520.0, 280.0)
const GAME_CONTENT: GameContent = preload("res://resources/game_content.tres")

@onready var hub_player: Node2D = $HubPlayer
@onready var portal: HubPortal = $ExpeditionPortal
@onready var hub_ui: CanvasLayer = $HubUI

var gold_label: Label
var portal_hint: Label
var altar_message: Label
var tier_status_label: Label
var inventory_ui: InventoryUI
var shop_ui: ShopUI

func _ready() -> void:
	portal.configure(hub_player)
	portal.expedition_requested.connect(_start_expedition)
	_build_ui()
	_build_item_interfaces()
	_refresh_profile_ui()
	queue_redraw()

func _process(delta: float) -> void:
	if (inventory_ui != null and inventory_ui.is_open()) or (shop_ui != null and shop_ui.is_open()):
		portal_hint.visible = false
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	hub_player.position += input_vector * HUB_MOVE_SPEED * delta
	hub_player.position = hub_player.position.clamp(-HUB_LIMIT, HUB_LIMIT)
	portal_hint.visible = portal.is_player_near()

func _draw() -> void:
	draw_rect(Rect2(-700.0, -400.0, 1400.0, 800.0), Color("100d0a"))
	for ring_radius in [130.0, 230.0, 360.0]:
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color("33251a"), 3.0)
	draw_circle($HealthUpgradeAltar.position, 54.0, Color("2f241d"))
	draw_arc($HealthUpgradeAltar.position, 54.0, 0.0, TAU, 32, Color("a8874d"), 4.0)
	draw_circle($ExpeditionPortal.position, 68.0, Color("171321"))
	draw_arc($ExpeditionPortal.position, 68.0, 0.0, TAU, 40, Color("765c9c"), 7.0)

func _build_ui() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.022, 0.018, 0.94)
	panel.position = Vector2(24.0, 24.0)
	panel.size = Vector2(390.0, 250.0)
	hub_ui.add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(18.0, 16.0)
	box.size = Vector2(354.0, 218.0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ХАБ ОХОТНИКА"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("d0ad64"))
	box.add_child(title)
	gold_label = Label.new()
	box.add_child(gold_label)
	tier_status_label = Label.new()
	tier_status_label.add_theme_color_override("font_color", Color("d0ad64"))
	box.add_child(tier_status_label)
	var altar_button := Button.new()
	altar_button.text = "УКРЕПИТЬ ЗДОРОВЬЕ — 50 ЗОЛОТА"
	altar_button.custom_minimum_size = Vector2(0.0, 48.0)
	altar_button.pressed.connect(_purchase_health)
	box.add_child(altar_button)
	altar_message = Label.new()
	altar_message.add_theme_color_override("font_color", Color("8f7c61"))
	box.add_child(altar_message)

	portal_hint = Label.new()
	portal_hint.text = "E — НАЧАТЬ ВЫЛАЗКУ"
	portal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portal_hint.add_theme_font_size_override("font_size", 24)
	portal_hint.add_theme_color_override("font_color", Color("d0ad64"))
	portal_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	portal_hint.position = Vector2(-190.0, -90.0)
	portal_hint.size = Vector2(380.0, 50.0)
	hub_ui.add_child(portal_hint)

	var menu_button := Button.new()
	menu_button.text = "В ГЛАВНОЕ МЕНЮ"
	menu_button.position = Vector2(24.0, 650.0)
	menu_button.size = Vector2(250.0, 46.0)
	menu_button.pressed.connect(_show_main_menu)
	hub_ui.add_child(menu_button)

	var item_menu := VBoxContainer.new()
	item_menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	item_menu.position = Vector2(-300.0, 24.0)
	item_menu.size = Vector2(276.0, 300.0)
	item_menu.add_theme_constant_override("separation", 8)
	hub_ui.add_child(item_menu)
	for button_data in [
		["ИНВЕНТАРЬ  [I]", &"inventory"],
		["КУЗНЕЦ", &"blacksmith"],
		["ЛАВКА БИЖУТЕРИИ", &"jewelry"],
		["АЛХИМИК", &"alchemist"],
	]:
		var item_button := Button.new()
		item_button.text = String(button_data[0])
		item_button.custom_minimum_size = Vector2(276.0, 50.0)
		var target_id := StringName(button_data[1])
		item_button.pressed.connect(_open_item_window.bind(target_id))
		item_menu.add_child(item_button)

func _build_item_interfaces() -> void:
	var session := _session()
	shop_ui = ShopUI.new()
	shop_ui.name = "ShopUI"
	shop_ui.configure(GAME_CONTENT, session.inventory, session.profile, session.shop_service)
	add_child(shop_ui)
	inventory_ui = InventoryUI.new()
	inventory_ui.name = "InventoryUI"
	inventory_ui.configure(
		GAME_CONTENT,
		session.inventory,
		session.profile,
		session.shop_service,
		func() -> bool: return shop_ui == null or not shop_ui.is_open(),
		false
	)
	add_child(inventory_ui)

func _open_item_window(target_id: StringName) -> void:
	if target_id == &"inventory":
		if shop_ui != null:
			shop_ui.close()
		inventory_ui.open()
	else:
		if inventory_ui != null:
			inventory_ui.close()
		shop_ui.open_shop(target_id)

func _purchase_health() -> void:
	if _session().purchase_health_upgrade():
		altar_message.text = "ЗДОРОВЬЕ УКРЕПЛЕНО. БОНУС ПРИМЕНИТСЯ В НОВОЙ ВЫЛАЗКЕ."
	else:
		altar_message.text = "НЕДОСТАТОЧНО ЗОЛОТА."
	_refresh_profile_ui()

func _refresh_profile_ui() -> void:
	var profile: PlayerProfile = _session().profile
	gold_label.text = "ЗОЛОТО: %d   •   БОНУС ЗДОРОВЬЯ: +%d" % [
		profile.gold,
		int(profile.permanent_max_health_bonus),
	]
	var progress := profile.get_location_progress(&"test_location")
	tier_status_label.text = "Следующая доступная ступень: %d" % (progress.highest_unlocked_tier if progress != null else 1)

func _start_expedition(location_id: StringName) -> void:
	var session := _session()
	var progress: LocationProgress = session.profile.get_location_progress(location_id)
	if progress == null:
		push_warning("Location progress is missing: %s" % location_id)
		return
	session.clear_expedition_selection()
	if not session.select_expedition(location_id, progress.highest_unlocked_tier):
		push_warning("Highest location tier is not selectable")
		return
	get_node("/root/SceneRouter").start_expedition(location_id)

func _show_main_menu() -> void:
	get_node("/root/SceneRouter").show_main_menu()

func _session() -> Node:
	return get_node("/root/GameSession")
