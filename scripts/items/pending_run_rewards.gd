class_name PendingRunRewards
extends RefCounted

signal rewards_changed

var game_content: GameContent
var inventory: InventoryService
var profile: PlayerProfile
var _save_callback: Callable
var _items: Array[ItemInstance] = []

func configure(content: GameContent, permanent_inventory: InventoryService, player_profile: PlayerProfile, saved_items: Array, save_callback := Callable()) -> void:
	game_content = content
	inventory = permanent_inventory
	profile = player_profile
	_save_callback = save_callback
	_items.clear()
	var factory := ItemFactory.new()
	factory.configure(content)
	for saved_item in saved_items:
		if not saved_item is Dictionary:
			continue
		var item := ItemInstance.from_dict(saved_item)
		if item != null and factory.validate_item_instance(item) and find_item(item.instance_id) == null:
			_items.append(item)

func add_item(item: ItemInstance) -> bool:
	if item == null or item.instance_id.is_empty() or game_content.item(item.definition_id) == null or find_item(item.instance_id) != null:
		return false
	_items.append(item)
	rewards_changed.emit()
	return true

func find_item(instance_id: String) -> ItemInstance:
	for item in _items:
		if item.instance_id == instance_id:
			return item
	return null

func get_items() -> Array[ItemInstance]:
	return _items.duplicate()

func serialized_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _items:
		result.append(item.to_dict())
	return result

func claim_item(instance_id: String) -> bool:
	var item := find_item(instance_id)
	if item == null or not inventory.can_add_preserving_identity(item):
		return false
	_items.erase(item)
	if not inventory.add_item_preserving_identity(item):
		_items.append(item)
		return false
	_save()
	rewards_changed.emit()
	return true

func sell_item(instance_id: String) -> bool:
	var item := find_item(instance_id)
	var definition := game_content.item(item.definition_id) if item != null else null
	if definition == null or not definition.can_sell:
		return false
	var value := definition.resolved_item_sell_price(item) * item.quantity
	if value <= 0:
		return false
	_items.erase(item)
	profile.grant_gold(value)
	_save()
	rewards_changed.emit()
	return true

func discard_item(instance_id: String) -> bool:
	var item := find_item(instance_id)
	if item == null:
		return false
	_items.erase(item)
	_save()
	rewards_changed.emit()
	return true

func _save() -> void:
	if _save_callback.is_valid():
		_save_callback.call()
