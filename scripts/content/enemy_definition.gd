class_name EnemyDefinition
extends Resource

@export var id: StringName
@export var scene: PackedScene
@export var visual_definition: CharacterVisualDefinition
@export var visual_radius := 24.0
@export var collision_radius := 24.0
@export var max_health := 70.0
@export var move_speed := 72.0
@export var contact_damage := 12.0
@export var experience_value := 18
@export var spawn_distance := 620.0
@export var is_boss := false
