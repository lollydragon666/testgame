extends SceneTree

const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/brawler_enemy.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _make_enemy(player: PlayerHero, position_value: Vector2) -> EnemyBase:
	var enemy := ENEMY_SCENE.instantiate() as EnemyBase
	enemy.setup(player, position_value, 1.0, CONFIG, CONTENT.enemy(GameIds.ENEMY_BRAWLER))
	root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func _run() -> void:
	var grid := SpatialGrid.new()
	grid.configure(100.0)
	var near_object := Node.new()
	var adjacent_object := Node.new()
	var far_object := Node.new()
	root.add_child(near_object)
	root.add_child(adjacent_object)
	root.add_child(far_object)
	grid.insert(near_object, Vector2(10.0, 10.0))
	grid.insert(adjacent_object, Vector2(110.0, 10.0))
	grid.insert(far_object, Vector2(510.0, 10.0))
	_require(grid.cell_count() == 3, "SpatialGrid did not insert objects into their expected cells")
	_require(grid.query(Vector2(50.0, 10.0), 100.0).size() == 2, "SpatialGrid queried cells outside the local neighborhood")
	grid.update(far_object, Vector2(20.0, 10.0))
	_require(grid.query(Vector2(50.0, 10.0), 60.0).has(far_object), "SpatialGrid did not move an object to its new cell")
	_require(grid.cell_count() == 2, "SpatialGrid retained the empty cell after movement")
	grid.remove(adjacent_object)
	_require(not grid.query(Vector2(110.0, 10.0), 1.0).has(adjacent_object), "SpatialGrid did not remove an object")
	grid.insert(adjacent_object, Vector2(110.0, 10.0))

	var query_result := grid.query(Vector2(50.0, 10.0), 100.0)
	var buffer_sentinel := Node.new()
	root.add_child(buffer_sentinel)
	var query_buffer: Array[Object] = [buffer_sentinel]
	grid.query_into(Vector2(50.0, 10.0), 100.0, query_buffer)
	_require(query_buffer.size() == query_result.size(), "query_into did not clear its caller-owned buffer")
	for object in query_result:
		_require(query_buffer.has(object), "query() and query_into() returned different objects")
	var unique_ids: Dictionary[int, bool] = {}
	for object in query_buffer:
		unique_ids[object.get_instance_id()] = true
	_require(unique_ids.size() == query_buffer.size(), "SpatialGrid returned one object more than once")

	var invalid_object := Node.new()
	grid.insert(invalid_object, Vector2(20.0, 20.0))
	invalid_object.free()
	grid.query_into(Vector2(20.0, 20.0), 1.0, query_buffer)
	for object in query_buffer:
		_require(is_instance_valid(object), "SpatialGrid returned an invalid object")

	var negative_object := Node.new()
	var left_boundary_object := Node.new()
	var right_boundary_object := Node.new()
	root.add_child(negative_object)
	root.add_child(left_boundary_object)
	root.add_child(right_boundary_object)
	grid.insert(negative_object, Vector2(-1.0, -1.0))
	grid.insert(left_boundary_object, Vector2(99.9, 0.0))
	grid.insert(right_boundary_object, Vector2(100.0, 0.0))
	_require(grid.query(Vector2(-1.0, -1.0), 0.0).has(negative_object), "SpatialGrid failed on negative coordinates")
	var boundary_result := grid.query(Vector2(100.0, 0.0), 1.0)
	_require(boundary_result.has(left_boundary_object) and boundary_result.has(right_boundary_object), "SpatialGrid failed across a cell boundary")

	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var state := WorldState.new()
	state.configure(CONFIG)
	root.add_child(state)
	var enemy_a := _make_enemy(player, Vector2(300.0, 0.0))
	var enemy_b := _make_enemy(player, Vector2(325.0, 0.0))
	var enemy_far := _make_enemy(player, Vector2(900.0, 0.0))
	state.register_enemy(enemy_a)
	state.register_enemy(enemy_b)
	state.register_enemy(enemy_far)
	_require(state.enemies_near(Vector2(310.0, 0.0), 90.0).size() == 2, "Enemy query included a distant grid cell")
	enemy_far.world_position = Vector2(350.0, 0.0)
	state.update_enemy(enemy_far)
	_require(state.enemies_near(Vector2(310.0, 0.0), 90.0).has(enemy_far), "WorldState did not update a moving enemy cell")
	_require(not state.enemy_separation(enemy_a, CONFIG.enemy_separation_radius).is_zero_approx(), "Overlapping enemies did not produce separation")

	var prop_definition := PropDefinition.new()
	prop_definition.id = &"test_obstacle"
	prop_definition.visual_radius = 40.0
	prop_definition.collision_radius = 40.0
	prop_definition.destructible = false
	var obstacle := WorldProp.new()
	obstacle.setup(prop_definition, Vector2(600.0, 0.0))
	root.add_child(obstacle)
	state.register_world_prop(obstacle)
	_require(state.is_position_blocked(Vector2(600.0, 0.0), 20.0), "Obstacle was not detected through the grid")
	_require(state.resolve_obstacle_motion(Vector2(500.0, 0.0), Vector2(600.0, 0.0), 20.0) == Vector2(500.0, 0.0), "Obstacle did not reject blocked movement")
	_require(not state.is_enemy_spawn_clear(Vector2(600.0, 0.0), 24.0, player.world_position, player.collision_radius, 10.0), "Spawn check accepted an obstacle")
	_require(not state.is_enemy_spawn_clear(enemy_a.world_position, 24.0, player.world_position, player.collision_radius, 10.0), "Spawn check accepted an occupied enemy position")
	_require(state.is_enemy_spawn_clear(Vector2(1500.0, 1500.0), 24.0, player.world_position, player.collision_radius, 10.0), "Spawn check rejected a free position")

	var limit_config := WorldConfig.new()
	limit_config.max_enemy_projectiles = 2
	limit_config.max_player_projectiles = 1
	limit_config.max_pickups = 2
	var limit_state := WorldState.new()
	limit_state.configure(limit_config)
	root.add_child(limit_state)
	for _index in 2:
		var enemy_projectile := DeflectableProjectile.new()
		limit_state.register_enemy_projectile(enemy_projectile)
		root.add_child(enemy_projectile)
		var pickup := GamePickup.new()
		limit_state.register_pickup(pickup)
		root.add_child(pickup)
	var player_projectile := PlayerMagicProjectile.new()
	limit_state.register_player_projectile(player_projectile)
	root.add_child(player_projectile)
	_require(not limit_state.can_spawn_enemy_projectile(limit_config), "Enemy projectile limit was not enforced")
	_require(not limit_state.can_spawn_player_projectile(limit_config), "Player projectile limit was not enforced")
	_require(not limit_state.can_spawn_pickup(limit_config), "Pickup limit was not enforced")

	print("SPATIAL INDEX PASS")
	quit()
