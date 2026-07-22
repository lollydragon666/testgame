class_name ItemAffixCatalog
extends Resource

@export var definitions: Array[ItemAffixDefinition] = []

func definition(id: StringName) -> ItemAffixDefinition:
	for affix in definitions:
		if affix != null and affix.id == id:
			return affix
	return null

func compatible(item_type: ItemEnums.ItemType) -> Array[ItemAffixDefinition]:
	var result: Array[ItemAffixDefinition] = []
	for affix in definitions:
		if affix != null and affix.weight > 0.0 and affix.supports(item_type):
			result.append(affix)
	return result
