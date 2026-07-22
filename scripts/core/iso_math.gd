class_name IsoMath
extends RefCounted

const X_SCALE := 1.18
const Y_SCALE := 0.56

static func world_to_screen(world_position: Vector2) -> Vector2:
	return Vector2(
		(world_position.x - world_position.y) * X_SCALE,
		(world_position.x + world_position.y) * Y_SCALE
	)

static func screen_to_world(screen_position: Vector2) -> Vector2:
	var horizontal := screen_position.x / X_SCALE
	var vertical := screen_position.y / Y_SCALE
	return Vector2(
		(horizontal + vertical) * 0.5,
		(vertical - horizontal) * 0.5
	)

static func world_direction_from_screen(screen_direction: Vector2) -> Vector2:
	var world_direction := screen_to_world(screen_direction)
	return world_direction.normalized() if world_direction.length_squared() > 0.0 else Vector2.RIGHT

static func screen_angle(world_direction: Vector2) -> float:
	return world_to_screen(world_direction.normalized()).angle()

