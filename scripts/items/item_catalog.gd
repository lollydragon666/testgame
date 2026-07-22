class_name ItemCatalog
extends Resource

@export var definitions: Array[ItemDefinition] = []

func definition(id: StringName) -> ItemDefinition:
	for item in definitions:
		if item != null and item.id == id:
			return item
	return null

func definitions_by_type(item_type: ItemEnums.ItemType) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in definitions:
		if item != null and item.item_type == item_type:
			result.append(item)
	return result
