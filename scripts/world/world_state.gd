class_name WorldState
extends Node

# Изменяемые коллекции закрыты. Внешние системы получают snapshot или локальный grid-query.
var _enemies: Array[EnemyBase] = []
var _enemy_projectiles: Array[DeflectableProjectile] = []
var _player_projectiles: Array[PlayerMagicProjectile] = []
var _pickups: Array[GamePickup] = []
var _destructibles: Array[WorldProp] = []
var _obstacles: Array[WorldProp] = []

var _enemy_grid := SpatialGrid.new()
var _enemy_projectile_grid := SpatialGrid.new()
var _destructible_grid := SpatialGrid.new()
var _obstacle_grid := SpatialGrid.new()

func configure(config: WorldConfig) -> void:
	for grid in [_enemy_grid, _enemy_projectile_grid, _destructible_grid, _obstacle_grid]:
		grid.configure(config.spatial_cell_size)

func register_enemy(enemy: EnemyBase) -> void:
	if _enemies.has(enemy):
		return
	_enemies.append(enemy)
	_enemy_grid.insert(enemy, enemy.world_position)
	enemy.set_world_state(self)
	enemy.tree_exiting.connect(unregister_enemy.bind(enemy), CONNECT_ONE_SHOT)

func update_enemy(enemy: EnemyBase) -> void:
	_enemy_grid.update(enemy, enemy.world_position)

func unregister_enemy(enemy: EnemyBase) -> void:
	_enemies.erase(enemy)
	_enemy_grid.remove(enemy)

func enemy_snapshot() -> Array[EnemyBase]:
	return _enemies.duplicate()

func enemies_near(world_position: Vector2, radius: float) -> Array[EnemyBase]:
	var result: Array[EnemyBase] = []
	for object in _enemy_grid.query(world_position, radius):
		var enemy := object as EnemyBase
		if enemy != null:
			result.append(enemy)
	return result

func register_enemy_projectile(projectile: DeflectableProjectile) -> void:
	if _enemy_projectiles.has(projectile):
		return
	_enemy_projectiles.append(projectile)
	_enemy_projectile_grid.insert(projectile, projectile.world_position)
	projectile.set_world_state(self)
	projectile.tree_exiting.connect(unregister_enemy_projectile.bind(projectile), CONNECT_ONE_SHOT)

func update_enemy_projectile(projectile: DeflectableProjectile) -> void:
	_enemy_projectile_grid.update(projectile, projectile.world_position)

func unregister_enemy_projectile(projectile: DeflectableProjectile) -> void:
	_enemy_projectiles.erase(projectile)
	_enemy_projectile_grid.remove(projectile)

func enemy_projectile_snapshot() -> Array[DeflectableProjectile]:
	return _enemy_projectiles.duplicate()

func player_projectile_snapshot() -> Array[PlayerMagicProjectile]:
	return _player_projectiles.duplicate()

func pickup_snapshot() -> Array[GamePickup]:
	return _pickups.duplicate()

func enemy_projectiles_near(world_position: Vector2, radius: float) -> Array[DeflectableProjectile]:
	var result: Array[DeflectableProjectile] = []
	for object in _enemy_projectile_grid.query(world_position, radius):
		var projectile := object as DeflectableProjectile
		if projectile != null:
			result.append(projectile)
	return result

func register_player_projectile(projectile: PlayerMagicProjectile) -> void:
	if _player_projectiles.has(projectile):
		return
	_player_projectiles.append(projectile)
	projectile.tree_exiting.connect(unregister_player_projectile.bind(projectile), CONNECT_ONE_SHOT)

func unregister_player_projectile(projectile: PlayerMagicProjectile) -> void:
	_player_projectiles.erase(projectile)

func register_pickup(pickup: GamePickup) -> void:
	if _pickups.has(pickup):
		return
	_pickups.append(pickup)
	pickup.tree_exiting.connect(unregister_pickup.bind(pickup), CONNECT_ONE_SHOT)

func unregister_pickup(pickup: GamePickup) -> void:
	_pickups.erase(pickup)

func register_world_prop(prop: WorldProp) -> void:
	if _obstacles.has(prop):
		return
	_obstacles.append(prop)
	_obstacle_grid.insert(prop, prop.world_position)
	if prop.destructible:
		_destructibles.append(prop)
		_destructible_grid.insert(prop, prop.world_position)
	prop.tree_exiting.connect(unregister_world_prop.bind(prop), CONNECT_ONE_SHOT)

