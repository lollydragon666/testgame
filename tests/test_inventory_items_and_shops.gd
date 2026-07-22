extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _inventory(with_starter := true) -> InventoryService:
	var result := InventoryService.new()
	result.configure(CONTENT)
	if with_starter:
		result.load_serialized([], {})
	return result

func _run() -> void:
	_validate_catalog()
	_validate_inventory()
	_validate_equipment()
	_validate_shops()
	print("INVENTORY ITEMS AND SHOPS PASS")
	quit()

func _validate_catalog() -> void:
	var seen: Dictionary[StringName, bool] = {}
	var weapon_count := 0
	var armor_count := 0
	var amulet_count := 0
	var ring_count := 0
	var consumable_count := 0
	for definition in CONTENT.all_items():
		_require(definition != null and not definition.id.is_empty(), "Item definition is null or has no ID")
		_require(not seen.has(definition.id), "Duplicate item ID: %s" % definition.id)
		seen[definition.id] = true
		_require(definition.base_price >= 0 and definition.resolved_sell_price() >= 0, "Item has a negative price: %s" % definition.id)
		_require(definition.equipment_slot != ItemEnums.EquipmentSlot.NONE, "Item has no valid slot: %s" % definition.id)
		if definition is WeaponDefinition:
			weapon_count += 1
			_require((definition as WeaponDefinition).weapon_class == ItemEnums.SWORD_CLASS, "A non-sword weapon class was added")
		elif definition is ArmorDefinition:
			armor_count += 1
		elif definition is JewelryDefinition:
			if definition.equipment_slot == ItemEnums.EquipmentSlot.AMULET:
				amulet_count += 1
			elif definition.equipment_slot == ItemEnums.EquipmentSlot.RING:
				ring_count += 1
		elif definition is ConsumableDefinition:
			consumable_count += 1
			_require(definition.stackable and definition.max_stack == 20, "Potion stack contract is invalid: %s" % definition.id)
	_require(weapon_count == 15, "Expected exactly 15 swords, got %d" % weapon_count)
	_require(armor_count == 10, "Expected exactly 10 armor sets, got %d" % armor_count)
	_require(amulet_count == 6, "Expected exactly 6 amulets, got %d" % amulet_count)
	_require(ring_count == 8, "Expected exactly 8 rings, got %d" % ring_count)
	_require(consumable_count == 6, "Expected exactly 6 potions, got %d" % consumable_count)
	for shop in CONTENT.shops:
		_require(shop != null and not shop.id.is_empty(), "Invalid shop definition")
		for item_id in shop.stock_definition_ids:
			_require(CONTENT.item(item_id) != null, "Shop references missing item: %s" % item_id)

func _validate_inventory() -> void:
	var inventory := _inventory()
	_require(inventory.inventory_size() == 1, "Starter sword migration did not add exactly one item")
	var first_starter_id := inventory.equipped_instance_id(ItemEnums.EquipmentSlot.WEAPON)
	inventory.load_serialized(inventory.serialized_items(), inventory.serialized_equipment())
	_require(inventory.inventory_size() == 1, "Starter sword duplicated after loading migrated data")
	_require(inventory.equipped_instance_id(ItemEnums.EquipmentSlot.WEAPON) == first_starter_id, "Starter sword instance ID changed during load")

	inventory.clear_for_tests()
	var inventory_changed_count := 0
	inventory.inventory_changed.connect(func(): inventory_changed_count += 1)
	for _index in InventoryService.CAPACITY:
		_require(inventory.add_item_by_definition(&"old_gladius"), "Non-stackable item could not fill an available slot")
	_require(inventory.inventory_size() == InventoryService.CAPACITY, "Inventory capacity is not 40")
	_require(not inventory.add_item_by_definition(&"old_gladius"), "Inventory accepted item beyond capacity")
	_require(inventory_changed_count == InventoryService.CAPACITY, "Inventory change signal count is incorrect")
	_require(not inventory.add_item_by_definition(&"missing_item"), "Unknown item definition was accepted")

	inventory.clear_for_tests()
	_require(inventory.add_item_by_definition(&"small_healing_potion", 25), "Potion stack could not be added")
	_require(inventory.inventory_size() == 2, "A stack of 25 potions must occupy two cells")
	var total_quantity := 0
	var largest_stack := 0
	for item in inventory.get_items():
		total_quantity += item.quantity
		largest_stack = maxi(largest_stack, item.quantity)
	_require(total_quantity == 25 and largest_stack == 20, "Potion max stack of 20 was not enforced")
	var stack := inventory.get_items()[0]
	_require(inventory.remove_item(stack.instance_id, 1), "Item removal failed")
	_require(inventory.find_item(stack.instance_id).quantity == stack.quantity, "Inventory snapshot unexpectedly mutated storage")

