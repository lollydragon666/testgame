class_name EnemyDropController
extends RefCounted

var grants_experience := true
var grants_loot := true
var loot_table_id: StringName = &"normal"

func configure(definition: EnemyDefinition) -> void:
	grants_experience = definition.grants_experience
	grants_loot = definition.grants_loot
	loot_table_id = definition.loot_table_id
