extends SceneTree

const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	_require(is_equal_approx(PlayerHero.DASH_DISTANCE, 165.0), "Dash distance changed from 165")
	_require(is_equal_approx(PlayerHero.DASH_COOLDOWN, 1.1), "Dash cooldown changed from 1.1")
	_require(is_equal_approx(PlayerHero.DASH_DURATION, 0.16), "Dash duration changed from 0.16")
	_require(is_equal_approx(PlayerHero.DASH_INVULNERABILITY, 0.18), "Dash invulnerability changed from 0.18")
	_require(InputMap.has_action("dash"), "Dash Input Map action is missing")
	var has_space := false
	for event in InputMap.action_get_events("dash"):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_SPACE:
			has_space = true
	_require(has_space, "Dash action is not bound to Space")

	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var state := WorldState.new()
	state.configure(CONFIG)
	root.add_child(state)
	player.set_combat_registry(state)

	player.aim_direction = Vector2.RIGHT
	_require(player.try_start_dash(), "Ready dash did not start")
	var fixed_direction := player.dash_direction
	player.aim_direction = Vector2.UP
	player._step_dash(PlayerHero.DASH_DURATION)
	_require(is_equal_approx(player.world_position.x, PlayerHero.DASH_DISTANCE), "Dash did not cover its configured distance")
	_require(is_equal_approx(player.world_position.y, 0.0), "Dash direction changed after start")
	_require(fixed_direction == Vector2.RIGHT, "Dash did not use aim_direction without movement input")
	_require(not player.try_start_dash(), "Cooldown allowed an immediate second dash")

	player.reset_run()
	_require(is_equal_approx(player.dash_cooldown_remaining, 0.0) and not player.is_dashing, "reset_run did not reset dash state")
	var expected_movement_direction := IsoMath.world_direction_from_screen(Vector2.UP)
	_require(player.try_start_dash(Vector2.UP), "Movement-directed dash did not start")
	_require(player.dash_direction.is_equal_approx(expected_movement_direction), "Held movement did not override aim direction")
	player._finish_dash()

	player.reset_run()
	var obstacle_definition := PropDefinition.new()
	obstacle_definition.id = &"dash_test_obstacle"
	obstacle_definition.collision_radius = 30.0
	obstacle_definition.visual_radius = 30.0
	obstacle_definition.destructible = false
	var obstacle := WorldProp.new()
	obstacle.setup(obstacle_definition, Vector2(80.0, 0.0))
	root.add_child(obstacle)
	state.register_world_prop(obstacle)
	player.aim_direction = Vector2.RIGHT
	_require(player.try_start_dash(), "Obstacle test dash did not start")
	player._step_dash(PlayerHero.DASH_DURATION)
	_require(player.world_position.x < obstacle.world_position.x, "Dash crossed an obstacle")
	_require(player.world_position.distance_to(obstacle.world_position) >= player.collision_radius + obstacle.collision_radius - 0.01, "Dash ended inside an obstacle")

	player.reset_run()
	player.world_position = Vector2(CONFIG.world_limit - 40.0, 0.0)
	player.aim_direction = Vector2.RIGHT
	_require(player.try_start_dash(), "Boundary test dash did not start")
	player._step_dash(PlayerHero.DASH_DURATION)
	_require(player.world_position.x <= CONFIG.world_limit, "Dash moved the player beyond world_limit")

	player.reset_run()
	player.aim_direction = Vector2.RIGHT
	var health_before := player.health
	_require(player.try_start_dash(), "Invulnerability test dash did not start")
	player.take_damage(50.0)
	_require(is_equal_approx(player.health, health_before), "Player took damage during dash invulnerability")
	player.set_gameplay_active(false)
	_require(not player.is_dashing, "Dash continued after gameplay was disabled")

	print("PLAYER DASH PASS")
	quit()
