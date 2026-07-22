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
var item_factory := ItemFactory.new()
var _items: Array[ItemInstance] = []
var _run_inventory: RunInventoryService
var _starting_permanent_equipment: Dictionary = {}
var _equipped_items: Dictionary = {}
var _consumable_cooldowns: Dictionary[ItemEnums.EquipmentSlot, float] = {}
var _consumable_handler: Callable
var _transaction_depth := 0
var _inventory_change_pending := false

func configure(content: GameContent) -> void:
	game_content = content
	item_factory.configure(content)
	_reset_equipment()
	reset_consumable_runtime()

func configure_consumable_handler(handler: Callable) -> void:
	_consumable_handler = handler

func attach_run_inventory(storage: RunInventoryService, starting_equipment: Dictionary) -> void:
	if _run_inventory == storage:
		_starting_permanent_equipment = starting_equipment.duplicate(true)
		return
	if _run_inventory != null and _run_inventory.run_inventory_changed.is_connected(_on_run_inventory_changed):
		_run_inventory.run_inventory_changed.disconnect(_on_run_inventory_changed)
	_run_inventory = storage
	_starting_permanent_equipment = starting_equipment.duplicate(true)
	if _run_inventory != null:
		_run_inventory.run_inventory_changed.connect(_on_run_inventory_changed)
	_emit_inventory_changed()

func detach_run_inventory() -> void:
	if _run_inventory != null and _run_inventory.run_inventory_changed.is_connected(_on_run_inventory_changed):
		_run_inventory.run_inventory_changed.disconnect(_on_run_inventory_changed)
	_run_inventory = null
	_starting_permanent_equipment.clear()
	# Remove dangling references to discarded run items.
	for slot in _equipped_items:
		if _find_permanent_item(String(_equipped_items[slot])) == null:
			_equipped_items[slot] = ""
	_emit_inventory_changed()
	equipment_changed.emit()

func _on_run_inventory_changed() -> void:
	_emit_inventory_changed()

func begin_transaction() -> void:
	_transaction_depth += 1

func end_transaction() -> void:
	if _transaction_depth <= 0:
		return
	_transaction_depth -= 1
	if _transaction_depth == 0 and _inventory_change_pending:
		_inventory_change_pending = false
		inventory_changed.emit()

func _emit_inventory_changed() -> void:
	if _transaction_depth > 0:
		_inventory_change_pending = true
	else:
		inventory_changed.emit()

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
		var item := _deserialize_item(item_data)
		if item == null:
			continue
		if seen_ids.has(item.instance_id):
			var duplicate_id := item.instance_id
			item.instance_id = ItemInstance.generate_instance_id()
			push_warning("Duplicate inventory ID %s was replaced with %s; equipment keeps the first item" % [duplicate_id, item.instance_id])
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

func _deserialize_item(data: Dictionary) -> ItemInstance:
	var definition_id := StringName(String(data.get("definition_id", "")))
	var definition := game_content.item(definition_id) if game_content != null else null
	if definition == null:
		push_warning("Skipping inventory item with an unknown definition: %s" % definition_id)
		return null
	var quantity := int(data.get("quantity", 0))
	var instance_id := String(data.get("instance_id", ""))
	if instance_id.is_empty() or quantity <= 0 or (not definition.stackable and quantity != 1):
		push_warning("Skipping inventory item with invalid identity or quantity: %s" % definition_id)
		return null
	var legacy_fixed_item := not data.has("rarity") or not data.has("item_level")
	var rarity_value := int(definition.rarity) if legacy_fixed_item else int(data.get("rarity", -1))
	var item_level := 1 if legacy_fixed_item else int(data.get("item_level", 0))
	if rarity_value < ItemEnums.ItemRarity.COMMON or rarity_value > ItemEnums.ItemRarity.LEGENDARY:
		push_warning("Skipping inventory item with invalid rarity: %s" % definition_id)
		return null
	if item_level < ItemFactory.MINIMUM_ITEM_LEVEL or item_level > ItemFactory.MAXIMUM_ITEM_LEVEL:
		push_warning("Skipping inventory item with invalid item level: %s" % definition_id)
		return null
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = definition_id
	item.quantity = quantity
	item.rarity = rarity_value as ItemEnums.ItemRarity
	item.item_level = item_level
	item.generated_seed = int(data.get("generated_seed", 0))
	var parameters: Variant = data.get("saved_parameters", {})
	item.saved_parameters = parameters.duplicate(true) if parameters is Dictionary else {}
	if not legacy_fixed_item:
		_load_valid_affixes(item, definition, data.get("affixes", []))
	if not item_factory.validate_item_instance(item):
		push_warning("Skipping inventory item that failed validation: %s" % definition_id)
		return null
	return item

