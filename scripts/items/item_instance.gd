class_name ItemInstance
extends RefCounted

static var _sequence := 0

var instance_id := ""
var definition_id: StringName
var quantity := 1
var rarity: ItemEnums.ItemRarity = ItemEnums.ItemRarity.COMMON
var item_level := 1
var affixes: Array[ItemAffixRoll] = []
var generated_seed := 0
var saved_parameters: Dictionary = {}

static func create(item_definition_id: StringName, item_quantity := 1, item_rarity: ItemEnums.ItemRarity = ItemEnums.ItemRarity.COMMON) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = generate_instance_id()
	item.definition_id = item_definition_id
	item.quantity = maxi(1, item_quantity)
	item.rarity = item_rarity
	return item

static func generate_instance_id() -> String:
	_sequence += 1
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() == 16:
		bytes[6] = (bytes[6] & 0x0f) | 0x40
		bytes[8] = (bytes[8] & 0x3f) | 0x80
		var hexadecimal := ""
		for value in bytes:
			hexadecimal += "%02x" % value
		return "item-%s-%s-%s-%s-%s" % [
			hexadecimal.substr(0, 8),
			hexadecimal.substr(8, 4),
			hexadecimal.substr(12, 4),
			hexadecimal.substr(16, 4),
			hexadecimal.substr(20, 12),
		]
	return "item-%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), _sequence]

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
		"item_level": item_level,
		"generated_seed": generated_seed,
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
	item.rarity = int(data.get("rarity", ItemEnums.ItemRarity.COMMON)) as ItemEnums.ItemRarity
	item.item_level = int(data.get("item_level", 1))
	item.generated_seed = int(data.get("generated_seed", 0))
	for affix_data in data.get("affixes", []):
		if affix_data is Dictionary:
			item.affixes.append(ItemAffixRoll.from_dict(affix_data))
	var parameters: Variant = data.get("saved_parameters", {})
	item.saved_parameters = parameters.duplicate(true) if parameters is Dictionary else {}
	return item
