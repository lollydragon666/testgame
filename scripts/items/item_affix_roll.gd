class_name ItemAffixRoll
extends RefCounted

var affix_id: StringName
var value := 0.0

func to_dict() -> Dictionary:
	return {"affix_id": String(affix_id), "value": value}

static func from_dict(data: Dictionary) -> ItemAffixRoll:
	var roll := ItemAffixRoll.new()
	roll.affix_id = StringName(String(data.get("affix_id", "")))
	roll.value = float(data.get("value", 0.0))
	return roll
