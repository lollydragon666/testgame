class_name ItemAffixRoll
extends RefCounted

var affix_id: StringName
var stat: ItemEnums.ItemStatType = ItemEnums.ItemStatType.DAMAGE_FLAT
var value := 0.0
var is_percentage := false

func to_dict() -> Dictionary:
	return {"affix_id": String(affix_id), "stat": stat, "value": value, "is_percentage": is_percentage}

static func from_dict(data: Dictionary) -> ItemAffixRoll:
	var roll := ItemAffixRoll.new()
	roll.affix_id = StringName(String(data.get("affix_id", "")))
	roll.stat = clampi(int(data.get("stat", ItemEnums.ItemStatType.DAMAGE_FLAT)), ItemEnums.ItemStatType.DAMAGE_FLAT, ItemEnums.ItemStatType.LOOT_CHANCE) as ItemEnums.ItemStatType
	roll.value = float(data.get("value", 0.0))
	roll.is_percentage = bool(data.get("is_percentage", false))
	return roll
