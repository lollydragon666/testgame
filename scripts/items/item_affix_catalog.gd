class_name ItemAffixCatalog
extends Resource

@export var definitions: Array[ItemAffixDefinition] = []

func definition(id: StringName) -> ItemAffixDefinition:
	for affix in definitions:
		if affix != null and affix.id == id:
			return affix
	return null

func compatible(definition: ItemDefinition, item_level := 1) -> Array[ItemAffixDefinition]:
	var result: Array[ItemAffixDefinition] = []
	for affix in definitions:
		if affix != null and affix.weight > 0.0 and affix.supports(definition, item_level):
			result.append(affix)
	return result

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary[StringName, bool] = {}
	for affix in definitions:
		if affix == null:
			errors.append("Affix catalog contains an empty definition")
			continue
		if affix.id.is_empty():
			errors.append("Affix definition has an empty ID")
		elif seen_ids.has(affix.id):
			errors.append("Duplicate affix ID: %s" % affix.id)
		else:
			seen_ids[affix.id] = true
		if affix.allowed_item_types.is_empty():
			errors.append("Affix %s has no allowed item types" % affix.id)
		if affix.weight <= 0.0:
			errors.append("Affix %s has a non-positive weight" % affix.id)
	return errors
