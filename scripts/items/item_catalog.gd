class_name ItemCatalog
extends Resource

@export var definitions: Array[ItemDefinition] = []
@export var additional_catalogs: Array[Resource] = []

func definition(id: StringName) -> ItemDefinition:
	for item in definitions:
		if item != null and item.id == id:
			return item
	for catalog_resource in additional_catalogs:
		var catalog := catalog_resource as ItemCatalog
		if catalog != null:
			var found := catalog.definition(id)
			if found != null:
				return found
	return null

func all_definitions() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = definitions.duplicate()
	for catalog_resource in additional_catalogs:
		var catalog := catalog_resource as ItemCatalog
		if catalog != null:
			result.append_array(catalog.all_definitions())
	return result

func definitions_by_type(item_type: ItemEnums.ItemType) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in all_definitions():
		if item != null and item.item_type == item_type:
			result.append(item)
	return result
