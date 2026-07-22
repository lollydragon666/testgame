class_name WaveDefinition
extends Resource

@export var number := 1
@export var enemy_roster: Array[StringName] = []
@export var spawn_weights: Dictionary[StringName, float] = {}
@export var maximum_alive: Dictionary[StringName, int] = {}
@export var maximum_per_wave: Dictionary[StringName, int] = {}
@export var guaranteed_group_ids: Array[StringName] = []
@export var sequence_group_ids: Array[StringName] = []
@export var duration_override := 0.0
@export var boss_enemy_id: StringName