func unregister_world_prop(prop: WorldProp) -> void:
	_obstacles.erase(prop)
	_obstacle_grid.remove(prop)
	_destructibles.erase(prop)
	_destructible_grid.remove(prop)

func destructible_snapshot() -> Array[WorldProp]:
	return _destructibles.duplicate()

func destructibles_near(world_position: Vector2, radius: float) -> Array[WorldProp]:
	var result: Array[WorldProp] = []
	for object in _destructible_grid.query(world_position, radius):
		var prop := object as WorldProp
		if prop != null:
			result.append(prop)
	return result

func obstacles_near(world_position: Vector2, radius: float) -> Array[WorldProp]:
	var result: Array[WorldProp] = []
	for object in _obstacle_grid.query(world_position, radius):
		var prop := object as WorldProp
		if prop != null:
			result.append(prop)
	return result

func replace_world_props(props: Array[WorldProp]) -> void:
	_destructibles.clear()
	_obstacles.clear()
	_destructible_grid.clear()
	_obstacle_grid.clear()
	for prop in props:
		if is_instance_valid(prop):
			register_world_prop(prop)

func enemy_separation(enemy: EnemyBase, search_radius: float) -> Vector2:
	var correction := Vector2.ZERO
	for neighbor in enemies_near(enemy.world_position, search_radius):
		if neighbor == enemy or not neighbor.is_alive:
			continue
		var offset := enemy.world_position - neighbor.world_position
		var distance := offset.length()
		var minimum_distance := enemy.collision_radius + neighbor.collision_radius
		if distance >= minimum_distance:
			continue
		if distance <= 0.001:
			var base_direction := Vector2.from_angle(float((enemy.get_instance_id() + neighbor.get_instance_id()) % 628) * 0.01)
			offset = base_direction if enemy.get_instance_id() < neighbor.get_instance_id() else -base_direction
			distance = 1.0
		correction += offset / distance * (1.0 - distance / minimum_distance)
	return correction.normalized() if not correction.is_zero_approx() else Vector2.ZERO

func resolve_obstacle_motion(from_position: Vector2, to_position: Vector2, radius: float) -> Vector2:
	if not is_position_blocked(to_position, radius):
		return to_position
	var slide_x := Vector2(to_position.x, from_position.y)
	if not is_position_blocked(slide_x, radius):
		return slide_x
	var slide_y := Vector2(from_position.x, to_position.y)
	if not is_position_blocked(slide_y, radius):
		return slide_y
	return from_position

func is_position_blocked(world_position: Vector2, radius: float) -> bool:
	for obstacle in obstacles_near(world_position, radius + 64.0):
		if world_position.distance_to(obstacle.world_position) < radius + obstacle.collision_radius:
			return true
	return false

func is_enemy_spawn_clear(world_position: Vector2, radius: float, player_position: Vector2, player_radius: float, clearance: float) -> bool:
	if world_position.distance_to(player_position) < radius + player_radius + clearance:
		return false
	if is_position_blocked(world_position, radius + clearance):
		return false
	for enemy in enemies_near(world_position, radius + clearance + 80.0):
		if enemy.is_alive and world_position.distance_to(enemy.world_position) < radius + enemy.collision_radius + clearance:
			return false
	return true

func clear_enemies() -> void:
	_enemies.clear()
	_enemy_grid.clear()

func clear_projectiles() -> void:
	_enemy_projectiles.clear()
	_player_projectiles.clear()
	_enemy_projectile_grid.clear()

func clear_pickups() -> void:
	_pickups.clear()

func clear_runtime() -> void:
	clear_enemies()
	clear_projectiles()
	clear_pickups()

func enemy_count() -> int:
	return _enemies.size()

func enemy_projectile_count() -> int:
	return _enemy_projectiles.size()

func player_projectile_count() -> int:
	return _player_projectiles.size()

func pickup_count() -> int:
	return _pickups.size()

func spatial_cell_count() -> int:
	return (
		_enemy_grid.cell_count()
		+ _enemy_projectile_grid.cell_count()
		+ _destructible_grid.cell_count()
		+ _obstacle_grid.cell_count()
	)

func can_spawn_enemy_projectile(config: WorldConfig) -> bool:
	return enemy_projectile_count() < config.max_enemy_projectiles

func can_spawn_player_projectile(config: WorldConfig) -> bool:
	return player_projectile_count() < config.max_player_projectiles

func can_spawn_pickup(config: WorldConfig) -> bool:
	return pickup_count() < config.max_pickups
