class_name InventoryUI
extends CanvasLayer

const EQUIPMENT_SLOTS: Array[ItemEnums.EquipmentSlot] = [
	ItemEnums.EquipmentSlot.WEAPON,
	ItemEnums.EquipmentSlot.ARMOR,
	ItemEnums.EquipmentSlot.AMULET,
	ItemEnums.EquipmentSlot.RING_1,
	ItemEnums.EquipmentSlot.RING_2,
	ItemEnums.EquipmentSlot.CONSUMABLE_2,
	ItemEnums.EquipmentSlot.CONSUMABLE_3,
]

var game_content: GameContent
var inventory: InventoryService
var profile: PlayerProfile
var shop_service: ShopService
var can_open_callback: Callable
var pause_game_when_open := false
var selected_instance_id := ""
var selected_filter := -1
var _paused_by_window := false

var overlay: ColorRect
var item_grid: GridContainer
var equipment_box: VBoxContainer
var details_label: RichTextLabel
var gold_label: Label
var capacity_label: Label
var action_box: HBoxContainer

func configure(
	content: GameContent,
	inventory_service: InventoryService,
	player_profile: PlayerProfile = null,
	economy_service: ShopService = null,
	open_guard := Callable(),
	pause_game := false
) -> void:
	game_content = content
	inventory = inventory_service
	profile = player_profile
	shop_service = economy_service
	can_open_callback = open_guard
	pause_game_when_open = pause_game

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	overlay.visible = false
	if inventory != null:
		inventory.inventory_changed.connect(_refresh)
		inventory.equipment_changed.connect(_refresh)
		inventory.consumable_slot_changed.connect(func(_slot: ItemEnums.EquipmentSlot): _refresh())
	if shop_service != null:
		shop_service.currency_changed.connect(func(_gold: int): _refresh())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if overlay.visible:
			close()
		elif not can_open_callback.is_valid() or bool(can_open_callback.call()):
			open()
		get_viewport().set_input_as_handled()
	elif overlay.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	if overlay == null or inventory == null:
		return
	overlay.visible = true
	if pause_game_when_open and not get_tree().paused:
		get_tree().paused = true
		_paused_by_window = true
	_refresh()

func close() -> void:
	if overlay == null:
		return
	overlay.visible = false
	if _paused_by_window:
		get_tree().paused = false
		_paused_by_window = false

func is_open() -> bool:
	return overlay != null and overlay.visible

