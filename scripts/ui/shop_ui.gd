class_name ShopUI
extends CanvasLayer

var game_content: GameContent
var inventory: InventoryService
var profile: PlayerProfile
var shop_service: ShopService
var current_shop_id: StringName
var selected_stock_id: StringName
var selected_owned_instance_id := ""
var selected_stock_filter: StringName = &"all"

var overlay: ColorRect
var title_label: Label
var gold_label: Label
var tab_box: HBoxContainer
var stock_box: VBoxContainer
var owned_box: VBoxContainer
var details_label: RichTextLabel
var buy_button: Button
var sell_button: Button
var message_label: Label

func configure(
	content: GameContent,
	inventory_service: InventoryService,
	player_profile: PlayerProfile,
	economy_service: ShopService
) -> void:
	game_content = content
	inventory = inventory_service
	profile = player_profile
	shop_service = economy_service

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	overlay.visible = false
	if inventory != null:
		inventory.inventory_changed.connect(_refresh)
		inventory.equipment_changed.connect(_refresh)
	if shop_service != null:
		shop_service.currency_changed.connect(func(_gold: int): _refresh())
		shop_service.notification_requested.connect(_show_message)

func _unhandled_input(event: InputEvent) -> void:
	if overlay != null and overlay.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open_shop(shop_id: StringName) -> void:
	if game_content == null or game_content.shop(shop_id) == null:
		return
	current_shop_id = shop_id
	selected_stock_id = &""
	selected_owned_instance_id = ""
	selected_stock_filter = _default_filter(shop_id)
	overlay.visible = true
	_refresh()

func close() -> void:
	if overlay != null:
		overlay.visible = false

func is_open() -> bool:
	return overlay != null and overlay.visible

func _build_interface() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.018, 0.012, 0.010, 0.97)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var frame := VBoxContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-560.0, -315.0)
	frame.size = Vector2(1120.0, 630.0)
	frame.add_theme_constant_override("separation", 12)
	overlay.add_child(frame)

	var header := HBoxContainer.new()
	frame.add_child(header)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("d0ad64"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 19)
	gold_label.add_theme_color_override("font_color", Color("d0ad64"))
	header.add_child(gold_label)
	var close_button := _button("ЗАКРЫТЬ")
	close_button.pressed.connect(close)
	header.add_child(close_button)
	tab_box = HBoxContainer.new()
	tab_box.add_theme_constant_override("separation", 6)
	frame.add_child(tab_box)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	frame.add_child(columns)
	stock_box = _scrolling_column(columns, "ТОВАРЫ", 360.0)
	details_label = RichTextLabel.new()
	details_label.bbcode_enabled = true
	details_label.custom_minimum_size = Vector2(350.0, 460.0)
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(details_label)
	owned_box = _scrolling_column(columns, "ВАШИ ПРЕДМЕТЫ", 360.0)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	frame.add_child(actions)
	buy_button = _button("КУПИТЬ")
	buy_button.custom_minimum_size = Vector2(180.0, 48.0)
	buy_button.pressed.connect(_buy_selected)
	actions.add_child(buy_button)
	sell_button = _button("ПРОДАТЬ 1")
	sell_button.custom_minimum_size = Vector2(180.0, 48.0)
	sell_button.pressed.connect(_sell_selected)
	actions.add_child(sell_button)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color("af7e4d"))
	frame.add_child(message_label)

