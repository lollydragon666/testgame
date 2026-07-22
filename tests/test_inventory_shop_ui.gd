extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	_require(InputMap.has_action("toggle_inventory"), "Inventory input action is missing")
	var inventory := InventoryService.new()
	inventory.configure(CONTENT)
	inventory.load_serialized([], {})
	inventory.add_item_by_definition(&"cloth_armor")
	inventory.add_item_by_definition(&"strength_ring")
	inventory.add_item_by_definition(&"small_healing_potion", 3)
	var profile := PlayerProfile.new()
	profile.gold = 5000
	var shop_service := ShopService.new()
	shop_service.configure(CONTENT, inventory, profile)

	var inventory_ui := InventoryUI.new()
	inventory_ui.configure(CONTENT, inventory, profile, shop_service)
	root.add_child(inventory_ui)
	await process_frame
	inventory_ui.open()
	_require(inventory_ui.is_open(), "Inventory window did not open")
	_require(inventory_ui.item_grid.get_child_count() == inventory.inventory_size(), "Inventory grid does not show all items")
	_require(inventory_ui.equipment_box.get_child_count() == InventoryUI.EQUIPMENT_SLOTS.size() + 1, "Equipment panel has a wrong slot count")
	_require(inventory_ui.capacity_label.text.contains("%d / %d" % [inventory.inventory_size(), InventoryService.CAPACITY]), "Inventory capacity is not displayed")
	inventory_ui._set_filter(ItemEnums.ItemType.ARMOR)
	_require(inventory_ui.selected_filter == ItemEnums.ItemType.ARMOR, "Inventory category filter did not change")
	_require(inventory_ui.item_grid.get_child_count() == 1, "Armor filter shows items from other categories")
	var armor: ItemInstance
	for item in inventory.get_items():
		if item.definition_id == &"cloth_armor": armor = item
	inventory_ui._select_item(armor.instance_id)
	_require(inventory_ui.details_label.text.contains("Стёганая броня"), "Item detail panel did not update")
	_require(inventory_ui.action_box.get_child_count() > 0, "Item actions were not created")
	inventory_ui._equip_selected()
	_require(inventory.equipped_instance_id(ItemEnums.EquipmentSlot.ARMOR) == armor.instance_id, "UI equip action did not use InventoryService")
	_require(inventory_ui.details_label.text.contains("Стёганая броня"), "Equipment signal did not refresh UI")
	inventory_ui.close()
	_require(not inventory_ui.is_open(), "Inventory window did not close")

	var shop_ui := ShopUI.new()
	shop_ui.configure(CONTENT, inventory, profile, shop_service)
	root.add_child(shop_ui)
	await process_frame
	shop_ui.open_shop(&"blacksmith")
	_require(shop_ui.is_open(), "Shop window did not open")
	_require(shop_ui.title_label.text == "КУЗНЕЦ", "Shop title does not come from ShopDefinition")
	_require(shop_ui.selected_stock_filter == &"weapon", "Blacksmith did not open on weapon tab")
	_require(shop_ui.tab_box.get_child_count() == 2, "Blacksmith tabs are missing")
	_require(shop_ui.stock_box.get_child_count() > 0, "Blacksmith stock was not rendered")
	var gold_before := profile.gold
	shop_ui._select_stock(&"old_gladius")
	shop_ui._buy_selected()
	_require(profile.gold == gold_before - CONTENT.item(&"old_gladius").base_price, "Shop UI did not execute exact service price")
	_require(_has_definition(inventory, &"old_gladius"), "Shop UI purchase did not add item")
	shop_ui.open_shop(&"jewelry")
	_require(shop_ui.selected_stock_filter == &"amulet" and shop_ui.tab_box.get_child_count() == 2, "Jewelry tabs are missing")
	shop_ui.open_shop(&"alchemist")
	_require(shop_ui.selected_stock_filter == &"healing" and shop_ui.tab_box.get_child_count() == 2, "Alchemist tabs are missing")
	shop_ui.close()
	_require(not shop_ui.is_open(), "Shop window did not close")

	inventory_ui.queue_free()
	shop_ui.queue_free()
	await process_frame
	print("INVENTORY SHOP UI PASS")
	quit()

func _has_definition(inventory: InventoryService, definition_id: StringName) -> bool:
	for item in inventory.get_items():
		if item.definition_id == definition_id:
			return true
	return false
