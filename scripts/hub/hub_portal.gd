class_name HubPortal
extends Node2D

signal expedition_requested(location_id: StringName)

@export var location_id: StringName = &"test_location"
@export var interaction_radius := 105.0

var player: Node2D

func configure(hub_player: Node2D) -> void:
	player = hub_player

func _process(_delta: float) -> void:
	if is_player_near() and Input.is_action_just_pressed("interact"):
		expedition_requested.emit(location_id)

func is_player_near() -> bool:
	return player != null and player.position.distance_to(position) <= interaction_radius