func _scrolling_column(parent: Control, heading_text: String, width: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(width, 0.0)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", Color("d0ad64"))
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	return list

func _refresh() -> void:
	if overlay == null or inventory == null or shop_service == null:
		return
	var shop := game_content.shop(current_shop_id)
	if shop == null:
		return
	title_label.text = shop.display_name.to_upper()
	gold_label.text = "ЗОЛОТО: %d" % profile.gold
	_rebuild_tabs()
	_clear_children(stock_box)
	_clear_children(owned_box)
	for definition_id in shop.stock_definition_ids:
		var definition := game_content.item(definition_id)
		if definition == null or not _matches_stock_filter(definition):
			continue
		var stock_button := _button("%s\n%d золота" % [definition.display_name, definition.base_price])
		stock_button.custom_minimum_size = Vector2(340.0, 52.0)
		stock_button.pressed.connect(_select_stock.bind(definition.id))
		stock_box.add_child(stock_button)
	for item in inventory.get_items():
		var definition := game_content.item(item.definition_id)
		if definition == null or not definition.can_sell:
			continue
		var owned_button := _button("%s%s\nПродажа: %d" % [
			"%s · ур. %d" % [definition.display_name, item.item_level],
			" ×%d" % item.quantity if item.quantity > 1 else "",
			definition.resolved_item_sell_price(item),
		])
		owned_button.add_theme_color_override("font_color", ItemRarityPresentation.color(item.rarity))
		owned_button.custom_minimum_size = Vector2(340.0, 52.0)
		owned_button.disabled = not shop_service.can_sell(item.instance_id)
		owned_button.pressed.connect(_select_owned.bind(item.instance_id))
		owned_box.add_child(owned_button)
	_rebuild_details()

func _rebuild_tabs() -> void:
	_clear_children(tab_box)
	var tabs: Array = []
	match current_shop_id:
		&"blacksmith": tabs = [["ОРУЖИЕ", &"weapon"], ["БРОНЯ", &"armor"]]
		&"jewelry": tabs = [["АМУЛЕТЫ", &"amulet"], ["КОЛЬЦА", &"ring"]]
		&"alchemist": tabs = [["ЛЕЧЕНИЕ", &"healing"], ["УСИЛЕНИЯ", &"buff"]]
		_: tabs = [["ВСЕ", &"all"]]
	for tab_data in tabs:
		var filter_id := StringName(tab_data[1])
		var marker := "◆ " if filter_id == selected_stock_filter else ""
		var tab_button := _button(marker + String(tab_data[0]))
		tab_button.pressed.connect(_set_stock_filter.bind(filter_id))
		tab_box.add_child(tab_button)

func _set_stock_filter(filter_id: StringName) -> void:
	selected_stock_filter = filter_id
	selected_stock_id = &""
	_refresh()

func _default_filter(shop_id: StringName) -> StringName:
	match shop_id:
		&"blacksmith": return &"weapon"
		&"jewelry": return &"amulet"
		&"alchemist": return &"healing"
	return &"all"

func _matches_stock_filter(definition: ItemDefinition) -> bool:
	match selected_stock_filter:
		&"weapon": return definition.item_type == ItemEnums.ItemType.WEAPON
		&"armor": return definition.item_type == ItemEnums.ItemType.ARMOR
		&"amulet": return definition.equipment_slot == ItemEnums.EquipmentSlot.AMULET
		&"ring": return definition.equipment_slot == ItemEnums.EquipmentSlot.RING
		&"healing": return definition is ConsumableDefinition and (definition as ConsumableDefinition).effect_type == ItemEnums.ConsumableEffectType.HEAL
		&"buff": return definition is ConsumableDefinition and (definition as ConsumableDefinition).effect_type != ItemEnums.ConsumableEffectType.HEAL
	return true

func _rebuild_details() -> void:
	buy_button.disabled = selected_stock_id.is_empty() or not shop_service.can_buy(current_shop_id, selected_stock_id)
	sell_button.disabled = selected_owned_instance_id.is_empty() or not shop_service.can_sell(selected_owned_instance_id)
	if not selected_stock_id.is_empty():
		var definition := game_content.item(selected_stock_id)
		details_label.text = _definition_details(definition, "ПОКУПКА: %d" % definition.base_price)
		return
	var item := inventory.find_item(selected_owned_instance_id)
	if item != null:
		var definition := game_content.item(item.definition_id)
		details_label.text = _item_details(item, definition, "ПРОДАЖА: %d" % definition.resolved_item_sell_price(item))
		return
	details_label.text = "[color=#8f7c61]Выберите товар для покупки или свой предмет для продажи.[/color]"

func _definition_details(definition: ItemDefinition, price_text: String) -> String:
	if definition == null:
		return ""
	return "[font_size=24][color=#d0ad64]%s[/color][/font_size]\n%s\n\n%s\n\n[color=#d0ad64]%s[/color]" % [
		definition.display_name,
		ItemEnums.item_type_name(definition.item_type),
		definition.description,
		price_text,
	]

func _item_details(item: ItemInstance, definition: ItemDefinition, price_text: String) -> String:
	if item == null or definition == null:
		return ""
	var rarity_color := ItemRarityPresentation.color_html(item.rarity)
	var lines: Array[String] = [
		"[font_size=24][color=#%s]%s[/color][/font_size]" % [rarity_color, definition.display_name],
		"[color=#%s]%s[/color] · уровень %d" % [rarity_color, ItemRarityPresentation.rarity_name(item.rarity), item.item_level],
		"",
		definition.description,
	]
	if not item.affixes.is_empty():
		lines.append("\n[color=#73b86b]СЛУЧАЙНЫЕ СВОЙСТВА[/color]")
		for affix in item.affixes:
			lines.append(ItemRarityPresentation.format_affix(affix, game_content))
	lines.append("\n[color=#d0ad64]%s[/color]" % price_text)
	return "\n".join(lines)

func _select_stock(definition_id: StringName) -> void:
	selected_stock_id = definition_id
	selected_owned_instance_id = ""
	_rebuild_details()

func _select_owned(instance_id: String) -> void:
	selected_owned_instance_id = instance_id
	selected_stock_id = &""
	_rebuild_details()

func _buy_selected() -> void:
	if shop_service.buy_item(current_shop_id, selected_stock_id, 1):
		_show_message("Покупка совершена")
	_refresh()

func _sell_selected() -> void:
	if shop_service.sell_item(selected_owned_instance_id, 1):
		_show_message("Предмет продан")
		selected_owned_instance_id = ""
	_refresh()

func _show_message(message: String) -> void:
	if message_label != null:
		message_label.text = message

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_color_override("font_color", Color("d4c4a4"))
	button.add_theme_color_override("font_hover_color", Color("f0d58a"))
	return button

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		# Shop filters and stock buttons can rebuild their own container while they
		# are emitting `pressed`, so immediate `free()` would target a locked object.
		node.remove_child(child)
		child.queue_free()
