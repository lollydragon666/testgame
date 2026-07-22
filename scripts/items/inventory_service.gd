class_name InventoryService
extends RefCounted

signal inventory_changed
signal item_added(instance_id: String)
signal item_removed(instance_id: String)
signal equipment_changed
signal consumable_slot_changed(slot: ItemEnums.EquipmentSlot)
signal consumable_cooldown_changed(slot: ItemEnums.EquipmentSlot, remaining: float, duration: float)

const CAPACITY := 40
const STARTER_WEAPON_ID := &"player_sword"

var game_content: GameContent
var _items: Array[ItemInstance] = []
var _equipped_items: Dictionary = {}
var _consumable_cooldowns: Dictionary[ItemEnums.EquipmentSlot, float] = {}
var _consumable_handler: Callable

func configure(content: GameContent) -> void:
	game_content = content
	_reset_equipment()
	reset_consumable_runtime()

func configure_consumable_handler(handler: Callable) -> void:
	_consumable_handler = handler

func _reset_equipment() -> void:
	_equipped_items = {
		ItemEnums.EquipmentSlot.WEAPON: "",
		ItemEnums.EquipmentSlot.ARMOR: "",
		ItemEnums.EquipmentSlot.AMULET: "",
		ItemEnums.EquipmentSlot.RING_1: "",
		ItemEnums.EquipmentSlot.RING_2: "",
		ItemEnums.EquipmentSlot.CONSUMABLE_2: "",
		ItemEnums.EquipmentSlot.CONSUMABLE_3: "",
	}

func load_serialized(saved_items: Array, saved_equipment: Dictionary, legacy_weapon_id: StringName = &"") -> void:
	_items.clear()
	_reset_equipment()
	var seen_ids: Dictionary[String, bool] = {}
	for item_data in saved_items:
		if not item_data is Dictionary:
			push_warning("Skipping malformed inventory entry")
			continue
		var item := ItemInstance.from_dict(item_data)
		if item == null or game_content.item(item.definition_id) == null or seen_ids.has(item.instance_id):
			push_warning("Skipping invalid or duplicate inventory item")
			continue
		seen_ids[item.instance_id] = true
		_items.append(item)
	for slot_key in saved_equipment:
		var slot := int(slot_key)
		var instance_id := String(saved_equipment[slot_key])
		if _equipped_items.has(slot) and not instance_id.is_empty():
			var item := find_item(instance_id)
			var definition := game_content.item(item.definition_id) if item != null else null
			if definition != null and definition.accepts_slot(slot as ItemEnums.EquipmentSlot) and not _is_instance_equipped(instance_id):
				_equipped_items[slot] = instance_id
	_migrate_starter_weapon(legacy_weapon_id)

func _migrate_starter_weapon(legacy_weapon_id: StringName) -> void:
	var requested_weapon := legacy_weapon_id if not legacy_weapon_id.is_empty() and game_content.weapon(legacy_weapon_id) != null else STARTER_WEAPON_ID
	var weapon_item: ItemInstance
	for item in _items:
		if item.definition_id == requested_weapon:
			weapon_item = item
			break
	if weapon_item == null:
		weapon_item = ItemInstance.create(requested_weapon)
		_items.append(weapon_item)
	if String(_equipped_items[ItemEnums.EquipmentSlot.WEAPON]).is_empty():
		_equipped_items[ItemEnums.EquipmentSlot.WEAPON] = weapon_item.instance_id

func add_item(item: ItemInstance) -> bool:
	if item == null or item.quantity <= 0 or item.instance_id.is_empty():
		return false
	var definition := game_content.item(item.definition_id) if game_content != null else null
	if definition == null:
		return false
	if not can_add_item(item):
		return false
	if not definition.stackable:
		for index in item.quantity:
			var added := item if index == 0 else ItemInstance.create(item.definition_id, 1, item.rarity)
			added.quantity = 1
			_items.append(added)
			item_added.emit(added.instance_id)
	else:
		_add_stackable(item, definition)
	inventory_changed.emit()
	return true

