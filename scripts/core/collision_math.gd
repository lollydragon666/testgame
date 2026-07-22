class_name CollisionMath
extends RefCounted

## Возвращает положение первого пересечения на отрезке в диапазоне 0..1 или -1 при промахе.
static func segment_circle_hit_fraction(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var offset := from - center
	var radius_squared := radius * radius
	if offset.length_squared() <= radius_squared:
		return 0.0
	var segment := to - from
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.000001:
		return -1.0
	var projection := offset.dot(segment)
	var discriminant := projection * projection - segment_length_squared * (offset.length_squared() - radius_squared)
	if discriminant < 0.0:
		return -1.0
	var hit_fraction := (-projection - sqrt(discriminant)) / segment_length_squared
	return hit_fraction if hit_fraction >= 0.0 and hit_fraction <= 1.0 else -1.0