func _load_valid_affixes(item: ItemInstance, definition: ItemDefinition, saved_affixes: Variant) -> void:
	if not saved_affixes is Array:
		push_warning("Ignoring malformed affix list on %s" % item.instance_id)
		return
	var seen_ids: Dictionary[StringName, bool] = {}
	var seen_groups: Dictionary[StringName, bool] = {}
	var maximum_count := item_factory.affix_generator.affix_count_for_rarity(item.rarity)
	for affix_data in saved_affixes:
		if item.affixes.size() >= maximum_count:
			push_warning("Ignoring excess affixes on %s" % item.instance_id)
			break
		if not affix_data is Dictionary:
			push_warning("Ignoring malformed affix on %s" % item.instance_id)
			continue
		var affix_id := StringName(String(affix_data.get("affix_id", "")))
		var value_variant: Variant = affix_data.get("value", null)
		var affix_definition := game_content.item_affix(affix_id)
		if affix_definition == null or seen_ids.has(affix_id):
			push_warning("Ignoring unknown or duplicate affix %s on %s" % [affix_id, item.instance_id])
			continue
		if not (value_variant is float or value_variant is int):
			push_warning("Ignoring non-numeric affix %s on %s" % [affix_id, item.instance_id])
			continue
		var value := float(value_variant)
		if not is_finite(value) or not affix_definition.supports(definition, item.item_level):
			push_warning("Ignoring incompatible or non-finite affix %s on %s" % [affix_id, item.instance_id])
			continue
		if not affix_definition.exclusive_group.is_empty() and seen_groups.has(affix_definition.exclusive_group):
			push_warning("Ignoring repeated affix group %s on %s" % [affix_definition.exclusive_group, item.instance_id])
			continue
		var roll := ItemAffixRoll.new()
		roll.affix_id = affix_id
		roll.value = value
		item.affixes.append(roll)
		seen_ids[affix_id] = true
		if not affix_definition.exclusive_group.is_empty():
			seen_groups[affix_definition.exclusive_group] = true

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
			var added := item if index == 0 else item.duplicate_instance()
			if index > 0:
				added.instance_id = ItemInstance.generate_instance_id()
			added.quantity = 1
			_items.append(added)
			item_added.emit(added.instance_id)
	else:
		_add_stackable(item, definition)
	_emit_inventory_changed()
	return true

## Victory transfer keeps the exact loot instance even for stackable items.
func add_item_preserving_identity(item: ItemInstance) -> bool:
	if not can_add_preserving_identity(item):
		return false
	_items.append(item)
	item_added.emit(item.instance_id)
	_emit_inventory_changed()
	return true

func can_add_preserving_identity(item: ItemInstance) -> bool:
	return (
		item != null
		and game_content != null
		and not item.instance_id.is_empty()
		and item.quantity > 0
		and game_content.item(item.definition_id) != null
		and _find_permanent_item(item.instance_id) == null
		and _items.size() < CAPACITY
	)

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
		stack.item_level = item.item_level
		stack.generated_seed = item.generated_seed
		_items.append(stack)
		item_added.emit(stack.instance_id)
		remaining -= stack_quantity

func _can_stack(first: ItemInstance, second: ItemInstance, definition: ItemDefinition) -> bool:
	return (
		definition.stackable
		and first.definition_id == second.definition_id
		and first.rarity == second.rarity
		and first.item_level == second.item_level
		and first.quantity < definition.max_stack
		and JSON.stringify(first.to_dict().get("affixes", [])) == JSON.stringify(second.to_dict().get("affixes", []))
	)

func add_item_by_definition(definition_id: StringName, quantity := 1) -> bool:
	if quantity <= 0 or game_content == null:
		return false
	var definition := game_content.item(definition_id)
	if definition == null:
		return false
	var item := item_factory.create_fixed_item(definition_id, quantity)
	return add_item(item) if item != null else false

func remove_item(instance_id: String, quantity := 1) -> bool:
	if quantity <= 0:
		return false
	var item := _find_permanent_item(instance_id)
	if item == null and _run_inventory != null:
		return _run_inventory.remove_item(instance_id, quantity)
	if item == null or quantity > item.quantity:
		return false
	if quantity == item.quantity and _is_instance_equipped(instance_id):
		return false
	item.quantity -= quantity
	if item.quantity <= 0:
		_items.erase(item)
		item_removed.emit(instance_id)
	_emit_inventory_changed()
	return true

func find_item(instance_id: String) -> ItemInstance:
	var permanent_item := _find_permanent_item(instance_id)
	if permanent_item != null:
		return permanent_item
	return _run_inventory.find_item(instance_id) if _run_inventory != null else null

func _find_permanent_item(instance_id: String) -> ItemInstance:
	for item in _items:
		if item.instance_id == instance_id:
			return item
	return null

func permanent_item(instance_id: String) -> ItemInstance:
	return _find_permanent_item(instance_id)

func is_run_item(instance_id: String) -> bool:
	return _run_inventory != null and _run_inventory.has_item(instance_id)

func get_items() -> Array[ItemInstance]:
	var result := _items.duplicate()
	if _run_inventory != null:
		result.append_array(_run_inventory.get_items())
	return result

func get_items_by_type(item_type: ItemEnums.ItemType) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item in get_items():
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
		var key := String.num_int64(slot)
		var instance_id := String(_equipped_items[slot])
		if _find_permanent_item(instance_id) == null:
			var starting_id := String(_starting_permanent_equipment.get(key, ""))
			instance_id = starting_id if _find_permanent_item(starting_id) != null else ""
		result[key] = instance_id
	return result

func runtime_equipment_snapshot() -> Dictionary:
	return _equipped_items.duplicate(true)

func restore_runtime_equipment(snapshot: Dictionary) -> void:
	_reset_equipment()
	for slot_key in snapshot:
		var slot := int(slot_key)
		var instance_id := String(snapshot[slot_key])
		if _equipped_items.has(slot) and (instance_id.is_empty() or find_item(instance_id) != null):
			_equipped_items[slot] = instance_id
	equipment_changed.emit()

func inventory_size() -> int:
	return _items.size() + (_run_inventory.item_count() if _run_inventory != null else 0)

func permanent_inventory_size() -> int:
	return _items.size()

func run_inventory_size() -> int:
	return _run_inventory.item_count() if _run_inventory != null else 0

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
	detach_run_inventory()
	_items.clear()
	_reset_equipment()
	reset_consumable_runtime()
	_transaction_depth = 0
	_inventory_change_pending = false
