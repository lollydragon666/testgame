class_name EnemyTargetingController
extends RefCounted

var host: EnemyBase

func configure(enemy: EnemyBase) -> void:
	host = enemy

func offset_to_player() -> Vector2:
	return host.player.world_position - host.world_position if host != null and host.player != null else Vector2.ZERO

func distance_to_player() -> float:
	return offset_to_player().length()

func direction_to_player() -> Vector2:
	var offset := offset_to_player()
	return offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT

func has_line_of_sight(max_distance := INF) -> bool:
	if host == null or host.player == null:
		return false
	var segment := offset_to_player()
	var distance := segment.length()
	if distance > max_distance:
		return false
	if host.world_state == null or distance <= 0.001:
		return true
	var direction := segment / distance
	var midpoint := host.world_position + segment * 0.5
	for obstacle in host.world_state.obstacles_near(midpoint, distance * 0.5 + 96.0):
		var relative := obstacle.world_position - host.world_position
		var along := clampf(relative.dot(direction), 0.0, distance)
		var closest := host.world_position + direction * along
		if obstacle.world_position.distance_to(closest) < obstacle.collision_radius + 4.0:
			return false
	return true
