class_name ShopDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export var stock_definition_ids: Array[StringName] = []

func sells(definition_id: StringName) -> bool:
	return stock_definition_ids.has(definition_id)

