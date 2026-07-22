extends SceneTree

const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
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


func _make_enemy(player: PlayerHero, state: WorldState, position_value: Vector2) -> EnemyBase:
	var enemy := ENEMY_SCENE.instantiate() as EnemyBase
	enemy.setup(player, position_value, 1.0, CONFIG, CONTENT.enemy(GameIds.ENEMY_BRAWLER))
	root.add_child(enemy)
	enemy.set_physics_process(false)
	state.register_enemy(enemy)
	return enemy


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.world_position = Vector2.ZERO
	player.aim_direction = Vector2.RIGHT
	player.attack.swing_aim_direction = Vector2.RIGHT

	var state := WorldState.new()
	state.configure(CONFIG)
	root.add_child(state)
	player.set_combat_registry(state)

	var target_distance := 72.0
	var start_enemy := _make_enemy(player, state, Vector2.from_angle(PlayerAttack.SWEEP_START) * target_distance)
	var middle_enemy := _make_enemy(player, state, Vector2.RIGHT * target_distance)
	var end_enemy := _make_enemy(player, state, Vector2.from_angle(PlayerAttack.SWEEP_END) * target_distance)
	var behind_enemy := _make_enemy(player, state, Vector2.LEFT * target_distance)
	var outside_enemy := _make_enemy(player, state, Vector2.RIGHT * (player.attack.attack_reach + 40.0))
	var initial_health := start_enemy.health
	player.attack.hit_targets.clear()
	player.attack._hit_groups_between(PlayerAttack.SWEEP_START, PlayerAttack.SWEEP_END)
	_require(start_enemy.health < initial_health, "Enemy at the start of the arc was not hit")
	_require(middle_enemy.health < initial_health, "Enemy in the middle of the arc was not hit")
	_require(end_enemy.health < initial_health, "Enemy at the end of the arc was not hit")
	_require(is_equal_approx(behind_enemy.health, initial_health), "Enemy behind the player was hit")
	_require(is_equal_approx(outside_enemy.health, initial_health), "Enemy outside attack reach was hit")

	var health_after_first_hit := middle_enemy.health
	player.attack._hit_groups_between(PlayerAttack.SWEEP_START, PlayerAttack.SWEEP_END)
	_require(is_equal_approx(middle_enemy.health, health_after_first_hit), "One enemy was hit more than once in one swing")
	_require(start_enemy.health < initial_health and end_enemy.health < initial_health, "One swing did not hit two different enemies")

	var projectile := EnemyProjectile.new()
	projectile.setup(player, Vector2.RIGHT * target_distance, Vector2.UP, 0.0)
	state.register_enemy_projectile(projectile)
	root.add_child(projectile)
	projectile.set_physics_process(false)
	player.attack.hit_targets.clear()
	player.attack._hit_groups_between(-0.1, 0.1)
	_require(projectile.is_queued_for_deletion(), "Sword did not destroy or deflect a projectile")

	var prop_definition := PropDefinition.new()
	prop_definition.id = &"attack_test_prop"
	prop_definition.destructible = true
	prop_definition.collision_radius = 20.0
	prop_definition.visual_radius = 20.0
	prop_definition.potion_chance = 0.0
	var prop := WorldProp.new()
	prop.setup(prop_definition, Vector2.RIGHT * target_distance)
	root.add_child(prop)
	state.register_world_prop(prop)
	player.attack.hit_targets.clear()
	player.attack._hit_groups_between(-0.1, 0.1)
	_require(prop.is_queued_for_deletion(), "Destructible did not receive a sword hit")

	var fps_results: Array[bool] = []
	for physics_fps in [30, 60, 120]:
		var segment_count := maxi(1, ceili(player.attack.swing_duration * physics_fps))
		var hit := false
		for segment in segment_count:
			var from_offset := lerpf(PlayerAttack.SWEEP_START, PlayerAttack.SWEEP_END, float(segment) / float(segment_count))
			var to_offset := lerpf(PlayerAttack.SWEEP_START, PlayerAttack.SWEEP_END, float(segment + 1) / float(segment_count))
			if player.attack.point_in_blade_sweep(Vector2.RIGHT * target_distance, 5.0, from_offset, to_offset):
				hit = true
		fps_results.append(hit)
	_require(fps_results.all(func(hit: bool) -> bool: return hit), "Sword hit depended on physics FPS")

	print("PLAYER ATTACK PASS")
	quit()
