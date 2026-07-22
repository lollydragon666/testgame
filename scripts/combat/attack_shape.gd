class_name AttackShape
extends RefCounted

var origin := Vector2.ZERO
var forward := Vector2.RIGHT
var inner_radius := 0.0
var outer_radius := 1.0
var half_width := 0.0

func configure(shape_origin: Vector2, shape_forward: Vector2, shape_inner_radius: float, shape_outer_radius: float, shape_half_width: float) -> void:
	origin = shape_origin
	forward = shape_forward.normalized() if not shape_forward.is_zero_approx() else Vector2.RIGHT
	inner_radius = maxf(0.0, shape_inner_radius)
	outer_radius = maxf(inner_radius, shape_outer_radius)
	half_width = maxf(0.0, shape_half_width)

## Чистая world-space проверка swept-сектора против круглой цели.
func intersects_swept_circle(target_position: Vector2, target_collision_radius: float, from_offset: float, to_offset: float) -> bool:
	var relative := target_position - origin
	var distance := relative.length()
	var padded_radius := maxf(0.0, target_collision_radius) + half_width
	if distance + padded_radius < inner_radius:
		return false
	if distance - padded_radius > outer_radius:
		return false
	if distance <= 0.0001:
		return inner_radius <= padded_radius
	var target_angle := relative.angle()
	var forward_angle := forward.angle()
	var angle_from_forward := wrapf(target_angle - forward_angle, -PI, PI)
	var angular_padding := asin(minf(1.0, padded_radius / distance))
	var minimum_offset := minf(from_offset, to_offset) - angular_padding
	var maximum_offset := maxf(from_offset, to_offset) + angular_padding
	return angle_from_forward >= minimum_offset and angle_from_forward <= maximum_offset
