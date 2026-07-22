class_name RunInventoryService
extends RefCounted

signal run_item_added(instance_id: String)
signal run_item_removed(instance_id: String)
signal run_inventory_changed

const CAPACITY := 40

var game_content: GameContent
var _items: Array[ItemInstance] = []

func configure(content: GameContent) -> void:
	game_content = content
	clear()

## Stores the exact instance created by the loot roll. Run loot is never stacked
## into a different ItemInstance, so identity and randomized properties stay stable.
func add_item(item: ItemInstance) -> bool:
	if not can_add_item(item):
		return false
	_items.append(item)
	run_item_added.emit(item.instance_id)
	run_inventory_changed.emit()
	return true

func can_add_item(item: ItemInstance) -> bool:
	return (
		item != null
		and game_content != null
		and not item.instance_id.is_empty()
		and item.quantity > 0
		and game_content.item(item.definition_id) != null
		and find_item(item.instance_id) == null
		and _items.size() < CAPACITY
	)

func remove_item(instance_id: String, quantity := 1) -> bool:
	if quantity <= 0:
		return false
	var item := find_item(instance_id)
	if item == null or quantity > item.quantity:
		return false
	item.quantity -= quantity
	if item.quantity <= 0:
		_items.erase(item)
		run_item_removed.emit(instance_id)
	run_inventory_changed.emit()
	return true

func find_item(instance_id: String) -> ItemInstance:
	for item in _items:
		if item.instance_id == instance_id:
			return item
	return null

func has_item(instance_id: String) -> bool:
	return find_item(instance_id) != null

func get_items() -> Array[ItemInstance]:
	return _items.duplicate()

func item_count() -> int:
	return _items.size()

func clear() -> void:
	if _items.is_empty():
		return
	_items.clear()
	run_inventory_changed.emit()