func can_add_item(item: ItemInstance) -> bool:
	if item == null or item.quantity <= 0 or game_content == null:
		return false
	var definition := game_content.item(item.definition_id)
	if definition == null:
		return false
	var required_slots := item.quantity
	if definition.stackable:
		var remaining := item.quantity
		for existing in _items:
			if _can_stack(existing, item, definition):
				remaining -= maxi(0, definition.max_stack - existing.quantity)
				if remaining <= 0:
					return true
		required_slots = ceili(float(remaining) / float(maxi(1, definition.max_stack)))
	return _items.size() + required_slots <= CAPACITY

func _add_stackable(item: ItemInstance, definition: ItemDefinition) -> void:
	var remaining := item.quantity
	for existing in _items:
		if not _can_stack(existing, item, definition):
			continue
		var moved := mini(remaining, definition.max_stack - existing.quantity)
		existing.quantity += moved
		remaining -= moved
		if remaining <= 0:
			return
	while remaining > 0:
		var stack_quantity := mini(remaining, definition.max_stack)
		var stack := item if remaining == item.quantity else ItemInstance.create(item.definition_id, stack_quantity, item.rarity)
		stack.quantity = stack_quantity
		stack.affixes = item.affixes.duplicate()
		_items.append(stack)
		item_added.emit(stack.instance_id)
		remaining -= stack_quantity

func _can_stack(first: ItemInstance, second: ItemInstance, definition: ItemDefinition) -> bool:
	return (
		definition.stackable
		and first.definition_id == second.definition_id
		and first.rarity == second.rarity
		and first.quantity < definition.max_stack
		and JSON.stringify(first.to_dict().get("affixes", [])) == JSON.stringify(second.to_dict().get("affixes", []))
	)

func add_item_by_definition(definition_id: StringName, quantity := 1) -> bool:
	if quantity <= 0 or game_content == null:
		return false
	var definition := game_content.item(definition_id)
	if definition == null:
		return false
	return add_item(ItemInstance.create(definition_id, quantity, definition.rarity))

func remove_item(instance_id: String, quantity := 1) -> bool:
	if quantity <= 0:
		return false
	var item := find_item(instance_id)
	if item == null or quantity > item.quantity:
		return false
	if quantity == item.quantity and _is_instance_equipped(instance_id):
		return false
	item.quantity -= quantity
	if item.quantity <= 0:
		_items.erase(item)
		item_removed.emit(instance_id)
	inventory_changed.emit()
	return true

func find_item(instance_id: String) -> ItemInstance:
	for item in _items:
		if item.instance_id == instance_id:
			return item
	return null

func get_items() -> Array[ItemInstance]:
	return _items.duplicate()

func get_items_by_type(item_type: ItemEnums.ItemType) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item in _items:
		var definition := game_content.item(item.definition_id)
		if definition != null and definition.item_type == item_type:
			result.append(item)
	return result

func equip_item(instance_id: String, target_slot: ItemEnums.EquipmentSlot) -> bool:
	if not _equipped_items.has(target_slot) or _is_instance_equipped(instance_id):
		return false
	var item := find_item(instance_id)
	var definition := game_content.item(item.definition_id) if item != null else null
	if definition == null or not definition.accepts_slot(target_slot):
		return false
	if target_slot == ItemEnums.EquipmentSlot.RING_1 or target_slot == ItemEnums.EquipmentSlot.RING_2:
		if not definition.allow_duplicate_equipment and _definition_is_equipped(item.definition_id):
			return false
	_equipped_items[target_slot] = instance_id
	equipment_changed.emit()
	if target_slot == ItemEnums.EquipmentSlot.CONSUMABLE_2 or target_slot == ItemEnums.EquipmentSlot.CONSUMABLE_3:
		consumable_slot_changed.emit(target_slot)
	return true