func _build_interface() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.018, 0.012, 0.010, 0.97)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var frame := VBoxContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-580.0, -330.0)
	frame.size = Vector2(1160.0, 660.0)
	frame.add_theme_constant_override("separation", 10)
	overlay.add_child(frame)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	frame.add_child(header)
	var title := Label.new()
	title.text = "ИНВЕНТАРЬ"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("d0ad64"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	gold_label = Label.new()
	gold_label.add_theme_color_override("font_color", Color("d0ad64"))
	header.add_child(gold_label)
	capacity_label = Label.new()
	header.add_child(capacity_label)
	var close_button := _button("ЗАКРЫТЬ  [I]")
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	frame.add_child(filters)
	for filter_data in [
		["ВСЕ", -1],
		["ОРУЖИЕ", ItemEnums.ItemType.WEAPON],
		["БРОНЯ", ItemEnums.ItemType.ARMOR],
		["БИЖУТЕРИЯ", ItemEnums.ItemType.JEWELRY],
		["РАСХОДНИКИ", ItemEnums.ItemType.CONSUMABLE],
	]:
		var filter_button := _button(String(filter_data[0]))
		filter_button.pressed.connect(_set_filter.bind(int(filter_data[1])))
		filters.add_child(filter_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	frame.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500.0, 500.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	item_grid = GridContainer.new()
	item_grid.columns = 4
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 6)
	item_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(item_grid)

	equipment_box = VBoxContainer.new()
	equipment_box.custom_minimum_size = Vector2(245.0, 0.0)
	equipment_box.add_theme_constant_override("separation", 5)
	body.add_child(equipment_box)

	var details_box := VBoxContainer.new()
	details_box.custom_minimum_size = Vector2(360.0, 0.0)
	details_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(details_box)
	details_label = RichTextLabel.new()
	details_label.bbcode_enabled = true
	details_label.fit_content = false
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_label.custom_minimum_size = Vector2(360.0, 430.0)
	details_box.add_child(details_label)
	action_box = HBoxContainer.new()
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_theme_constant_override("separation", 5)
	details_box.add_child(action_box)

func _refresh() -> void:
	if overlay == null or inventory == null:
		return
	if not selected_instance_id.is_empty() and inventory.find_item(selected_instance_id) == null:
		selected_instance_id = ""
	gold_label.text = "ЗОЛОТО: %d" % (profile.gold if profile != null else 0)
	capacity_label.text = "ЯЧЕЙКИ: %d / %d" % [inventory.inventory_size(), InventoryService.CAPACITY]
	_rebuild_item_grid()
	_rebuild_equipment()
	_rebuild_details()

func _rebuild_item_grid() -> void:
	_clear_children(item_grid)
	var items := inventory.get_items()
	items.sort_custom(func(first: ItemInstance, second: ItemInstance) -> bool:
		var first_definition := game_content.item(first.definition_id)
		var second_definition := game_content.item(second.definition_id)
		return first_definition.sort_order < second_definition.sort_order
	)
	for item in items:
		var definition := game_content.item(item.definition_id)
		if definition == null or (selected_filter >= 0 and int(definition.item_type) != selected_filter):
			continue
		var selected_marker := "◆ " if item.instance_id == selected_instance_id else ""
		var quantity_text := " ×%d" % item.quantity if item.quantity > 1 else ""
		var equipped_text := "\n[НАДЕТО]" if inventory.is_equipped(item.instance_id) else ""
		var item_button := _button("%s%s%s%s" % [selected_marker, definition.display_name, quantity_text, equipped_text])
		item_button.custom_minimum_size = Vector2(116.0, 78.0)
		item_button.pressed.connect(_select_item.bind(item.instance_id))
		item_grid.add_child(item_button)

func _rebuild_equipment() -> void:
	_clear_children(equipment_box)
	var heading := Label.new()
	heading.text = "ЭКИПИРОВКА"
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", Color("d0ad64"))
	equipment_box.add_child(heading)
	for slot in EQUIPMENT_SLOTS:
		var item := inventory.equipped_item(slot)
		var definition := inventory.equipped_definition(slot)
		var slot_button := _button("%s\n%s" % [
			_slot_name(slot),
			definition.display_name if definition != null else "— пусто —",
		])
		slot_button.custom_minimum_size = Vector2(235.0, 49.0)
		slot_button.disabled = item == null
		if item != null:
			slot_button.pressed.connect(_select_item.bind(item.instance_id))
		equipment_box.add_child(slot_button)

func _rebuild_details() -> void:
	_clear_children(action_box)
	var item := inventory.find_item(selected_instance_id)
	var definition := game_content.item(item.definition_id) if item != null else null
	if item == null or definition == null:
		details_label.text = "[color=#8f7c61]Выберите предмет, чтобы увидеть его свойства.[/color]"
		return
	var lines: Array[String] = [
		"[font_size=24][color=#d0ad64]%s[/color][/font_size]" % definition.display_name,
		"%s · %s" % [ItemEnums.item_type_name(definition.item_type), ItemEnums.rarity_name(item.rarity)],
		"Количество: %d" % item.quantity,
		"",
		definition.description,
		"",
		_definition_stats(definition),
	]
	if not item.affixes.is_empty():
		lines.append("\n[color=#73b86b]СЛУЧАЙНЫЕ СВОЙСТВА[/color]")
		for affix in item.affixes:
			var affix_definition := game_content.item_affix(affix.affix_id)
			var affix_name := affix_definition.display_name if affix_definition != null else String(affix.affix_id)
			var value_text := "%+.1f%%" % (affix.value * 100.0) if affix.is_percentage else "%+.1f" % affix.value
			lines.append("%s: %s" % [affix_name, value_text])
	var comparison := _comparison_text(item, definition)
	if not comparison.is_empty():
		lines.append("\n[color=#9b8ac4]СРАВНЕНИЕ[/color]\n%s" % comparison)
	details_label.text = "\n".join(lines)
	_build_actions(item, definition)

func _build_actions(item: ItemInstance, definition: ItemDefinition) -> void:
	if inventory.is_equipped(item.instance_id):
		_add_action("СНЯТЬ", _unequip_selected)
	elif definition.item_type != ItemEnums.ItemType.CONSUMABLE:
		_add_action("ЭКИПИРОВАТЬ", _equip_selected)
	if definition.item_type == ItemEnums.ItemType.CONSUMABLE:
		_add_action("НА 2", _assign_consumable.bind(ItemEnums.EquipmentSlot.CONSUMABLE_2))
		_add_action("НА 3", _assign_consumable.bind(ItemEnums.EquipmentSlot.CONSUMABLE_3))
		var assigned_slot := _equipped_slot_for(item.instance_id)
		if assigned_slot == ItemEnums.EquipmentSlot.CONSUMABLE_2 or assigned_slot == ItemEnums.EquipmentSlot.CONSUMABLE_3:
			_add_action("ИСПОЛЬЗОВАТЬ", inventory.use_consumable_slot.bind(assigned_slot))
	if shop_service != null and shop_service.can_sell(item.instance_id):
		_add_action("ПРОДАТЬ", _sell_selected)

func _add_action(text: String, callback: Callable) -> void:
	var button := _button(text)
	button.pressed.connect(callback)
	action_box.add_child(button)

func _select_item(instance_id: String) -> void:
	selected_instance_id = instance_id
	_refresh()

func _set_filter(filter_value: int) -> void:
	selected_filter = filter_value
	_refresh()

func _equip_selected() -> void:
	var item := inventory.find_item(selected_instance_id)
	var definition := game_content.item(item.definition_id) if item != null else null
	if definition == null:
		return
	var slot := definition.equipment_slot
	if slot == ItemEnums.EquipmentSlot.RING:
		slot = ItemEnums.EquipmentSlot.RING_1 if inventory.equipped_item(ItemEnums.EquipmentSlot.RING_1) == null else ItemEnums.EquipmentSlot.RING_2
	inventory.equip_item(item.instance_id, slot)
	_refresh()

func _unequip_selected() -> void:
	var slot := _equipped_slot_for(selected_instance_id)
	if slot != ItemEnums.EquipmentSlot.NONE:
		inventory.unequip_slot(slot)
	_refresh()

func _assign_consumable(slot: ItemEnums.EquipmentSlot) -> void:
	if inventory.equipped_item(slot) != null:
		inventory.unequip_slot(slot)
	inventory.equip_item(selected_instance_id, slot)
	_refresh()

func _sell_selected() -> void:
	if shop_service != null and shop_service.sell_item(selected_instance_id, 1):
		_refresh()

func _equipped_slot_for(instance_id: String) -> ItemEnums.EquipmentSlot:
	for slot in EQUIPMENT_SLOTS:
		if inventory.equipped_instance_id(slot) == instance_id:
			return slot
	return ItemEnums.EquipmentSlot.NONE

func _comparison_text(item: ItemInstance, definition: ItemDefinition) -> String:
	var slot := definition.equipment_slot
	if slot == ItemEnums.EquipmentSlot.RING:
		slot = ItemEnums.EquipmentSlot.RING_1
	if slot == ItemEnums.EquipmentSlot.NONE or slot == ItemEnums.EquipmentSlot.CONSUMABLE_2:
		return ""
	var equipped := inventory.equipped_definition(slot)
	var equipped_item := inventory.equipped_item(slot)
	if equipped == null or equipped_item == null or equipped_item.instance_id == item.instance_id:
		return ""
	return "%s (надето)\n%s\n\n%s (выбрано)\n%s" % [
		equipped.display_name,
		_definition_stats(equipped),
		definition.display_name,
		_definition_stats(definition),
	]

func _definition_stats(definition: ItemDefinition) -> String:
	if definition is WeaponDefinition:
		var weapon := definition as WeaponDefinition
		return "Урон %.0f · Cooldown %.2fс\nДальность %.0f · Ширина %.0f" % [weapon.base_damage, weapon.cooldown, weapon.base_attack_reach, weapon.attack_half_width * 2.0]
	if definition is ArmorDefinition:
		var armor := definition as ArmorDefinition
		return "Защита %.0f · Здоровье %+.0f\nСкорость %+.0f%%" % [armor.defense, armor.max_health_bonus, armor.movement_speed_modifier * 100.0]
	if definition is JewelryDefinition:
		var jewelry := definition as JewelryDefinition
		return "Урон %+.0f%% · Защита %+.0f · Здоровье %+.0f\nАтака %+.0f%% · Движение %+.0f%% · Крит %+.0f%%\nКрит. урон %+.0f%% · Добыча %+.0f%%" % [jewelry.damage_bonus * 100.0, jewelry.defense_bonus, jewelry.max_health_bonus, jewelry.attack_speed_bonus * 100.0, jewelry.movement_speed_bonus * 100.0, jewelry.critical_chance_bonus * 100.0, jewelry.critical_damage_bonus * 100.0, jewelry.loot_chance_bonus * 100.0]
	if definition is ConsumableDefinition:
		var consumable := definition as ConsumableDefinition
		return "Эффект: %s\nДлительность: %.0fс · Cooldown: %.1fс" % [_consumable_effect_name(consumable), consumable.duration, consumable.cooldown]
	return ""

func _consumable_effect_name(definition: ConsumableDefinition) -> String:
	match definition.effect_type:
		ItemEnums.ConsumableEffectType.HEAL: return "лечение %.0f" % definition.effect_value
		ItemEnums.ConsumableEffectType.DAMAGE_BOOST: return "урон +%.0f%%" % (definition.effect_value * 100.0)
		ItemEnums.ConsumableEffectType.DEFENSE_BOOST: return "защита +%.0f" % definition.effect_value
		ItemEnums.ConsumableEffectType.ATTACK_SPEED_BOOST: return "скорость атаки +%.0f%%" % (definition.effect_value * 100.0)
		ItemEnums.ConsumableEffectType.MOVEMENT_SPEED_BOOST: return "скорость движения +%.0f%%" % (definition.effect_value * 100.0)
	return "неизвестно"

func _slot_name(slot: ItemEnums.EquipmentSlot) -> String:
	return {
		ItemEnums.EquipmentSlot.WEAPON: "ОРУЖИЕ",
		ItemEnums.EquipmentSlot.ARMOR: "БРОНЯ",
		ItemEnums.EquipmentSlot.AMULET: "АМУЛЕТ",
		ItemEnums.EquipmentSlot.RING_1: "КОЛЬЦО I",
		ItemEnums.EquipmentSlot.RING_2: "КОЛЬЦО II",
		ItemEnums.EquipmentSlot.CONSUMABLE_2: "ЗЕЛЬЕ [2]",
		ItemEnums.EquipmentSlot.CONSUMABLE_3: "ЗЕЛЬЕ [3]",
	}.get(slot, "СЛОТ")

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_color_override("font_color", Color("d4c4a4"))
	button.add_theme_color_override("font_hover_color", Color("f0d58a"))
	return button

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		# A button may request this rebuild from its own `pressed` signal. Detach it
		# immediately, but defer destruction until Godot finishes emitting the signal.
		node.remove_child(child)
		child.queue_free()
