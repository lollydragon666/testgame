extends SceneTree

const CONFIG: WorldConfig = preload("res://resources/world_config.tres")
const CONTENT: GameContent = preload("res://resources/game_content.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MELEE_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerHero
	player.configure_world(CONFIG)
	player.configure_content(CONTENT)
	root.add_child(player)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.world_position = Vector2(150.0, 0.0)

	var health_before_arrow := player.health
	var arrow := EnemyProjectile.new()
	arrow.setup(player, Vector2.ZERO, Vector2.RIGHT, 12.0)
	root.add_child(arrow)
	arrow.set_physics_process(false)
	arrow._physics_process(1.0)
	_require(player.health < health_before_arrow, "Swept enemy projectile skipped the player")

	var state := WorldState.new()
	root.add_child(state)
	var near_enemy := MELEE_SCENE.instantiate() as MeleeEnemy
	near_enemy.setup(player, Vector2(120.0, 0.0), 1.0, CONFIG)
	root.add_child(near_enemy)
	near_enemy.set_physics_process(false)
	state.register_enemy(near_enemy)
	var far_enemy := MELEE_SCENE.instantiate() as MeleeEnemy
	far_enemy.setup(player, Vector2(260.0, 0.0), 1.0, CONFIG)
	root.add_child(far_enemy)
	far_enemy.set_physics_process(false)
	state.register_enemy(far_enemy)

	var near_health := near_enemy.health
	var far_health := far_enemy.health
	var lightning := PlayerMagicProjectile.new()
	lightning.setup(CONTENT.spell(GameIds.SPELL_LIGHTNING), Vector2.ZERO, Vector2.RIGHT, 25.0, 1, state)
	root.add_child(lightning)
	lightning.set_physics_process(false)
	lightning._physics_process(1.0)
	_require(near_enemy.health < near_health, "Swept player projectile skipped the nearest enemy")
	_require(is_equal_approx(far_enemy.health, far_health), "Projectile ignored first-hit ordering")

	near_enemy.attack_cooldown = 1.0
	near_enemy._physics_process(0.25)
	_require(is_equal_approx(near_enemy.attack_cooldown, 0.75), "Enemy attack timer is not driven by physics tick")
	player.attack.cooldown = 1.0
	player.attack._physics_process(0.25)
	_require(is_equal_approx(player.attack.cooldown, 0.75), "Player attack timer is not driven by physics tick")

	var waves := WaveManager.new()
	root.add_child(waves)
	waves.setup(func() -> int: return 999, CONFIG, CONTENT)
	waves.start_run()
	waves.set_physics_process(false)
	waves._physics_process(0.5)
	_require(is_equal_approx(waves.wave_time, 0.5), "WaveManager is not driven by physics tick")

	print("FIXED TICK AND SWEPT COLLISION PASS")
	quit()
