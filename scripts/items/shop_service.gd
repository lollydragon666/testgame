class_name ShopService
extends RefCounted

signal currency_changed(current_gold: int)
signal purchase_completed(shop_id: StringName, definition_id: StringName, quantity: int)
signal sale_completed(instance_id: String, quantity: int)
signal notification_requested(message: String)

var game_content: GameContent
var inventory: InventoryService
var profile: PlayerProfile
var item_factory := ItemFactory.new()
var _save_callback: Callable

func configure(
	content: GameContent,
	inventory_service: InventoryService,
	player_profile: PlayerProfile,
	save_callback := Callable()
) -> void:
	game_content = content
	inventory = inventory_service
	profile = player_profile
	item_factory.configure(content)
	_save_callback = save_callback

func can_buy(shop_id: StringName, definition_id: StringName, quantity := 1) -> bool:
	if quantity <= 0 or game_content == null or inventory == null or profile == null:
		return false
	var shop := game_content.shop(shop_id)
	var definition := game_content.item(definition_id)
	if shop == null or definition == null or not shop.sells(definition_id):
		return false
	if definition.base_price <= 0:
		return false
	if not definition.stackable and quantity != 1:
		return false
	var total_price := definition.base_price * quantity
	if profile.gold < total_price:
		return false
	var candidate := item_factory.create_fixed_item(definition_id, quantity)
	return candidate != null and inventory.can_add_item(candidate)

func buy_item(shop_id: StringName, definition_id: StringName, quantity := 1) -> bool:
	if not can_buy(shop_id, definition_id, quantity):
		_notify("Покупка невозможна")
		return false
	var definition := game_content.item(definition_id)
	var total_price := definition.base_price * quantity
	var purchased_item := item_factory.create_fixed_item(definition_id, quantity)
	inventory.begin_transaction()
	if not inventory.add_item(purchased_item):
		inventory.end_transaction()
		_notify("В инвентаре недостаточно места")
		return false
	profile.gold -= total_price
	inventory.end_transaction()
	currency_changed.emit(profile.gold)
	purchase_completed.emit(shop_id, definition_id, quantity)
	_save_profile()
	return true

func can_sell(instance_id: String, quantity := 1) -> bool:
	if quantity <= 0 or game_content == null or inventory == null or profile == null:
		return false
	if inventory.is_run_item(instance_id):
		return false
	var item := inventory.find_item(instance_id)
	if item == null or quantity > item.quantity or inventory.is_equipped(instance_id):
		return false
	var definition := game_content.item(item.definition_id)
	return (
		definition != null
		and definition.can_sell
		and item.definition_id != InventoryService.STARTER_WEAPON_ID
		and definition.resolved_item_sell_price(item) > 0
	)

func sell_item(instance_id: String, quantity := 1) -> bool:
	if inventory != null and inventory.is_run_item(instance_id):
		_notify("Добычу можно продать после успешного завершения забега")
		return false
	if not can_sell(instance_id, quantity):
		_notify("Продажа невозможна")
		return false
	var item := inventory.find_item(instance_id)
	var definition := game_content.item(item.definition_id)
	var total_price := definition.resolved_item_sell_price(item) * quantity
	inventory.begin_transaction()
	if not inventory.remove_item(instance_id, quantity):
		inventory.end_transaction()
		_notify("Предмет не удалось удалить из инвентаря")
		return false
	profile.grant_gold(total_price)
	inventory.end_transaction()
	currency_changed.emit(profile.gold)
	sale_completed.emit(instance_id, quantity)
	_save_profile()
	return true

func _save_profile() -> void:
	if _save_callback.is_valid():
		_save_callback.call()

func _notify(message: String) -> void:
	notification_requested.emit(message)