func _validate_equipment() -> void:
	var inventory := _inventory()
	for item_id in [&"cloth_armor", &"health_amulet", &"strength_ring", &"haste_ring"]:
		_require(inventory.add_item_by_definition(item_id), "Could not add equipment: %s" % item_id)
	var armor := inventory.get_items_by_type(ItemEnums.ItemType.ARMOR)[0]
	_require(not inventory.equip_item(armor.instance_id, ItemEnums.EquipmentSlot.WEAPON), "Armor was equipped as a weapon")
	_require(inventory.equip_item(armor.instance_id, ItemEnums.EquipmentSlot.ARMOR), "Armor could not be equipped")
	_require(not inventory.equip_item(armor.instance_id, ItemEnums.EquipmentSlot.RING_1), "One instance was equipped in two slots")
	var amulet: ItemInstance
	for item in inventory.get_items_by_type(ItemEnums.ItemType.JEWELRY):
		if item.definition_id == &"health_amulet": amulet = item
	_require(amulet != null and inventory.equip_item(amulet.instance_id, ItemEnums.EquipmentSlot.AMULET), "Amulet equip failed")
	_require(not inventory.equip_item(amulet.instance_id, ItemEnums.EquipmentSlot.RING_1), "Amulet was equipped into a ring slot")
	var ring_one: ItemInstance
	var ring_two: ItemInstance
	for item in inventory.get_items_by_type(ItemEnums.ItemType.JEWELRY):
		if item.definition_id == &"strength_ring": ring_one = item
		elif item.definition_id == &"haste_ring": ring_two = item
	_require(inventory.equip_item(ring_one.instance_id, ItemEnums.EquipmentSlot.RING_1), "First ring equip failed")
	_require(inventory.equip_item(ring_two.instance_id, ItemEnums.EquipmentSlot.RING_2), "Second ring equip failed")
	_require(inventory.unequip_slot(ItemEnums.EquipmentSlot.ARMOR), "Armor could not be unequipped")

	var duplicate_a := ItemInstance.create(&"haste_ring")
	var duplicate_b := ItemInstance.create(&"haste_ring")
	_require(inventory.add_item(duplicate_a) and inventory.add_item(duplicate_b), "Duplicate-rule setup failed")
	inventory.unequip_slot(ItemEnums.EquipmentSlot.RING_2)
	_require(inventory.equip_item(duplicate_a.instance_id, ItemEnums.EquipmentSlot.RING_1) or inventory.equipped_instance_id(ItemEnums.EquipmentSlot.RING_1) == duplicate_a.instance_id, "Restricted ring setup failed")
	_require(not inventory.equip_item(duplicate_b.instance_id, ItemEnums.EquipmentSlot.RING_2), "Restricted duplicate ring was equipped")

func _validate_shops() -> void:
	var blacksmith := CONTENT.shop(&"blacksmith")
	var jewelry := CONTENT.shop(&"jewelry")
	var alchemist := CONTENT.shop(&"alchemist")
	for item_id in blacksmith.stock_definition_ids:
		_require([ItemEnums.ItemType.WEAPON, ItemEnums.ItemType.ARMOR].has(CONTENT.item(item_id).item_type), "Blacksmith sells a wrong category")
	for item_id in jewelry.stock_definition_ids:
		_require(CONTENT.item(item_id).item_type == ItemEnums.ItemType.JEWELRY, "Jewelry shop sells a wrong category")
	for item_id in alchemist.stock_definition_ids:
		_require(CONTENT.item(item_id).item_type == ItemEnums.ItemType.CONSUMABLE, "Alchemist sells a wrong category")

	var inventory := _inventory()
	var profile := PlayerProfile.new()
	profile.gold = 1000
	var save_count := 0
	var gold_seen_by_inventory_signal := -1
	inventory.inventory_changed.connect(func(): gold_seen_by_inventory_signal = profile.gold)
	var shop := ShopService.new()
	shop.configure(CONTENT, inventory, profile, func(): save_count += 1)
	var price := CONTENT.item(&"old_gladius").base_price
	_require(shop.buy_item(&"blacksmith", &"old_gladius"), "Valid blacksmith purchase failed")
	_require(profile.gold == 1000 - price, "Purchase did not deduct exact price")
	_require(gold_seen_by_inventory_signal == profile.gold, "Inventory signal exposed purchase before currency deduction")
	_require(save_count == 1, "Successful purchase did not request a save")
	var purchased: ItemInstance
	for item in inventory.get_items():
		if item.definition_id == &"old_gladius": purchased = item
	_require(purchased != null, "Purchased item was not added")
	var gold_before_failed_purchase := profile.gold
	_require(not shop.buy_item(&"jewelry", &"old_gladius"), "Shop accepted item outside its stock")
	_require(profile.gold == gold_before_failed_purchase, "Failed purchase changed currency")
	profile.gold = 0
	_require(not shop.buy_item(&"blacksmith", &"iron_sabre"), "Purchase succeeded without enough gold")
	_require(shop.sell_item(purchased.instance_id), "Valid item sale failed")
	_require(gold_seen_by_inventory_signal == profile.gold, "Inventory signal exposed sale before currency grant")
	_require(inventory.find_item(purchased.instance_id) == null, "Sold item remained in inventory")
	var starter_id := inventory.equipped_instance_id(ItemEnums.EquipmentSlot.WEAPON)
	_require(not shop.can_sell(starter_id), "Starter sword can be sold")

	var full_inventory := _inventory(false)
	for _index in InventoryService.CAPACITY:
		_require(full_inventory.add_item_by_definition(&"old_gladius"), "Full-shop setup failed")
	var rich_profile := PlayerProfile.new()
	rich_profile.gold = 100000
	var full_shop := ShopService.new()
	full_shop.configure(CONTENT, full_inventory, rich_profile)
	_require(not full_shop.buy_item(&"blacksmith", &"iron_sabre"), "Purchase succeeded with full inventory")
	_require(rich_profile.gold == 100000, "Full-inventory purchase deducted gold")
