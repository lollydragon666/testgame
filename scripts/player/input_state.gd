class_name InputState
extends RefCounted

## Направление WASD в экранных осях, снятое в начале physics tick.
var movement_screen := Vector2.ZERO
## Направление мыши, заранее переведённое в мировые изометрические оси.
var aim_world := Vector2.RIGHT
var attack_pressed := false
var magic_pressed := false
var dash_pressed := false
var quick_slot_2_pressed := false
var quick_slot_3_pressed := false

func sample(player_screen_position: Vector2, mouse_screen_position: Vector2) -> void:
	movement_screen = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var mouse_delta := mouse_screen_position - player_screen_position
	if mouse_delta.length_squared() > 16.0:
		aim_world = IsoMath.world_direction_from_screen(mouse_delta)
	attack_pressed = Input.is_action_just_pressed("attack")
	magic_pressed = Input.is_action_just_pressed("cast_magic")
	dash_pressed = Input.is_action_just_pressed("dash")
	quick_slot_2_pressed = Input.is_action_just_pressed("quick_slot_2")
	quick_slot_3_pressed = Input.is_action_just_pressed("quick_slot_3")

func reset() -> void:
	movement_screen = Vector2.ZERO
	aim_world = Vector2.RIGHT
	attack_pressed = false
	magic_pressed = false
	dash_pressed = false
	quick_slot_2_pressed = false
	quick_slot_3_pressed = false