func unequip_slot(slot: ItemEnums.EquipmentSlot) -> bool:
	if not _equipped_items.has(slot) or String(_equipped_items[slot]).is_empty():
		return false
	_equipped_items[slot] = ""
	equipment_changed.emit()
	if slot == ItemEnums.EquipmentSlot.CONSUMABLE_2 or slot == ItemEnums.EquipmentSlot.CONSUMABLE_3:
		consumable_slot_changed.emit(slot)
	return true

func equipped_instance_id(slot: ItemEnums.EquipmentSlot) -> String:
	return String(_equipped_items.get(slot, ""))

func equipped_item(slot: ItemEnums.EquipmentSlot) -> ItemInstance:
	return find_item(equipped_instance_id(slot))

func equipped_definition(slot: ItemEnums.EquipmentSlot) -> ItemDefinition:
	var item := equipped_item(slot)
	return game_content.item(item.definition_id) if item != null else null

func is_equipped(instance_id: String) -> bool:
	return _is_instance_equipped(instance_id)

func _is_instance_equipped(instance_id: String) -> bool:
	return not instance_id.is_empty() and _equipped_items.values().has(instance_id)

func _definition_is_equipped(definition_id: StringName) -> bool:
	for instance_id in _equipped_items.values():
		var item := find_item(String(instance_id))
		if item != null and item.definition_id == definition_id:
			return true
	return false

func serialized_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _items:
		result.append(item.to_dict())
	return result

func serialized_equipment() -> Dictionary:
	var result := {}
	for slot in _equipped_items:
		result[String.num_int64(slot)] = String(_equipped_items[slot])
	return result

func inventory_size() -> int:
	return _items.size()

func use_consumable_slot(slot: ItemEnums.EquipmentSlot) -> bool:
	if slot != ItemEnums.EquipmentSlot.CONSUMABLE_2 and slot != ItemEnums.EquipmentSlot.CONSUMABLE_3:
		return false
	if consumable_cooldown_remaining(slot) > 0.0 or not _consumable_handler.is_valid():
		return false
	var item := equipped_item(slot)
	var definition := equipped_definition(slot) as ConsumableDefinition
	if item == null or item.quantity <= 0 or definition == null:
		return false
	if not bool(_consumable_handler.call(definition)):
		return false
	var consumed_instance_id := item.instance_id
	if item.quantity == 1:
		_equipped_items[slot] = ""
		consumable_slot_changed.emit(slot)
	if not remove_item(consumed_instance_id, 1):
		if item.quantity == 1:
			_equipped_items[slot] = consumed_instance_id
		return false
	_consumable_cooldowns[slot] = maxf(0.0, definition.cooldown)
	consumable_cooldown_changed.emit(slot, definition.cooldown, definition.cooldown)
	return true

func tick_consumable_cooldowns(delta: float) -> void:
	if delta <= 0.0:
		return
	for slot in _consumable_cooldowns.keys():
		var previous := _consumable_cooldowns[slot]
		var remaining := maxf(0.0, previous - delta)
		_consumable_cooldowns[slot] = remaining
		if not is_equal_approx(previous, remaining):
			var definition := equipped_definition(slot) as ConsumableDefinition
			var duration := definition.cooldown if definition != null else previous
			consumable_cooldown_changed.emit(slot, remaining, duration)
		if remaining <= 0.0:
			_consumable_cooldowns.erase(slot)

func consumable_cooldown_remaining(slot: ItemEnums.EquipmentSlot) -> float:
	return float(_consumable_cooldowns.get(slot, 0.0))

func reset_consumable_runtime() -> void:
	_consumable_cooldowns.clear()
	for slot in [ItemEnums.EquipmentSlot.CONSUMABLE_2, ItemEnums.EquipmentSlot.CONSUMABLE_3]:
		consumable_cooldown_changed.emit(slot, 0.0, 0.0)

func clear_for_tests() -> void:
	_items.clear()
	_reset_equipment()
	reset_consumable_runtime()
