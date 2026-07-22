extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/brawler_enemy.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _make_enemy(player: PlayerHero, config: WorldConfig, position_value: Vector2) -> EnemyBase:
	var enemy := ENEMY_SCENE.instantiate() as EnemyBase
	enemy.setup(player, position_value, 1.0, config, CONTENT.enemy(GameIds.ENEMY_BRAWLER))
	root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _run() -> void:
	var config := WorldConfig.new()
	config.enemy_separation_radius = 76.0
	config.enemy_separation_update_divisor = 2
	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(config)
	player.configure_content(CONTENT)
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	var state := WorldState.new()
	state.configure(config)
	root.add_child(state)
	var enemy_a := _make_enemy(player, config, Vector2(300.0, 0.0))
	var enemy_b := _make_enemy(player, config, Vector2(325.0, 0.0))
	var enemy_far := _make_enemy(player, config, Vector2(900.0, 0.0))
	state.register_enemy(enemy_a)
	state.register_enemy(enemy_b)
	state.register_enemy(enemy_far)

	_require(state.enemy_separation(enemy_a, config.enemy_separation_radius).length() > 0.0, "Overlapping enemies did not receive separation")
	_require(state.enemy_separation(enemy_far, config.enemy_separation_radius).is_zero_approx(), "Distant enemies received separation")

	enemy_b.world_position = enemy_a.world_position
	state.update_enemy(enemy_b)
	var first_same_position := state.enemy_separation(enemy_a, config.enemy_separation_radius)
	var second_same_position := state.enemy_separation(enemy_a, config.enemy_separation_radius)
	_require(first_same_position.is_finite() and not first_same_position.is_zero_approx(), "Same-position separation produced zero or NaN")
	_require(first_same_position.is_equal_approx(second_same_position), "Same-position separation direction was not stable")

	var phase := enemy_a.separation_update_phase()
	enemy_a.update_separation_cache_for_frame(phase)
	_require(not enemy_a.cached_separation().is_zero_approx(), "Separation cache did not update on its phase")
	enemy_b.world_position = Vector2(1200.0, 0.0)
	state.update_enemy(enemy_b)
	enemy_a.update_separation_cache_for_frame(phase + 1)
	_require(not enemy_a.cached_separation().is_zero_approx(), "Separation cache changed outside its phase")
	enemy_a.update_separation_cache_for_frame(phase + config.enemy_separation_update_divisor)
	_require(enemy_a.cached_separation().is_zero_approx(), "Separation cache did not refresh on the next phase")

	var phases: Dictionary[int, bool] = {}
	for index in 16:
		var phased_enemy := _make_enemy(player, config, Vector2(1500.0 + index * 60.0, 0.0))
		phases[phased_enemy.separation_update_phase()] = true
	_require(phases.size() == config.enemy_separation_update_divisor, "Enemies were not distributed across separation phases")

	enemy_a.world_position = Vector2(300.0, 0.0)
	enemy_b.world_position = Vector2(325.0, 0.0)
	state.update_enemy(enemy_a)
	state.update_enemy(enemy_b)
	enemy_a.update_separation_cache_for_frame(enemy_a.separation_update_phase())
	_require(not enemy_a.cached_separation().is_zero_approx(), "Separation cache setup failed before reset")
	enemy_a.reset_separation_cache()
	_require(enemy_a.cached_separation().is_zero_approx(), "Reset retained stale separation correction")

	print("ENEMY SEPARATION PASS")
	quit()
