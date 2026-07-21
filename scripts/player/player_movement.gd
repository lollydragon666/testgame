class_name PlayerMovement
extends Node

## Максимальная скорость героя в мировых координатах за секунду.
@export var speed := 195.0
## Насколько быстро герой набирает скорость после нажатия WASD.
@export var acceleration := 1250.0
## Насколько быстро герой останавливается после отпускания WASD.
@export var deceleration := 1550.0

## Сохраняется между кадрами, чтобы движение было плавным, а не рывками.
var velocity := Vector2.ZERO

func step(delta: float, current_position: Vector2, world_limit: float) -> Vector2:
	# WASD задаёт экранное направление, затем оно переводится в оси изометрического мира.
	var screen_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var world_input := Vector2.ZERO
	if screen_input.length_squared() > 0.0:
		world_input = IsoMath.world_direction_from_screen(screen_input)
	var desired_velocity := world_input * speed
	var rate := acceleration if world_input.length_squared() > 0.0 else deceleration
	velocity = velocity.move_toward(desired_velocity, rate * delta)
	var next_position := current_position + velocity * delta
	return next_position.clamp(Vector2.ONE * -world_limit, Vector2.ONE * world_limit)

func reset() -> void:
	velocity = Vector2.ZERO
