class_name ItemInstance
extends RefCounted

static var _sequence := 0

var instance_id := ""
var definition_id: StringName
var quantity := 1
var rarity: ItemEnums.ItemRarity = ItemEnums.ItemRarity.COMMON
var item_level := 1
var affixes: Array[ItemAffixRoll] = []
var saved_parameters: Dictionary = {}

static func create(item_definition_id: StringName, item_quantity := 1, item_rarity: ItemEnums.ItemRarity = ItemEnums.ItemRarity.COMMON) -> ItemInstance:
	_sequence += 1
	var item := ItemInstance.new()
	item.instance_id = "item-%d-%d" % [Time.get_ticks_usec(), _sequence]
	item.definition_id = item_definition_id
	item.quantity = maxi(1, item_quantity)
	item.rarity = item_rarity
	return item

func duplicate_instance() -> ItemInstance:
	return from_dict(to_dict())

func to_dict() -> Dictionary:
	var saved_affixes: Array[Dictionary] = []
	for affix in affixes:
		if affix != null:
			saved_affixes.append(affix.to_dict())
	return {
		"instance_id": instance_id,
		"definition_id": String(definition_id),
		"quantity": quantity,
		"rarity": rarity,
		"affixes": saved_affixes,
		"saved_parameters": saved_parameters.duplicate(true),
	}

static func from_dict(data: Dictionary) -> ItemInstance:
	var definition_text := String(data.get("definition_id", ""))
	var saved_id := String(data.get("instance_id", ""))
	var saved_quantity := int(data.get("quantity", 0))
	if definition_text.is_empty() or saved_id.is_empty() or saved_quantity <= 0:
		return null
	var item := ItemInstance.new()
	item.instance_id = saved_id
	item.definition_id = StringName(definition_text)
	item.quantity = saved_quantity
	item.rarity = clampi(int(data.get("rarity", ItemEnums.ItemRarity.COMMON)), ItemEnums.ItemRarity.COMMON, ItemEnums.ItemRarity.LEGENDARY) as ItemEnums.ItemRarity
	for affix_data in data.get("affixes", []):
		if affix_data is Dictionary:
			item.affixes.append(ItemAffixRoll.from_dict(affix_data))
	var parameters: Variant = data.get("saved_parameters", {})
	item.saved_parameters = parameters.duplicate(true) if parameters is Dictionary else {}
	return item
